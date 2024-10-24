provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}


# Define variables

variable "resource_group_location" {
  default = "East US"
}

variable "storage_account_name" {
  description = "Name of the Azure Storage Account"
  type        = string
  default     = "adlslab05180"
}

variable "subscription_id" {
  description = "The Subscription ID for Azure"
  type        = string
}

data "azurerm_key_vault" "existing" {
  name                = "akvlab00"
  resource_group_name = "rghelper"
}

data "azurerm_key_vault_secret" "secret" {
  name         = "clientsecret"
  key_vault_id = data.azurerm_key_vault.existing.id
}

data "azurerm_resource_group" "rgstore" {
  name = "rglab"
}


# Create the storage account
resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  resource_group_name      = data.azurerm_resource_group.rgstore.name
  location                 = data.azurerm_resource_group.rgstore.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  public_network_access_enabled = false
  is_hns_enabled = true

  tags = {
    environment = "Development"
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [
      identity,
      tags,
    ]
  }
}
