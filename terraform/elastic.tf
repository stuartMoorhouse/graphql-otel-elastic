# Elastic Cloud Serverless Observability project.
# Authentication: EC_API_KEY environment variable (Elastic Cloud API key).
resource "ec_observability_project" "main" {
  name      = "${var.prefix}-observability"
  region_id = var.elastic_region
}

# API key scoped to write APM/OTel signals (traces, metrics, logs).
resource "elasticstack_elasticsearch_security_api_key" "apm_ingest" {
  name = "${var.prefix}-apm-ingest"

  role_descriptors = jsonencode({
    apm-writer = {
      cluster = ["monitor"]
      index = [{
        names      = ["logs-*", "metrics-*", "traces-*", "apm-*"]
        privileges = ["create_index", "create_doc", "auto_configure"]
      }]
    }
  })
}
