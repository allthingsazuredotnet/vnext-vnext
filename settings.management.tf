# Configure the management resources settings.
locals {
  configure_management_resources = {
    settings = {
      ama = {
        enable_uami                                                         = false
        enable_vminsights_dcr                                               = false
        enable_change_tracking_dcr                                          = false
        enable_mdfc_defender_for_sql_dcr                                    = false
        enable_mdfc_defender_for_sql_query_collection_for_security_research = false
      }
      log_analytics = {
        enabled = true
        config = {
          retention_in_days          = 30
          enable_monitoring_for_vm   = true
          enable_monitoring_for_vmss = true
          enable_sentinel            = true
          enable_change_tracking     = true
        }
      }
      security_center = {
        enabled = false
        config = {
          email_security_contact                                = "testemail@testdomain.com"
          enable_defender_for_apis                              = true
          enable_defender_for_app_services                      = true
          enable_defender_for_arm                               = true
          enable_defender_for_containers                        = true
          enable_defender_for_cosmosdbs                         = true
          enable_defender_for_cspm                              = true
          enable_defender_for_dns                               = true
          enable_defender_for_key_vault                         = true
          enable_defender_for_oss_databases                     = true
          enable_defender_for_servers                           = true
          enable_defender_for_servers_vulnerability_assessments = true
          enable_defender_for_sql_servers                       = true
          enable_defender_for_sql_server_vms                    = true
          enable_defender_for_storage                           = true
        }
      }
    }

    location = var.management_resources_location
    tags     = var.management_resources_tags
    advanced = null
  }
}
