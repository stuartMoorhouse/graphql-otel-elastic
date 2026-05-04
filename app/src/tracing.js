const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-grpc');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');
const { GraphQLInstrumentation } = require('@opentelemetry/instrumentation-graphql');
const { HttpInstrumentation } = require('@opentelemetry/instrumentation-http');
const { PgInstrumentation } = require('@opentelemetry/instrumentation-pg');
const { Resource } = require('@opentelemetry/resources');
const { SEMRESATTRS_SERVICE_NAME, SEMRESATTRS_SERVICE_VERSION } = require('@opentelemetry/semantic-conventions');
const { credentials, Metadata } = require('@grpc/grpc-js');

function buildCredentials(endpoint) {
  return endpoint && endpoint.startsWith('https')
    ? credentials.createSsl()
    : credentials.createInsecure();
}

const endpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4317';
const apiKey = process.env.ELASTIC_APM_API_KEY;
const headers = apiKey ? { Authorization: `ApiKey ${apiKey}` } : {};

const headersEnv = process.env.OTEL_EXPORTER_OTLP_HEADERS;
if (headersEnv && !apiKey) {
  headersEnv.split(',').forEach(pair => {
    const [k, ...v] = pair.split('=');
    if (k && v.length) headers[k.trim()] = v.join('=').trim();
  });
}

function buildMetadata() {
  return Object.entries(headers).reduce((m, [k, v]) => {
    m.set(k, v);
    return m;
  }, new Metadata());
}

const traceExporter = new OTLPTraceExporter({
  url: endpoint,
  credentials: buildCredentials(endpoint),
  metadata: buildMetadata(),
});

const metricExporter = new OTLPMetricExporter({
  url: endpoint,
  credentials: buildCredentials(endpoint),
  metadata: buildMetadata(),
});

const sdk = new NodeSDK({
  resource: new Resource({
    [SEMRESATTRS_SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'graphql-blog',
    [SEMRESATTRS_SERVICE_VERSION]: '1.0.0',
  }),
  traceExporter,
  metricReader: new PeriodicExportingMetricReader({
    exporter: metricExporter,
    exportIntervalMillis: 30000,
  }),
  instrumentations: [
    new HttpInstrumentation(),
    new GraphQLInstrumentation({
      depth: 3,
      allowValues: true,
    }),
    new PgInstrumentation(),
  ],
});

sdk.start();

process.on('SIGTERM', () => {
  sdk.shutdown().finally(() => process.exit(0));
});
