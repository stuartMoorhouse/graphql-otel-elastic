variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "East US"
}

variable "prefix" {
  description = "Name prefix applied to all resources"
  type        = string
  default     = "graphql-otel"
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "elastic_region" {
  description = "Elastic Cloud Serverless region — see: https://www.elastic.co/guide/en/cloud/current/ec-regions-templates-instances.html"
  type        = string
  default     = "azure-eastus2"
}
