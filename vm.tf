# resource "azurerm_public_ip" "valheimip" {
#   name                = "valheim-pip"
#   location            = azurerm_resource_group.valheimrg.location
#   resource_group_name = azurerm_resource_group.valheimrg.name
#   allocation_method   = "Static"
# }

# resource "azurerm_network_interface" "valheim" {
#   name                = "valheim-nic"
#   location            = azurerm_resource_group.valheimrg.location
#   resource_group_name = azurerm_resource_group.valheimrg.name

#   ip_configuration {
#     name                          = "internal"
#     subnet_id                     = azurerm_subnet.valheimsubnet.id
#     private_ip_address_allocation = "Dynamic"
#     public_ip_address_id          = azurerm_public_ip.valheimip.id
#   }
# }

# resource "azurerm_virtual_machine" "valheim" {
#   name                  = "valheimserver"
#   location              = azurerm_resource_group.valheimrg.location
#   resource_group_name   = azurerm_resource_group.valheimrg.name
#   network_interface_ids = [azurerm_network_interface.valheim.id]
#   vm_size               = "Standard_B2ms"

#   storage_os_disk {
#     name              = "valheimdisk"
#     caching           = "ReadWrite"
#     create_option     = "FromImage"
#     managed_disk_type = "Premium_LRS"
#   }

#   storage_image_reference {
#     publisher = "Canonical"
#     offer     = "ubuntu-24_04-lts"
#     sku       = "server-gen1"
#     version   = "latest"
#   }

#   os_profile {
#     computer_name  = "valheimserver"
#     admin_username = "vhserver"
#     admin_password = "Password1234!"
#   }

#   os_profile_linux_config {
#     disable_password_authentication = false
#   }
# }
