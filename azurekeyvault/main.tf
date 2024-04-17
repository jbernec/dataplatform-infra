provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

variable "key_vault" {
  type        = string
  description = "The name of the SQL Database."
  default     = "akv-lab-0518"
}

variable "azurerm_private_endpoint_key_vault" {
  type        = string
  description = "The name of the SQL Database."
  default     = "private-endpoint-akv"
}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "rgakv" {
  name = "rglab"
}

data "azurerm_subnet" "subnet" {
  name                 = "otherservices"
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.rgvnet.name
}

data "azurerm_resource_group" "rgvnet" {
  name = "rgvirtualnetworks"
}

data "azurerm_virtual_network" "vnet" {
  name                = "defaultvnet"
  resource_group_name = data.azurerm_resource_group.rgvnet.name
}

resource "azurerm_key_vault" "akv" {
  name                        = var.key_vault
  location                    = data.azurerm_resource_group.rgakv.location
  resource_group_name         = data.azurerm_resource_group.rgakv.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  public_network_access_enabled = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
    ]

    storage_permissions = [
      "Get",
    ]
  }
}

# Create private endpoint for AKV
resource "azurerm_private_endpoint" "my_terraform_endpoint" {
  name                = var.azurerm_private_endpoint_key_vault
  location            = data.azurerm_resource_group.rgakv.location
  resource_group_name = data.azurerm_resource_group.rgakv.name
  subnet_id           = data.azurerm_subnet.subnet.id

  private_service_connection {
    name                           = "akv-private-serviceconnection"
    private_connection_resource_id = azurerm_key_vault.akv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.my_terraform_dns_zone.id]
  }
}

# Create private DNS zone
resource "azurerm_private_dns_zone" "my_terraform_dns_zone" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = data.azurerm_resource_group.rgakv.name
}

# Create virtual network link
resource "azurerm_private_dns_zone_virtual_network_link" "my_terraform_vnet_link" {
  name                  = "akv-dns-vnet-link"
  resource_group_name   = data.azurerm_resource_group.rgakv.name
  private_dns_zone_name = azurerm_private_dns_zone.my_terraform_dns_zone.name
  virtual_network_id    = data.azurerm_virtual_network.vnet.id
}