# OTel Configuration

This document describes how OpenTelemetry is configured for the `graphql-blog` service and how
signals flow from the application to Elastic Observability.

## Environment variables

The OTel SDK reads the following environment variables at startup. They are injected into the
systemd service unit by Terraform via the VM's `cloud-init` script (`terraform/userdata.sh`).

| Variable | Example value | Purpose |
|---|---|---|
| `OTEL_SERVICE_NAME` | `graphql-blog` | Service name shown in APM |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `https://xxx.apm.us-east-1.aws.elastic.cloud:443` | OTLP gRPC endpoint for Elastic APM |
| `OTEL_EXPORTER_OTLP_HEADERS` | `Authorization=ApiKey <base64-key>` | Auth header sent with every OTLP request |
| `OTEL_RESOURCE_ATTRIBUTES` | `deployment.environment=production` | Extra resource tags on all signals |

The `OTEL_EXPORTER_OTLP_ENDPOINT` must be an HTTPS URL for TLS to be used. The SDK in
`app/src/tracing.js` checks the scheme and creates SSL credentials automatically.

## APM endpoint and API key

Both are provisioned automatically by `terraform apply`:

- `ec_observability_project.main` creates the Elastic Serverless Observability project and
  exposes its OTLP endpoint as a Terraform output (`elastic_apm_endpoint`).
- `elasticstack_elasticsearch_security_api_key.apm_ingest` creates a scoped API key
  (write access to `logs-*`, `metrics-*`, `traces-*`) and exposes the base64-encoded
  value, which Terraform injects directly into the systemd unit via `cloud-init`.

No manual key creation or `terraform.tfvars` entry is required for APM auth.

## How the configuration flows

```
terraform.tfvars
  └── elastic_apm_endpoint, elastic_apm_api_key
        └── terraform apply
              └── cloud-init (userdata.sh) renders values into systemd unit
                    └── /etc/systemd/system/graphql-blog.service
                          └── Environment= directives
                                └── OTel SDK (app/src/tracing.js) reads env vars at process start
                                      └── OTLP exporter sends to Elastic APM endpoint
```

Changes to `terraform.tfvars` require `terraform apply` followed by a service restart on the VM:

```bash
# After terraform apply
scripts/configure.sh        # refresh shared/env.json
scripts/reset-demo.sh       # restart graphql-blog on the VM
```

## Signals sent to Elastic

| Signal type | Source | Notes |
|---|---|---|
| Traces — HTTP | `@opentelemetry/instrumentation-http` | One span per HTTP request to port 4000 |
| Traces — GraphQL | `@opentelemetry/instrumentation-graphql` | Spans for each operation, field resolvers at depth <= 3 |
| Metrics — Node.js runtime | `@opentelemetry/auto-instrumentations-node` | Event loop lag, heap, GC; exported every 30 s |
| Logs | — | Not configured in this setup |

Logs are not sent via OTel in this demo. If needed, configure `@opentelemetry/winston-transport`
or a Filebeat log shipper separately.

## Viewing signals in Kibana

- **Traces**: Observability -> APM -> Services -> `graphql-blog` -> Transactions
  - GraphQL operations appear as transaction names, e.g. `query posts`, `mutation createPost`
  - HTTP spans appear as child spans of the GraphQL operation span
- **Metrics**: Observability -> APM -> Services -> `graphql-blog` -> Metrics
  - Node.js runtime metrics: heap used, event loop lag, active handles
- **Service map**: Observability -> APM -> Service Map
  - Shows `graphql-blog` and its dependency on the PostgreSQL database

## Generating demo traces

Run the load generator to produce a realistic mix of queries and mutations:

```bash
scripts/generate-load.sh --count 20 --delay 0.5
```

This sends five operation types per iteration: `posts` list query, `post(id)` detail query with
nested author and comments, `authors` query, `createPost` mutation, and `createComment` mutation.
Allow 30-60 seconds for traces to appear in Kibana after the first request.
