provider "azurerm" {
  features {}
}


# Define variables

variable "resource_group_location" {
  default = "East US"
}

variable "storage_account_name" {
  description = "Name of the Azure Storage Account"
  type        = string
  default     = "storagelab05180"
}

data "azurerm_key_vault" "existing" {
  name                = "akvservice"
  resource_group_name = "rghelperservices"
}

data "azurerm_key_vault_secret" "secret" {
  name         = "clientsecret"
  key_vault_id = data.azurerm_key_vault.existing.id
}

data "azurerm_resource_group" "rgvnet" {
  name = "rgvirtualnetworks"
}

data "azurerm_resource_group" "rgstore" {
  name = "rglab"
}

data "azurerm_virtual_network" "vnet" {
  name                = "defaultvnet"
  resource_group_name = data.azurerm_resource_group.rgvnet.name
}

data "azurerm_subnet" "subnet" {
  name                 = "otherservices"
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.rgvnet.name
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

# Create a private endpoint for the storage account
resource "azurerm_private_endpoint" "storage_endpoint" {
  name                = "storage-endpoint"
  location            = var.resource_group_location
  resource_group_name = data.azurerm_resource_group.rgvnet.name
  subnet_id           = data.azurerm_subnet.subnet.id
  # subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "storage-connection"
    private_connection_resource_id = azurerm_storage_account.storage.id
    subresource_names              = ["dfs"]
    is_manual_connection           = false
  }

  depends_on = [
    azurerm_storage_account.storage
  ]

  private_dns_zone_group {
    name                 = "dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns.id]
  }
}

# Create a private DNS zone
resource "azurerm_private_dns_zone" "private_dns" {
  name                = "privatelink.dfs.core.windows.net"
  resource_group_name = data.azurerm_resource_group.rgvnet.name
}

# Create a virtual network link to the private DNS zone
resource "azurerm_private_dns_zone_virtual_network_link" "link" {
  name                  = "storage-dns-vnet-link"
  resource_group_name   = data.azurerm_resource_group.rgvnet.name
  private_dns_zone_name = azurerm_private_dns_zone.private_dns.name
  virtual_network_id    = data.azurerm_virtual_network.vnet.id

  depends_on = [ data.azurerm_virtual_network.vnet ]
}
