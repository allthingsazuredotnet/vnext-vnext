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

resource "azurerm_logic_app_trigger_http_request" "aiops_http" {
  name         = "Receive JSON payload from Azure Monitor"
  logic_app_id = azurerm_logic_app_workflow.aiops.id

  schema = <<SCHEMA
  {
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
  SCHEMA
}


resource "azurerm_logic_app_action_custom" "aiops_parse" {
  name         = "Parse alert payload"
  logic_app_id = azurerm_logic_app_workflow.aiops.id

  body = <<BODY
    {
    "type": "ParseJson",
    "inputs": {
        "content": "@triggerBody()",
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
    },
    "runAfter": {}
    }
  BODY
}

resource "azurerm_logic_app_action_custom" "aiops_affected_resource" {
  name         = "AffectedResource"
  logic_app_id = azurerm_logic_app_workflow.aiops.id

  body = <<BODY
    {
    "type": "InitializeVariable",
    "inputs": {
        "variables": [
        {
            "name": "AffectedResource",
            "type": "array",
            "value": "@split(triggerBody()?['data']?['essentials']?['alertTargetIDs'][0], '/')"
        }
        ]
    },
    "runAfter": {
        "Parse alert payload": [
        "Succeeded"
        ]
    }
    }
BODY
}

resource "azurerm_logic_app_action_custom" "aiops_read_resource" {
  name         = "Read a resource"
  logic_app_id = azurerm_logic_app_workflow.aiops.id

  body = <<BODY
    {
    "type": "ApiConnection",
    "inputs": {
        "host": {
        "connection": {
            "name": "arm"
        }
        },
        "method": "get",
        "path": "/subscriptions/@{encodeURIComponent(variables('AffectedResource')[2])}/resourcegroups/@{encodeURIComponent(variables('AffectedResource')[4])}/providers/@{encodeURIComponent(variables('AffectedResource')[6])}/@{encodeURIComponent(concat(variables('AffectedResource')[7], '/', variables('AffectedResource')[8]))}",
        "queries": {
        "x-ms-api-version": "2021-04-01"
        }
    },
    "runAfter": {
        "AffectedResource": [
        "Succeeded"
        ]
    }
    }
BODY
}

resource "azurerm_logic_app_action_custom" "aiops_compose_alert" {
  name         = "Compose alert payload"
  logic_app_id = azurerm_logic_app_workflow.aiops.id

  body = <<BODY
    {
    "type": "Compose",
    "inputs": "@{union(body('Parse_alert_payload'), json(concat('{\"data\": ', string(union(body('Parse_alert_payload')?['data'], json(concat('{\"customProperties\": ', string(body('Read_a_resource')?['tags']), '}')))), '}')))}",
    "runAfter": {
        "Read a resource": [
        "Succeeded"
        ]
    }
    }
BODY
}