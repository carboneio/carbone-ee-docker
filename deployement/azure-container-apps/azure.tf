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

variable "carbone_license" {
  type = string
  sensitive = true
  description = "Carbone License"
}

variable "carbone_key" {
  type = string
  sensitive = true
  description = "Carbone public key to enable authentification"
  default = "EMPTY"
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "carbone-deployement"
  location = "francecentral"
}

resource "azurerm_key_vault" "key_vault" {
  name                       = "carbone-KeyVault"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7

  enabled_for_deployment = true
  enabled_for_template_deployment = true

  enable_rbac_authorization = true
}

resource "azurerm_user_assigned_identity" "carbone_identity" {
  location            = azurerm_resource_group.rg.location
  name                = "carbone_identity"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "principal_rbac" {
  scope                = azurerm_key_vault.key_vault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "azurewaysecret_licence" {
  scope                = azurerm_key_vault_secret.carbone_license.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.carbone_identity.principal_id
}

resource "azurerm_role_assignment" "azurewaysecret_key" {
  scope                = azurerm_key_vault_secret.carbone_public_key.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.carbone_identity.principal_id
}

resource "azurerm_key_vault_secret" "carbone_license" {
  name         = "carbone-license"
  value        = var.carbone_license
  key_vault_id = azurerm_key_vault.key_vault.id

  depends_on = [ azurerm_role_assignment.principal_rbac ]
}

resource "azurerm_key_vault_secret" "carbone_public_key" {
  name         = "carbone-public-key"
  value        = var.carbone_key
  key_vault_id = azurerm_key_vault.key_vault.id

  depends_on = [ azurerm_role_assignment.principal_rbac ]
}

resource "azurerm_log_analytics_workspace" "log_workspace" {
  name                = "carbone-logs"
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
  name                      = "carbonestorageaccess"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  shared_access_key_enabled = true
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

resource "azurerm_role_assignment" "render_blob_contributor_role_assignment" {
  scope                = azurerm_storage_container.renders.resource_manager_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.carbone_identity.principal_id
}

resource "azurerm_role_assignment" "template_blob_contributor_role_assignment" {
  scope                = azurerm_storage_container.templates.resource_manager_id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.carbone_identity.principal_id
}

resource "azurerm_container_app" "carbone_ee_app" {
  name                         = "carbone-app"
  container_app_environment_id = azurerm_container_app_environment.carbone_env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  secret {
    name  = "carbone-license"
    key_vault_secret_id = azurerm_key_vault_secret.carbone_license.versionless_id
    identity = azurerm_user_assigned_identity.carbone_identity.id
  }
  secret {
    name  = "carbone-public-key"
    key_vault_secret_id = azurerm_key_vault_secret.carbone_public_key.versionless_id
    identity = azurerm_user_assigned_identity.carbone_identity.id
  }

  template {
    container {
      name   = "carbone-ee"
      image  = "docker.io/carbone/carbone-ee:full-5.0.0-beta.21"
      cpu    = 2.0
      memory = "4Gi"
      env {
        name = "AZURE_MANAGED_IDENTITY_CLIENT_ID"
        value = azurerm_user_assigned_identity.carbone_identity.client_id
      }
      env {
        name = "CARBONE_EE_FACTORIES"
        value = 2
      }
      env {
        name = "CARBONE_EE_STUDIO"
        value = "true"
      }
      #env {
      #  name = "CARBONE_DATABASE_NAME"
      #  value = "database.sqlite"
      #}
      env {
        name = "CARBONE_EE_AUTHENTICATION"
        value = "false"
      }
      env {
        name = "CARBONE_EE_NBREPORTMAXPERBATCH"
        value = 10000
      }
      env {
        name = "CARBONE_AUTHENTICATION_PUBLIC_KEY"
        secret_name = "carbone-public-key"
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
        name = "CONTAINER_TEMPLATES"
        value = "carbone-templates"
      }
      env {
        name = "CONTAINER_RENDERS"
        value = "carbone-rendus"
      }
      env {
        name = "CARBONE_EE_CONVERTERFACTORYTIMEOUT"
        value = 36000000
      }
      env {
        name = "CARBONE_EE_NBREPORTMAXPERBATCH"
        value = 100000
      }
      env {
        name = "CARBONE_EE_LICENSE"
        secret_name = "carbone-license"
      }
    }
    max_replicas = 2
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
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.carbone_identity.id]
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

output "app_url" {
  value = "https://${azurerm_container_app.carbone_ee_app.ingress[0].fqdn}"
}