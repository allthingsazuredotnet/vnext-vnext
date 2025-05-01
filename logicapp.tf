resource azurerm_resource_group "aiops" {
  name     = "iaggbs-rg-logicapp-aiops-prod-uksouth"
  location = "uksouth"
}

resource "azurerm_logic_app_workflow" "aiops" {
  name                = "iaggbs-logicapp-aiops-prod-uksouth-01"
  location            = azurerm_resource_group.aiops.location
  resource_group_name = azurerm_resource_group.aiops.name

  // Optional identity block, depends on your setup
  identity {
    type = "system_assigned"
  }
}