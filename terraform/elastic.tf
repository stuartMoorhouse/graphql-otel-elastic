# Elastic Cloud Serverless Observability project.
# Authentication: EC_API_KEY environment variable (Elastic Cloud API key).
resource "ec_observability_project" "main" {
  name      = "${var.prefix}-observability"
  region_id = var.elastic_region
}

# API key with APM application privileges — required for the APM server's OTLP endpoint.
# Index-level privileges are not sufficient; the APM server validates against application privileges.
resource "elasticstack_elasticsearch_security_api_key" "apm_ingest" {
  name = "${var.prefix}-apm-ingest"

  role_descriptors = jsonencode({
    apm-writer = {
      applications = [{
        application = "apm"
        privileges  = ["event:write", "config_agent:read"]
        resources   = ["*"]
      }]
    }
  })
}

# Push the new API key into the VM's systemd unit whenever it changes.
# Uses a drop-in override so the base unit file is not modified.
resource "null_resource" "update_vm_apm_key" {
  triggers = {
    api_key = elasticstack_elasticsearch_security_api_key.apm_ingest.encoded
  }

  depends_on = [azurerm_linux_virtual_machine.main]

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.main.ip_address
    user        = var.admin_username
    private_key = tls_private_key.main.private_key_openssh
    timeout     = "5m"
  }

  provisioner "file" {
    content     = "[Service]\nEnvironment=\"OTEL_EXPORTER_OTLP_HEADERS=Authorization=ApiKey ${elasticstack_elasticsearch_security_api_key.apm_ingest.encoded}\"\n"
    destination = "/tmp/apm-key.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/systemd/system/graphql-blog.service.d",
      "sudo mv /tmp/apm-key.conf /etc/systemd/system/graphql-blog.service.d/apm-key.conf",
      "sudo systemctl daemon-reload",
      "sudo systemctl restart graphql-blog",
    ]
  }
}
