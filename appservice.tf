resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"
}

resource "azurerm_app_service_plan" "example" {
  name                = "example-asp"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  sku {
    tier     = "PremiumV3"
    size     = "P0v3"
    capacity = 3
  }
  per_site_scaling             = false
  maximum_elastic_worker_count = 1
  zone_redundant               = true
}
