terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    ec = {
      source  = "elastic/ec"
      version = "~> 0.12"
    }
    elasticstack = {
      source  = "elastic/elasticstack"
      version = "~> 0.11"
    }
  }
}

provider "azurerm" {
  features {}
  # Credentials are supplied via environment variables:
  #   ARM_SUBSCRIPTION_ID
  #   ARM_CLIENT_ID
  #   ARM_CLIENT_SECRET
  #   ARM_TENANT_ID
}

# Authentication: EC_API_KEY environment variable (Elastic Cloud API key).
provider "ec" {}

provider "elasticstack" {
  elasticsearch {
    endpoints = [ec_observability_project.main.endpoints.elasticsearch]
    username  = ec_observability_project.main.credentials.username
    password  = ec_observability_project.main.credentials.password
  }
  kibana {
    endpoints = [ec_observability_project.main.endpoints.kibana]
    username  = ec_observability_project.main.credentials.username
    password  = ec_observability_project.main.credentials.password
  }
}
