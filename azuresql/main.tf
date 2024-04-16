provider "azurerm" {
  features {}
}


variable "sql_db_name" {
  type        = string
  description = "The name of the SQL Database."
  default     = "sampledb0518"
}

variable "admin_username" {
  type        = string
  description = "The administrator username of the SQL logical server."
  default     = "azureadmin"
}

variable "admin_password" {
  type        = string
  description = "The administrator password of the SQL logical server."
  sensitive   = true
  default     = null
}

# Random password for SQL server
resource "random_password" "admin_password" {
  count       = var.admin_password == null ? 1 : 0
  length      = 20
  special     = true
  min_numeric = 1
  min_upper   = 1
  min_lower   = 1
  min_special = 1
}

locals {
  admin_password = try(random_password.admin_password[0].result, var.admin_password)
}

data "azurerm_key_vault" "existing" {
  name                = "akvservice"
  resource_group_name = "rghelperservices"
}

data "azurerm_key_vault_secret" "secret" {
  name         = "sqlpassword"
  key_vault_id = data.azurerm_key_vault.existing.id
}

data "azurerm_resource_group" "rgsql" {
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

# Create SQL server
resource "azurerm_mssql_server" "server" {
  name                         = var.sql_db_name
  resource_group_name          = data.azurerm_resource_group.rgsql.name
  location                     = data.azurerm_resource_group.rgsql.location
  administrator_login          = var.admin_username
  administrator_login_password = data.azurerm_key_vault_secret.secret.value
  version                      = "12.0"
}

# Create SQL database
resource "azurerm_mssql_database" "db" {
  name      = var.sql_db_name
  server_id = azurerm_mssql_server.server.id
}

# Create private endpoint for SQL server
resource "azurerm_private_endpoint" "my_terraform_endpoint" {
  name                = "private-endpoint-sql"
  location            = data.azurerm_resource_group.rgsql.location
  resource_group_name = data.azurerm_resource_group.rgsql.name
  subnet_id           = data.azurerm_subnet.subnet.id

  private_service_connection {
    name                           = "private-serviceconnection"
    private_connection_resource_id = azurerm_mssql_server.server.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.my_terraform_dns_zone.id]
  }
}

# Create private DNS zone
resource "azurerm_private_dns_zone" "my_terraform_dns_zone" {
  name                = "privatelink.database.windows.net"
  resource_group_name = data.azurerm_resource_group.rgsql.name
}

# Create virtual network link
resource "azurerm_private_dns_zone_virtual_network_link" "my_terraform_vnet_link" {
  name                  = "sql-dns-vnet-link"
  resource_group_name   = data.azurerm_resource_group.rgsql.name
  private_dns_zone_name = azurerm_private_dns_zone.my_terraform_dns_zone.name
  virtual_network_id    = data.azurerm_virtual_network.vnet.id
}