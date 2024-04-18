provider "azurerm" {
  features {
  }
}

data "azurerm_resource_group" "rgadf" {
  name = "rglab"
}

variable "adf_name" {
  type        = string
  description = "The name of the SQL Database."
  default     = "adf-0518"
}

variable "adf_private_endpoint" {
  type        = string
  description = "The name of the SQL Database."
  default     = "adf-pe-0518"
}

variable "adf_private_endpoint-portal" {
  type        = string
  description = "The name of the SQL Database."
  default     = "adf-pe-portal-0518"
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

resource "azurerm_data_factory" "adf" {
  name                = var.adf_name
  location            = data.azurerm_resource_group.rgadf.location
  resource_group_name = data.azurerm_resource_group.rgadf.name
  tags = {
    "environment" = "Development"
  }
  public_network_enabled = false
  identity {
    type         = "SystemAssigned"
  }
  managed_virtual_network_enabled = true
}

# Create private endpoint for ADF
resource "azurerm_private_endpoint" "my_terraform_endpoint" {
  name                = var.adf_private_endpoint
  location            = data.azurerm_resource_group.rgadf.location
  resource_group_name = data.azurerm_resource_group.rgadf.name
  subnet_id           = data.azurerm_subnet.subnet.id

  private_service_connection {
    name                           = "adf-private-serviceconnection"
    private_connection_resource_id = azurerm_data_factory.adf.id
    subresource_names              = ["datafactory"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.my_datafactory_dns_zone.id]
  }
}

# Create private endpoint for ADF-Portal
resource "azurerm_private_endpoint" "my_terraform_endpoint-portal" {
  name                = var.adf_private_endpoint-portal
  location            = data.azurerm_resource_group.rgadf.location
  resource_group_name = data.azurerm_resource_group.rgadf.name
  subnet_id           = data.azurerm_subnet.subnet.id

  private_service_connection {
    name                           = "adf-portal-private-serviceconnection"
    private_connection_resource_id = azurerm_data_factory.adf.id
    subresource_names              = ["portal"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.my_portal_dns_zone.id]
  }

}

# Create private portal DNS zone
resource "azurerm_private_dns_zone" "my_portal_dns_zone" {
  name                = "privatelink.adf.azure.com"
  resource_group_name = data.azurerm_resource_group.rgadf.name
  
}

# Create private datafactory DNS zone
resource "azurerm_private_dns_zone" "my_datafactory_dns_zone" {
  name                = "privatelink.datafactory.azure.net"
  resource_group_name = data.azurerm_resource_group.rgadf.name
  
}

# Create virtual network link
resource "azurerm_private_dns_zone_virtual_network_link" "my_portal_vnet_link" {
  name                  = "portal-adf-dns-vnet-link"
  resource_group_name   = data.azurerm_resource_group.rgadf.name
  private_dns_zone_name = azurerm_private_dns_zone.my_portal_dns_zone.name
  virtual_network_id    = data.azurerm_virtual_network.vnet.id
}

# Create virtual network link
resource "azurerm_private_dns_zone_virtual_network_link" "my_adf_vnet_link" {
  name                  = "adf-dns-vnet-link"
  resource_group_name   = data.azurerm_resource_group.rgadf.name
  private_dns_zone_name = azurerm_private_dns_zone.my_datafactory_dns_zone.name
  virtual_network_id    = data.azurerm_virtual_network.vnet.id
}