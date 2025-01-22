# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.113.0"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

variable "carbone_license" {}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "carboneTFResourceGroup"
  location = "francecentral"
}

resource "azurerm_key_vault" "key_vault" {
  name                       = "carboneSecrets"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7

  enabled_for_deployment = true
  enabled_for_template_deployment = true

  enable_rbac_authorization = true

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Set",
      "Get",
      "Delete",
      "Purge",
      "Recover"
    ]
  }
}

resource "azurerm_log_analytics_workspace" "log_workspace" {
  name                = "carbone-playground-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "carbone_env" {
  name                       = "Carbone-Environment"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_workspace.id
}

resource "azurerm_storage_account" "carbone-storage" {
  name                     = "carbonestorageaccess"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "templates" {
  name                  = "carbone-templates"
  storage_account_name  = azurerm_storage_account.carbone-storage.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "renders" {
  name                  = "carbone-rendus"
  storage_account_name  = azurerm_storage_account.carbone-storage.name
  container_access_type = "private"
}

resource "azurerm_container_app" "carbone_ee_app" {
  name                         = "carbone-app"
  container_app_environment_id = azurerm_container_app_environment.carbone_env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  secret {
    name  = "azure-secret-access-key"
    value = azurerm_storage_account.carbone-storage.primary_access_key
  }
  secret {
    name  = "carbone-license"
    value = "${var.carbone_license}"
  }

  template {
    container {
      name   = "carbone-ee"
      image  = "carbone/carbone-ee:full"
      cpu    = 1.0
      memory = "2Gi"
      env {
        name = "CARBONE_EE_FACTORIES"
        value = 1
      }
      env {
        name = "CARBONE_EE_STUDIO"
        value = "true"
      }
      env{
        name = "CARBONE_USE_AZURE_PLUGIN"
        value = "true"
      }
      env {
        name = "AZURE_STORAGE_ACCOUNT"
        value = "carbonestorageaccess"
      }
      env {
        name = "AZURE_STORAGE_KEY"
        secret_name = "azure-secret-access-key"
      }
      env {
        name = "CONTAINER_TEMPLATES"
        value = "carbone-templates"
      }
      env {
        name = "CONTAINER_RENDERS"
        value = "carbone-rendus"
      }
      env {
        name = "CARBONE_EE_LICENSE"
        secret_name = "carbone-license"
      }
    }
    max_replicas = 5
    min_replicas = 0

    custom_scale_rule {
      name = "azure-cpu-scaling"
      custom_rule_type = "cpu"
      metadata = {
        type = "Utilization"
        value = "60"
      }
    }
  }
  ingress {
    allow_insecure_connections = false
    external_enabled = true
    target_port = 4000
    traffic_weight {
      latest_revision = true
      percentage = 100
    }
  }
}