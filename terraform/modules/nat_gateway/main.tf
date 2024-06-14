terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
    }
  }

  required_version = ">= 0.14.9"
}

#-----------------------------------
# Public IP for NAT gateway
#-----------------------------------
resource "azurerm_public_ip" "pip-nat-gateway" {
  name                = "pip-orderlogix-natgw"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}


resource "azurerm_nat_gateway" "nat_gateway" {
  resource_group_name     = var.resource_group_name
  location                = var.location    
  name                    = var.name
  sku_name                = var.sku_name
  idle_timeout_in_minutes = var.idle_timeout_in_minutes
  zones                   = var.availability_zones
}

resource "azurerm_subnet_nat_gateway_association" "subnet_nat_gateway" {
  subnet_id      = var.subnet_id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway.id
}

resource "azurerm_nat_gateway_public_ip_association" "ip_addr_nat_gateway" {
  nat_gateway_id       = azurerm_nat_gateway.nat_gateway.id
  public_ip_address_id = azurerm_public_ip.pip-nat-gateway.id
}