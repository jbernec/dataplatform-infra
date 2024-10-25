provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = var.subscription_id
  
}

variable "key_vault" {
  type        = string
  description = "The name of the key vault."
  default     = "akv-lab-0518"
}

variable "subscription_id" {
  description = "The Subscription ID for Azure"
}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "keyvaultresourcegroup" {
  name = "rglab"
}

data "azurerm_key_vault" "existing" {
  name                = "akvlab00"
  resource_group_name = "rghelper"
}

data "azurerm_key_vault_secret" "subscription_id_secret" {
  name         = "subscription-id"
  key_vault_id = data.azurerm_key_vault.existing.id
}

output "secret_value" {
  value     = data.azurerm_key_vault_secret.subscription_id_secret.value
  sensitive = true
}

resource "azurerm_key_vault" "akv" {
  name                        = var.key_vault
  location                    = data.azurerm_resource_group.keyvaultresourcegroup.location
  resource_group_name         = data.azurerm_resource_group.keyvaultresourcegroup.name
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