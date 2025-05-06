resource "azurerm_resource_group" "aiops" {
  name     = "iaggbs-rg-logicapp-aiops-prod-uksouth"
  location = "uksouth"
}

resource "azurerm_logic_app_workflow" "aiops" {
  name                = "iaggbs-logicapp-aiops-prod-uksouth-01"
  location            = azurerm_resource_group.aiops.location
  resource_group_name = azurerm_resource_group.aiops.name

  // Optional identity block, depends on your setup
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_logic_app_trigger_custom" "aiops_http" {
  name         = "http_trigger"
  logic_app_id = azurerm_logic_app_workflow.aiops.id

  body = <<BODY
  {
             "Receive_JSON_payload_from_action_group": {
                "type": "Request",
                "kind": "Http",
                "inputs": {
                    "schema": {
                        "type": "object",
                        "properties": {
                            "schemaId": {
                                "type": "string"
                            },
                            "data": {
                                "type": "object",
                                "properties": {
                                    "essentials": {
                                        "type": "object",
                                        "properties": {
                                            "alertId": {
                                                "type": "string"
                                            },
                                            "alertRule": {
                                                "type": "string"
                                            },
                                            "severity": {
                                                "type": "string"
                                            },
                                            "signalType": {
                                                "type": "string"
                                            },
                                            "monitorCondition": {
                                                "type": "string"
                                            },
                                            "monitoringService": {
                                                "type": "string"
                                            },
                                            "alertTargetIDs": {
                                                "type": "array",
                                                "items": {
                                                    "type": "string"
                                                }
                                            },
                                            "originAlertId": {
                                                "type": "string"
                                            },
                                            "firedDateTime": {
                                                "type": "string"
                                            },
                                            "resolvedDateTime": {
                                                "type": "string"
                                            },
                                            "description": {
                                                "type": "string"
                                            },
                                            "essentialsVersion": {
                                                "type": "string"
                                            },
                                            "alertContextVersion": {
                                                "type": "string"
                                            }
                                        }
                                    },
                                    "alertContext": {
                                        "type": "object",
                                        "properties": {}
                                    }
                                }
                            }
                        }
                    }
                }
            }
  }
  BODY
}
