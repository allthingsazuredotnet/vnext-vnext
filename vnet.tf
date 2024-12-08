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

resource "azurerm_network_security_group" "valheimnsg" {
  name                = "valheim-nsg"
  resource_group_name = azurerm_resource_group.valheimrg.name
  location            = azurerm_resource_group.valheimrg.location

  security_rule {
    name                       = "sshinbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "194.164.227.48/32"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "valheiminboundtcp"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["2456", "2457"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "valheiminboundtcp"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_ranges    = ["2456", "2457"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "steaminboundtcp"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "27015"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "valheimnsg" {
  subnet_id                 = azurerm_subnet.valheimsubnet.id
  network_security_group_id = azurerm_network_security_group.valheimnsg.id
}
