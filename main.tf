# Use variables to customize the deployment

variable "root_id" {
  type    = string
  default = "v6lz"
}

variable "root_name" {
  type    = string
  default = "Version_6_LZ"
}

# Declare the Azure landing zones Terraform module
# and provide a base configuration.

module "enterprise_scale" {
  source  = "Azure/caf-enterprise-scale/azurerm"
  version = "6.2.1"

  default_location = var.default_location

  providers = {
    azurerm              = azurerm
    azurerm.connectivity = azurerm
    azurerm.management   = azurerm
  }

  root_parent_id                 = data.azurerm_client_config.core.tenant_id
  root_id                        = var.root_id
  root_name                      = var.root_name
  library_path                   = "${path.root}/lib"
  deploy_management_resources    = true
  configure_management_resources = local.configure_management_resources
  disable_telemetry              = true
  deploy_corp_landing_zones      = true
  deploy_online_landing_zones    = true
}
