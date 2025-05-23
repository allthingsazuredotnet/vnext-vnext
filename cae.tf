data "azurerm_client_config" "current" {}

locals {
  resource_group_name            = "rg-aiops-container-env"
  location                       = "UK South"                                # Choose your desired Azure region
  key_vault_name                 = "kv-aiops-${random_string.suffix.result}" # Ensure global uniqueness
  log_analytics_workspace_name   = "log-aiops-container-env"
  container_app_environment_name = "cae-aiops-app-environment"
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_resource_group" "aiops_container" {
  name     = local.resource_group_name
  location = local.location
}

resource "azurerm_container_registry" "acr" {
  name                = "caeiagtst${random_string.suffix.result}" # Appending random string for uniqueness
  location            = azurerm_resource_group.aiops_container.location
  resource_group_name = azurerm_resource_group.aiops_container.name
  sku                 = "Basic"
  admin_enabled       = true # Set to false if you plan to use token-based auth or managed identities exclusively

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_app_identity.id]
  }

  tags = {
    environment = "development" # Or your desired environment
    project     = "aiops"
  }
}

resource "azurerm_key_vault" "kv" {
  name                       = local.key_vault_name
  location                   = azurerm_resource_group.aiops_container.location
  resource_group_name        = azurerm_resource_group.aiops_container.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard" # Or "premium"
  enable_rbac_authorization  = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false # Set to true for production environments

  tags = {
    environment = "development"
    project     = "aiops"
  }
}

resource "azurerm_user_assigned_identity" "container_app_identity" {
  name                = "uai-aiops-payload" // Choose a suitable name
  resource_group_name = azurerm_resource_group.aiops_container.name
  location            = azurerm_resource_group.aiops_container.location

  tags = {
    environment = "development"
    project     = "aiops"
  }
}

resource "azurerm_role_assignment" "container_app_kv_secret_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.container_app_identity.principal_id // Use User-Assigned Identi
}

resource "azurerm_role_assignment" "container_app_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.container_app_identity.principal_id
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = local.log_analytics_workspace_name
  location            = azurerm_resource_group.aiops_container.location
  resource_group_name = azurerm_resource_group.aiops_container.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    environment = "development"
    project     = "aiops"
  }
}

resource "azurerm_container_app_environment" "cae" {
  name                       = local.container_app_environment_name
  location                   = azurerm_resource_group.aiops_container.location
  resource_group_name        = azurerm_resource_group.aiops_container.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  tags = {
    environment = "development"
    project     = "aiops"
  }
}

resource "azurerm_container_app" "aiops_payload" {
  name                         = "aiops-payload" // Choose a suitable name
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.aiops_container.name
  revision_mode                = "Single"

  registry {
    server   = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.container_app_identity.id
  }

  identity {
    type         = "UserAssigned" // Changed to UserAssigned (can also be "SystemAssigned, UserAssigned")
    identity_ids = [azurerm_user_assigned_identity.container_app_identity.id]
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "aiops"
      image  = "${azurerm_container_registry.acr.login_server}/aiops:latest" // Replace with your actual image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "SERVICE_NOW_ENDPOINT"
        value = "https://iag1test.service-now.com/api/sn_em_connector/em/inbound_event?source=azuremonitor"
      }

      env {
        name  = "SN_AUTH_TENANT_ID"
        value = "8bc3bb99-ff6d-42ef-9b17-1ea52c4db4ed"
      }

      env {
        name  = "AZURE_KEY_VAULT_URI"
        value = "kv-aiops-szdw" // This references a secret defined in the 'secret' block below
      }

      env {
        name  = "SN_AUTH_AUDIENCE"
        value = "api://fe05437f-c0ee-4c24-a034-532390fb5e2b" // This references a secret defined in the 'secret' block below
      }

      env {
        name        = "SN_AUTH_CLIENT_ID_SECRET_NAME"
        secret_name = "sn-auth-client-id-secret-name" // This references a secret defined in the 'secret' block below
      }
    }
  }

  ingress {
    target_port                = 5000   // Replace with the port your container application listens on
    transport                  = "http" // ACA handles TLS termination; your app receives HTTP traffic on target_port
    external_enabled           = true   // Set to true to expose the app externally
    allow_insecure_connections = false  // Default is false, ensures HTTPS only

    traffic_weight {
      percentage      = 100
      latest_revision = true // Direct all traffic to the latest stable revision
    }
  }

  // Optional: Define secrets that can be referenced by env vars
  // These secrets can be sourced from Key Vault or be simple string values
  #   secret {
  #     name  = "my-secret-name-in-container-app"
  #     value = "this-is-a-plain-text-secret" // For Key Vault, you'd use key_vault_secret_id and identity
  #   }

  # Example for Key Vault secret (requires managed identity on the Container App)

  secret {
    name                = "sn-auth-client-id-secret-name"
    key_vault_secret_id = "${azurerm_key_vault.kv.vault_uri}secrets/my-kv-secret"  // Assuming you have a Key Vault secret resource
    identity            = azurerm_user_assigned_identity.container_app_identity.id // Use User-Assigned Identity's ID
  }

  tags = {
    environment = "development"
    project     = "aiops"
  }
}
