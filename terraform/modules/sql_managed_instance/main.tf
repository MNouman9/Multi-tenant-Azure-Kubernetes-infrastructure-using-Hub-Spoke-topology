# TODO set the variables below either enter them in plain text after = sign, or change them in variables.tf
#  (var.xyz will take the default value from variables.tf if you don't change it)

# # Create security group
# resource "azurerm_network_security_group" "example" {
#   name                = "${random_pet.prefix.id}-nsg"
#   location            = azurerm_resource_group.example.location
#   resource_group_name = azurerm_resource_group.example.name
# }

# # Create a virtual network
# resource "azurerm_virtual_network" "example" {
#   name                = "${random_pet.prefix.id}-vnet"
#   resource_group_name = azurerm_resource_group.example.name
#   address_space       = ["10.0.0.0/24"]
#   location            = azurerm_resource_group.example.location
# }

# # Create a subnet
# resource "azurerm_subnet" "example" {
#   name                 = "${random_pet.prefix.id}-subnet"
#   resource_group_name  = azurerm_resource_group.example.name
#   virtual_network_name = azurerm_virtual_network.example.name
#   address_prefixes     = ["10.0.0.0/27"]

#   delegation {
#     name = "managedinstancedelegation"

#     service_delegation {
#       name = "Microsoft.Sql/managedInstances"
#       actions = [
#         "Microsoft.Network/virtualNetworks/subnets/join/action",
#         "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
#         "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
#       ]
#     }
#   }
# }

# # Associate subnet and the security group
# resource "azurerm_subnet_network_security_group_association" "example" {
#   subnet_id                 = azurerm_subnet.example.id
#   network_security_group_id = azurerm_network_security_group.example.id
# }

# # Create a route table
# resource "azurerm_route_table" "example" {
#   name                          = "${random_pet.prefix.id}-rt"
#   location                      = azurerm_resource_group.example.location
#   resource_group_name           = azurerm_resource_group.example.name
#   disable_bgp_route_propagation = false
# }

# # Associate subnet and the route table
# resource "azurerm_subnet_route_table_association" "example" {
#   subnet_id      = azurerm_subnet.example.id
#   route_table_id = azurerm_route_table.example.id
# }

resource "azurerm_user_assigned_identity" "sql_mi_identity" {
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  name = "${var.name}Identity"

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_network_security_group" "nsg_sql_mi" {
  name                = "mi-security-group"
  location            = var.location
  resource_group_name = var.resource_group_name
}


resource "azurerm_network_security_rule" "allow_management_inbound" {
  name                        = "allow_management_inbound"
  priority                    = 106
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["9000", "9003", "1438", "1440", "1452"]
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg_sql_mi.name
}

resource "azurerm_network_security_rule" "allow_misubnet_inbound" {
  name                        = "allow_misubnet_inbound"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.address_prefixes
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg_sql_mi.name
}

resource "azurerm_network_security_rule" "allow_health_probe_inbound" {
  name                        = "allow_health_probe_inbound"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg_sql_mi.name
}

resource "azurerm_network_security_rule" "allow_tds_inbound" {
  name                        = "allow_tds_inbound"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg_sql_mi.name
}

resource "azurerm_network_security_rule" "deny_all_inbound" {
  name                        = "deny_all_inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg_sql_mi.name
}

resource "azurerm_network_security_rule" "allow_management_outbound" {
  name                        = "allow_management_outbound"
  priority                    = 102
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443", "12000"]
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg_sql_mi.name
}

resource "azurerm_network_security_rule" "allow_misubnet_outbound" {
  name                        = "allow_misubnet_outbound"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.address_prefixes
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg_sql_mi.name
}

resource "azurerm_network_security_rule" "deny_all_outbound" {
  name                        = "deny_all_outbound"
  priority                    = 4096
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg_sql_mi.name
}

resource "azurerm_subnet_network_security_group_association" "nsg_sql_mi_associate" {
  subnet_id                 = var.subnet_id
  network_security_group_id = azurerm_network_security_group.nsg_sql_mi.id
}

# Create managed instance
resource "azurerm_mssql_managed_instance" "main" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  subnet_id                    = var.subnet_id
  administrator_login          = var.sql_user
  administrator_login_password = var.sql_user_password
  license_type                 = var.license_type
  sku_name                     = var.sku_name
  vcores                       = var.vcores
  storage_size_in_gb           = var.storage_size_in_gb
  timezone_id                  = var.timezone_id
  maintenance_configuration_name = var.maintenance_configuration_name

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.sql_mi_identity.id
    ]
  }

    depends_on = [
      azurerm_subnet_network_security_group_association.nsg_sql_mi_associate
    ]
}

# resource "random_password" "password" {
#   length      = 20
#   min_lower   = 1
#   min_upper   = 1
#   min_numeric = 1
#   min_special = 1
#   special     = true
# }

# resource "random_pet" "prefix" {
#   prefix = var.prefix
#   length = 1
# }