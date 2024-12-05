resource "azurerm_resource_group" "valheimrg" {
  name     = var.valheim_rg_name
  location = var.default_location
}

resource "azurerm_virtual_network" "valheimvnet" {
  name                = "valheim-vnet"
  resource_group_name = azurerm_resource_group.valheimrg.name
  location            = azurerm_resource_group.valheimrg.location
  address_space       = ["192.168.0.0/24"]
}

resource "azurerm_subnet" "valheimsubnet" {
  name                 = "valheim-subnet"
  resource_group_name  = azurerm_resource_group.valheimrg.name
  virtual_network_name = azurerm_virtual_network.valheimvnet.name
  address_prefixes     = ["192.168.0.0/26"]
} 