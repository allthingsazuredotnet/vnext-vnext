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
    "inputs": "@{union(body('Parse alert payload'), json(concat('{\"data\": ', string(union(body('Parse alert payload')?['data'], json(concat('{\"customProperties\": ', string(body('Read a resource')?['tags']), '}')))), '}')))}",
    "runAfter": {
        "Read a resource": [
        "Succeeded"
        ]
    }
    }
BODY
}

resource "azurerm_logic_app_action_custom" "send_payload" {
  name         = "Send payload to AIOPS"
  logic_app_id = azurerm_logic_app_workflow.aiops.id

  body = <<BODY
    {
    "type": "Http",
    "inputs": {
        "uri": "https://iag1test.service-now.com/api/sn_em_connector/em/inbound_event?source=azuremonitor",
        "method": "POST",
        "headers": {
        "typ": "JWT",
        "alg": "RS256",
        "x5t": "CNv0OI3RwqlHFEVnaoMAshCH2XE",
        "kid": "CNv0OI3RwqlHFEVnaoMAshCH2XE",
        "appidacr": "2"
        },
        "body": "@outputs('Compose alert payload')",
        "authentication": {
        "type": "ActiveDirectoryOAuth",
        "authority": "https://sts.windows.net/",
        "tenant": "8bc3bb99-ff6d-42ef-9b17-1ea52c4db4ed",
        "audience": "api://fe05437f-c0ee-4c24-a034-532390fb5e2b",
        "clientId": "fe05437f-c0ee-4c24-a034-532390fb5e2b",
        "secret": "X5d8Q~knSFEl25rDMLL0pqy5DJolNgcFHiF6fczQ"
        }
    },
    "runAfter": {
        "Compose alert payload": [
        "Succeeded"
        ]
    },
    "runtimeConfiguration": {
        "contentTransfer": {
        "transferMode": "Chunked"
        }
    }
    }
BODY
}