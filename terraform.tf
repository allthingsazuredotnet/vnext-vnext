terraform {
  required_version = ">= 1.11"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.1.7"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "azurerm" {
  alias           = "management"
  subscription_id = var.subscription_id_management
  features {}
}

provider "azurerm" {
  alias           = "connectivity"
  subscription_id = var.subscription_id_connectivity
  features {}
}
