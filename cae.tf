data "azurerm_client_config" "current" {}

locals {
  resource_group_name            = "rg-aiops-container-env"
  location                       = "UK South"                                # Choose your desired Azure region
  key_vault_name                 = "kv-aiops-${random_string.suffix.result}" # Ensure global uniqueness
  log_analytics_workspace_name   = "log-aiops-container-env"
  container_app_environment_name = "cae-aiops-app-environment"
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_resource_group" "aiops_container" {
  name     = local.resource_group_name
  location = local.location
}

resource "azurerm_key_vault" "kv" {
  name                       = local.key_vault_name
  location                   = azurerm_resource_group.aiops_container.location
  resource_group_name        = azurerm_resource_group.aiops_container.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "Standard" # Or "premium"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false # Set to true for production environments

  tags = {
    environment = "development"
    project     = "aiops"
  }
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = local.log_analytics_workspace_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    environment = "development"
    project     = "aiops"
  }
}

resource "azurerm_container_app_environment" "cae" {
  name                       = local.container_app_environment_name
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  tags = {
    environment = "development"
    project     = "aiops"
  }
}
