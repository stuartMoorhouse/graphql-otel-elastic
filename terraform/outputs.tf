output "vm_public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.main.ip_address
}

output "graphql_url" {
  description = "GraphQL endpoint URL"
  value       = "http://${azurerm_public_ip.main.ip_address}:4000/graphql"
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh -i ${local_sensitive_file.ssh_private_key.filename} ${var.admin_username}@${azurerm_public_ip.main.ip_address}"
}

output "resource_group_name" {
  description = "Resource group name — use for manual cleanup: az group delete --name <value>"
  value       = azurerm_resource_group.main.name
}

output "elastic_kibana_url" {
  description = "Elastic Kibana URL"
  value       = ec_observability_project.main.endpoints.kibana
}

output "elastic_apm_endpoint" {
  description = "Elastic APM OTLP endpoint (used by the VM)"
  value       = ec_observability_project.main.endpoints.apm
}

output "elastic_username" {
  description = "Elastic Cloud username"
  value       = ec_observability_project.main.credentials.username
}

output "elastic_password" {
  description = "Elastic Cloud password"
  value       = ec_observability_project.main.credentials.password
  sensitive   = true
}
