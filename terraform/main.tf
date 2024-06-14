terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.81.0"
    }
  }
}

provider "azurerm" {
  features {}
}

terraform {
  backend "azurerm" {
  }
}

locals {
  storage_account_prefix = "boot"
  route_table_name       = "route-to-eastus-hub-fw"
  route_name             = "r-nexthop-to-fw"
}

data "azurerm_client_config" "current" {
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}
resource "azurerm_resource_group" "hub-rg" {
  name     = var.hub_network_resource_group_name
  location = var.location
  tags     = var.tags
}
resource "azurerm_resource_group" "spoke-rg" {
  name     = var.spoke_network_resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "jumpbox-rg" {
  name     = var.vm_network_resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "security-rg" {
  name     = var.security_resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "sql-mi-rg" {
  name     = var.sql_mi_resource_group_name
  location = var.location
  tags     = var.tags
}

module "security_center" {
  source                           = "./modules/security_center"
  location                         = var.location
  resource_group_name              = azurerm_resource_group.security-rg.name
  security_contact_email           = var.security_contact_email
  security_contact_phone           = var.security_contact_phone

  depends_on               = [
    azurerm_resource_group.security-rg
  ]  
}

module "log_analytics_workspace" {
  source                           = "./modules/log_analytics"
  name                             = var.log_analytics_workspace_name
  location                         = var.location
  tags                             = var.tags  
  resource_group_name              = azurerm_resource_group.security-rg.name
  solution_plan_map                = var.solution_plan_map

  depends_on               = [
    azurerm_resource_group.security-rg
  ]
}

module "hub_network" {
  source                       = "./modules/virtual_network"
  resource_group_name          = azurerm_resource_group.hub-rg.name
  location                     = var.location
  vnet_name                    = var.hub_vnet_name
  address_space                = var.hub_address_space
  tags                         = var.tags
  log_analytics_workspace_id   = module.log_analytics_workspace.id
  log_analytics_retention_days = var.log_analytics_retention_days

  subnets = [
    {
      name : "AzureFirewallSubnet"
      address_prefixes : var.hub_firewall_subnet_address_prefix
      enforce_private_link_endpoint_network_policies  : true
      enforce_private_link_service_network_policies   : false
      enable_sql_delegation                           : false
    },
    {
      name : "AzureBastionSubnet"
      address_prefixes : var.hub_bastion_subnet_address_prefix
      enforce_private_link_endpoint_network_policies  : true
      enforce_private_link_service_network_policies   : false
      enable_sql_delegation                           : false
    },
  ]

  depends_on               = [
    azurerm_resource_group.hub-rg, module.log_analytics_workspace
  ]
}

#all subnets in the spoke network will be peered with the hub network
module "spoke_network" {
  source                       = "./modules/virtual_network"
  resource_group_name          = azurerm_resource_group.spoke-rg.name
  location                     = var.location
  tags                         = var.tags  
  vnet_name                    = var.spoke_vnet_name
  address_space                = var.spoke_vnet_address_space
  log_analytics_workspace_id   = module.log_analytics_workspace.id
  log_analytics_retention_days = var.log_analytics_retention_days

  subnets = [
    {
      name : var.aks_subnet_name
      address_prefixes : var.aks_subnet_address_prefix
      enforce_private_link_endpoint_network_policies  : true
      enforce_private_link_service_network_policies   : false
      enable_sql_delegation                           : false
    },
    {
      name : var.vm_subnet_name
      address_prefixes : var.vm_subnet_address_prefix
      enforce_private_link_endpoint_network_policies  : true
      enforce_private_link_service_network_policies   : false
      enable_sql_delegation                           : false
    },
    {
      name : var.application_gateway_subnet_name
      address_prefixes : var.application_gateway_subnet_address_prefix
      enforce_private_link_endpoint_network_policies  : true
      enforce_private_link_service_network_policies   : false
      enable_sql_delegation                           : false
    },
    {
      name : var.sqlmi_subnet_name
      address_prefixes : var.sqlmi_subnet_address_prefix
      enforce_private_link_endpoint_network_policies  : true
      enforce_private_link_service_network_policies   : false
      enable_sql_delegation                           : true
    },
    {
      name : var.ssrs_subnet_name
      address_prefixes : var.ssrs_subnet_address_prefix
      enforce_private_link_endpoint_network_policies  : true
      enforce_private_link_service_network_policies   : false
      enable_sql_delegation                           : false
    }
  ]

  depends_on               = [
    azurerm_resource_group.spoke-rg, module.log_analytics_workspace
  ]
}

#connect the hub and spoke networks with private peering
module "vnet_peering" {
  source              = "./modules/virtual_network_peering"
  vnet_1_name         = var.hub_vnet_name
  vnet_1_id           = module.hub_network.vnet_id
  vnet_1_rg           = azurerm_resource_group.hub-rg.name
  vnet_2_name         = var.spoke_vnet_name
  vnet_2_id           = module.spoke_network.vnet_id
  vnet_2_rg           = azurerm_resource_group.spoke-rg.name
  peering_name_1_to_2 = "${var.hub_vnet_name}To${var.spoke_vnet_name}"
  peering_name_2_to_1 = "${var.spoke_vnet_name}To${var.hub_vnet_name}"

  depends_on               = [
    azurerm_resource_group.hub-rg, azurerm_resource_group.spoke-rg, module.spoke_network,module.hub_network
  ] 
}

#The Firewall currently only provisions a single public IP address, whereas it looks like we may need 3 in total
module "firewall" {
  source                       = "./modules/firewall"
  name                         = var.firewall_name
  location                     = var.location
  tags                         = var.tags 
  resource_group_name          = azurerm_resource_group.hub-rg.name
  zones                        = var.firewall_zones
  threat_intel_mode            = var.firewall_threat_intel_mode
  sku_tier                     = var.firewall_sku_tier
  pip-fw-eastus-default        = "pip-${var.firewall_name}-default"
  subnet_id                    = module.hub_network.subnet_ids["AzureFirewallSubnet"]
  log_analytics_workspace_id   = module.log_analytics_workspace.id
  log_analytics_retention_days = var.log_analytics_retention_days

  depends_on               = [
    azurerm_resource_group.hub-rg, module.hub_network, module.log_analytics_workspace
  ] 
}

module "routetable" {
  source               = "./modules/route_table"
  resource_group_name  = azurerm_resource_group.spoke-rg.name
  location             = var.location
  tags                 = var.tags
  route_table_name     = local.route_table_name
  route_name           = local.route_name
  firewall_private_ip  = module.firewall.private_ip_address
  subnets_to_associate = {
    (var.aks_subnet_name) = {
      subscription_id      = data.azurerm_client_config.current.subscription_id
      resource_group_name  = azurerm_resource_group.spoke-rg.name
      virtual_network_name = var.spoke_vnet_name
    }
    (var.vm_subnet_name) = {
      subscription_id      = data.azurerm_client_config.current.subscription_id
      resource_group_name  = azurerm_resource_group.spoke-rg.name
      virtual_network_name = var.spoke_vnet_name
    }
    (var.sqlmi_subnet_name) = {
      subscription_id      = data.azurerm_client_config.current.subscription_id
      resource_group_name  = azurerm_resource_group.spoke-rg.name
      virtual_network_name = var.spoke_vnet_name
    }   
    (var.ssrs_subnet_name) = {
      subscription_id      = data.azurerm_client_config.current.subscription_id
      resource_group_name  = azurerm_resource_group.spoke-rg.name
      virtual_network_name = var.spoke_vnet_name
    }       
  }
  
  depends_on               = [
    azurerm_resource_group.spoke-rg, module.spoke_network
  ]  
} 

module "container_registry" {
  source                       = "./modules/container_registry"
  name                         = var.acr_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  tags                         = var.tags
  sku                          = var.acr_sku
  admin_enabled                = var.acr_admin_enabled
  georeplication_locations     = var.acr_georeplication_locations
  log_analytics_workspace_id   = module.log_analytics_workspace.id
  log_analytics_retention_days = var.log_analytics_retention_days

  depends_on               = [
    azurerm_resource_group.rg, module.log_analytics_workspace
  ]
}

module "application_gateway" {
  source  = "./modules/application_gateway"
  # By default, this module will not create a resource group and expect to provide 
  # a existing RG name to use an existing resource group. Location will be same as existing RG. 
  # set the argument to `create_resource_group = true` to create new resrouce.
  resource_group_name       = azurerm_resource_group.spoke-rg.name
  location                  = var.location
  tags                      = var.tags
  virtual_network_name      = var.spoke_vnet_name
  subnet_id                 = module.spoke_network.subnet_ids[var.application_gateway_subnet_name]
  subnet_name               = var.application_gateway_subnet_name
  app_gateway_name          = var.application_gateway_name
  
  # SKU requires `name`, `tier` to use for this Application Gateway
  # `Capacity` property is optional if `autoscale_configuration` is set
  sku = {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  autoscale_configuration = {
    min_capacity = 2
    max_capacity = 3
  }

  # A backend pool routes request to backend servers, which serve the request.
  # Can create different backend pools for different types of requests
  backend_address_pools = [
    { 
      name         = "default-be-address-pool"
      ip_addresses = []
    }
  ]

  # An application gateway routes traffic to the backend servers using the port, protocol, and other settings
  # The port and protocol used to check traffic is encrypted between the application gateway and backend servers
  # List of backend HTTP settings can be added here.  
  # `probe_name` argument is required if you are defing health probes.
  backend_http_settings = [
    {
      name                  = "default-be-https-settings"
      cookie_based_affinity = "Disabled"
      path                  = "/"
      enable_https          = true
      request_timeout       = 30
      # probe_name            = "appgw-testgateway-westeurope-probe1" # Remove this if `health_probes` object is not defined.
      connection_draining = {
        enable_connection_draining = true
        drain_timeout_sec          = 300

      }
    },
    {
      name                  = "default-be-http-settings"
      cookie_based_affinity = "Enabled"
      path                  = "/"
      enable_https          = false
      request_timeout       = 30
    }
  ]
  

  # List of HTTP/HTTPS listeners. SSL Certificate name is required
  # `Basic` - This type of listener listens to a single domain site, where it has a single DNS mapping to the IP address of the 
  # application gateway. This listener configuration is required when you host a single site behind an application gateway.
  # `Multi-site` - This listener configuration is required when you want to configure routing based on host name or domain name for 
  # more than one web application on the same application gateway. Each website can be directed to its own backend pool.
  # Setting `host_name` value changes Listener Type to 'Multi site`. `host_names` allows special wildcard charcters.
  http_listeners = [
    {
      name                 = "default-http-listener"
      #ssl_certificate_name = "ordermanagement-com"
      listener_type        = "Basic"
      host_name            = null
    }
  ]

  # Request routing rule is to determine how to route traffic on the listener. 
  # The rule binds the listener, the back-end server pool, and the backend HTTP settings.
  # `Basic` - All requests on the associated listener (for example, blog.contoso.com/*) are forwarded to the associated 
  # backend pool by using the associated HTTP setting.
  # `Path-based` - This routing rule lets you route the requests on the associated listener to a specific backend pool, 
  # based on the URL in the request. 
  request_routing_rules = [
    {
      name                       = "default-request-routing-rule"
      rule_type                  = "Basic"
      http_listener_name         = "default-http-listener"
      backend_address_pool_name  = "default-be-address-pool"
      backend_http_settings_name = "default-be-https-settings"
      priority                   = 19500
    }
  ]

  ssl_policy = {
    policy_type          = "Predefined"
    policy_name          = "AppGwSslPolicy20220101S"
  }

  # **************   I believe that AGIC will manage all of these settings   *****************
  # # TLS termination (previously known as Secure Sockets Layer (SSL) Offloading)
  # # The certificate on the listener requires the entire certificate chain (PFX certificate) to be uploaded to establish the chain of trust.
  # # Authentication and trusted root certificate setup are not required for trusted Azure services such as Azure App Service.
  # ssl_certificates = [{
  #   name     = "ordermanagement-com"
  #   data     = "./keyBag.pfx"
  #   password = "P@$$w0rd123"
  # }]


  # WAF configuration, disabled rule groups and exclusions.depends_on
  # The Application Gateway WAF comes pre-configured with CRS 3.0 by default. But you can choose to use CRS 3.2, 3.1, or 2.2.9 instead.
  # CRS 3.2 is only available on the `WAF_v2` SKU.
  waf_configuration = {
    firewall_mode            = "Detection"
    rule_set_version         = "3.1"
    file_upload_limit_mb     = 100
    max_request_body_size_kb = 128

    disabled_rule_group = [
      {
        rule_group_name = "REQUEST-930-APPLICATION-ATTACK-LFI"
        rules           = ["930100", "930110"]
      },
      {
        rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"
        rules           = ["920160"]
      }
    ]

    exclusion = [
      {
        match_variable          = "RequestCookieNames"
        selector                = "SomeCookie"
        selector_match_operator = "Equals"
      },
      {
        match_variable          = "RequestHeaderNames"
        selector                = "referer"
        selector_match_operator = "Equals"
      }
    ]
  }

  depends_on               = [
    azurerm_resource_group.spoke-rg, module.spoke_network
  ]

}

module "nat_gateway" {
  source = "./modules/nat_gateway"

  name                = var.nat_gateway_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = module.spoke_network.subnet_ids[var.aks_subnet_name]

  depends_on               = [
    azurerm_resource_group.rg, module.spoke_network
  ]  
}

module "aks_cluster" {
  source                                   = "./modules/aks"
  name                                     = var.aks_cluster_name
  location                                 = var.location
  tags                                     = var.tags
  resource_group_name                      = azurerm_resource_group.rg.name
  resource_group_id                        = azurerm_resource_group.rg.id
  kubernetes_version                       = var.kubernetes_version
  dns_prefix                               = lower(var.aks_cluster_name)
  private_cluster_enabled                  = true
  automatic_channel_upgrade                = var.automatic_channel_upgrade
  sku_tier                                 = var.sku_tier
  default_node_pool_name                   = var.default_node_pool_name
  default_node_pool_vm_size                = var.default_node_pool_vm_size
  vnet_subnet_id                           = module.spoke_network.subnet_ids[var.aks_subnet_name]
  default_node_pool_availability_zones     = var.default_node_pool_availability_zones
  default_node_pool_node_labels            = var.default_node_pool_node_labels
  default_node_pool_node_taints            = var.default_node_pool_node_taints
  default_node_pool_enable_auto_scaling    = var.default_node_pool_enable_auto_scaling
  default_node_pool_enable_host_encryption = var.default_node_pool_enable_host_encryption
  default_node_pool_enable_node_public_ip  = var.default_node_pool_enable_node_public_ip
  default_node_pool_max_pods               = var.default_node_pool_max_pods
  default_node_pool_max_count              = var.default_node_pool_max_count
  default_node_pool_min_count              = var.default_node_pool_min_count
  default_node_pool_node_count             = var.default_node_pool_node_count
  default_node_pool_os_disk_type           = var.default_node_pool_os_disk_type
  network_docker_bridge_cidr               = var.network_docker_bridge_cidr
  network_dns_service_ip                   = var.network_dns_service_ip
  network_plugin                           = var.network_plugin
  outbound_type                            = "userAssignedNATGateway"
  network_service_cidr                     = var.network_service_cidr
  log_analytics_workspace_id               = module.log_analytics_workspace.id
  role_based_access_control_enabled        = var.role_based_access_control_enabled
  tenant_id                                = data.azurerm_client_config.current.tenant_id
  admin_group_object_ids                   = var.admin_group_object_ids
  azure_rbac_enabled                       = var.azure_rbac_enabled
  admin_username                           = var.admin_username
  ssh_public_key                           = var.ssh_public_key

  ingress_application_gateway              = {
    enabled = true
    gateway_id = module.application_gateway.application_gateway_id
  } 

  depends_on                               = [
    azurerm_resource_group.rg, module.spoke_network, module.application_gateway, module.routetable, module.log_analytics_workspace
  ]

}

resource "azurerm_role_assignment" "ra_network_contributor" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Network Contributor"
  principal_id         = module.aks_cluster.aks_identity_principal_id
  skip_service_principal_aad_check = true

  #spg: must have aks cluster first
  depends_on = [module.aks_cluster]
}

# the following 2 role assignments allow app gateway ingress controller access to the app gateway
resource "azurerm_role_assignment" "ra_spoke_network_reader" {
  scope                = azurerm_resource_group.spoke-rg.id
  role_definition_name = "Reader"
  principal_id         = module.aks_cluster.ingress_application_gateway_identity.object_id
  skip_service_principal_aad_check = true

  #spg: must have aks cluster first
  depends_on = [module.spoke_network,module.aks_cluster]
}

resource "azurerm_role_assignment" "ra_spoke_network_contributor" {
  scope                = azurerm_resource_group.spoke-rg.id
  role_definition_name = "Contributor"
  principal_id         = module.aks_cluster.ingress_application_gateway_identity.object_id
  skip_service_principal_aad_check = true

  #spg: must have aks cluster first
  depends_on = [module.spoke_network,module.aks_cluster]
}

resource "azurerm_role_assignment" "ra_app_gateway_contributor" {
  scope                = module.application_gateway.application_gateway_id
  role_definition_name = "Contributor"
  principal_id         = module.aks_cluster.ingress_application_gateway_identity.object_id
  skip_service_principal_aad_check = true

  #spg: must have aks cluster first
  depends_on = [module.aks_cluster, module.application_gateway]
}

resource "azurerm_role_assignment" "ra_acr_pull" {
  role_definition_name = "AcrPull"
  scope                = module.container_registry.id
  principal_id         = module.aks_cluster.kubelet_identity_object_id
  skip_service_principal_aad_check = true
  
  #spg: must have aks cluster first
  depends_on = [
    module.container_registry, module.aks_cluster
  ]
}

#create a linux node pool for linux workloads
module "linux_node_pool" {
  source = "./modules/node_pool"
  resource_group_name = azurerm_resource_group.rg.name
  kubernetes_cluster_id = module.aks_cluster.id
  name                         = var.linux_node_pool_name
  vm_size                      = var.linux_node_pool_vm_size
  mode                         = var.linux_node_pool_mode
  node_labels                  = var.linux_node_pool_node_labels
  node_taints                  = var.linux_node_pool_node_taints
  availability_zones           = var.linux_node_pool_availability_zones
  vnet_subnet_id               = module.spoke_network.subnet_ids[var.aks_subnet_name]
  enable_auto_scaling          = var.linux_node_pool_enable_auto_scaling
  enable_host_encryption       = var.linux_node_pool_enable_host_encryption
  enable_node_public_ip        = var.linux_node_pool_enable_node_public_ip
  orchestrator_version         = var.kubernetes_version
  max_pods                     = var.linux_node_pool_max_pods
  max_count                    = var.linux_node_pool_max_count
  min_count                    = var.linux_node_pool_min_count
  node_count                   = var.linux_node_pool_node_count
  os_type                      = var.linux_node_pool_os_type
  os_sku                       = var.linux_node_pool_os_sku
  priority                     = var.linux_node_pool_priority
  tags                         = var.tags

  #spg: must have aks cluster first
  depends_on = [
    module.aks_cluster, module.spoke_network
  ]
}

#create a windows 2022 node pool for windows/iis workloads
module "windows_node_pool" {
  source = "./modules/node_pool"
  resource_group_name = azurerm_resource_group.rg.name
  kubernetes_cluster_id = module.aks_cluster.id
  name                         = var.windows_node_pool_name
  vm_size                      = var.windows_node_pool_vm_size
  mode                         = var.windows_node_pool_mode
  node_labels                  = var.windows_node_pool_node_labels
  node_taints                  = var.windows_node_pool_node_taints
  availability_zones           = var.windows_node_pool_availability_zones
  vnet_subnet_id               = module.spoke_network.subnet_ids[var.aks_subnet_name]
  enable_auto_scaling          = var.windows_node_pool_enable_auto_scaling
  enable_host_encryption       = var.windows_node_pool_enable_host_encryption
  enable_node_public_ip        = var.windows_node_pool_enable_node_public_ip
  orchestrator_version         = var.kubernetes_version
  max_pods                     = var.windows_node_pool_max_pods
  max_count                    = var.windows_node_pool_max_count
  min_count                    = var.windows_node_pool_min_count
  node_count                   = var.windows_node_pool_node_count
  os_type                      = var.windows_node_pool_os_type
  os_sku                       = var.windows_node_pool_os_sku
  priority                     = var.windows_node_pool_priority
  tags                         = var.tags

  # Windows Node Pools must have outbound nat disabled 
  # in order to work with AppGateway health checks
  windows_profile_enabled      = true
  outbound_nat_enabled         = false 

  #spg: must have aks cluster first
  depends_on = [
    module.aks_cluster, module.spoke_network
  ]
}

# Generate random name for storage account
resource "random_string" "storage_account_suffix" {
  length  = 8
  special = false
  lower   = true
  upper   = false
  numeric  = false
}

# Generate random number for aks storage account
resource "random_string" "aks_storage_account_suffix" {
  length  = 8
  special = false
  lower   = false
  upper   = false
  numeric  = true
}

module "storage_account" {
  source                      = "./modules/storage_account"
  name                        = "bootdiag${random_string.storage_account_suffix.result}"
  location                    = var.location
  tags                        = var.tags
  resource_group_name         = azurerm_resource_group.security-rg.name
  account_kind                = var.storage_account_kind
  account_tier                = var.storage_account_tier
  replication_type            = var.storage_account_replication_type

  depends_on = [
    azurerm_resource_group.security-rg
  ]  
}

module "aks_storage_account" {
  source                      = "./modules/storage_account"
  name                        = "orderlogixaks${random_string.aks_storage_account_suffix.result}"
  location                    = var.location
  tags                        = var.tags
  resource_group_name         = azurerm_resource_group.rg.name
  account_kind                = var.storage_account_kind
  account_tier                = var.storage_account_tier
  replication_type            = var.storage_account_replication_type

  depends_on = [
    azurerm_resource_group.rg
  ]  
}

resource "azurerm_storage_share" "storage-share-certs" {
  name                 = "certs"
  storage_account_name = module.aks_storage_account.name
  quota                = 5120
  access_tier          = "TransactionOptimized"
  
  depends_on = [
    module.aks_storage_account
  ]  
}

resource "azurerm_storage_share" "storage-share-iislogs" {
  name                 = "iislogs"
  storage_account_name = module.aks_storage_account.name
  quota                = 5120
  access_tier          = "TransactionOptimized"

  depends_on = [
    module.aks_storage_account
  ]  
}

resource "azurerm_storage_share" "storage-share-instance-config" {
  name                 = "instance-config"
  storage_account_name = module.aks_storage_account.name
  quota                = 5120
  access_tier          = "TransactionOptimized"

  depends_on = [
    module.aks_storage_account
  ]  
}

resource "azurerm_storage_share" "storage-share-db-schemas" {
  name                 = "db-schemas"
  storage_account_name = module.aks_storage_account.name
  quota                = 5120
  access_tier          = "TransactionOptimized"

  depends_on = [
    module.aks_storage_account
  ]  
}


module "bastion_host" {
  source                       = "./modules/bastion_host"
  name                         = var.bastion_host_name
  location                     = var.location
  resource_group_name          = azurerm_resource_group.hub-rg.name
  subnet_id                    = module.hub_network.subnet_ids["AzureBastionSubnet"]
  log_analytics_workspace_id   = module.log_analytics_workspace.id
  log_analytics_retention_days = var.log_analytics_retention_days

  depends_on = [
    azurerm_resource_group.hub-rg, module.hub_network, module.log_analytics_workspace
  ]  
}

module "windows_jumpbox_virtual_machine" {
  source                              = "./modules/windows_virtual_machine"
  name                                = var.jumpbox_vm_name
  size                                = var.windows_vm_size
  location                            = var.location
  os_disk_image                       = var.vm_windows_os_disk_image
  public_ip                           = var.vm_public_ip
  vm_user                             = var.admin_username
/*   az_devops_url                       = var.azure_devops_url
  az_devops_pat                       = var.azure_devops_pat
  az_devops_agentpool_name            = var.azure_devops_agent_pool_name */
  domain_name_label                   = var.domain_name_label
  resource_group_name                 = azurerm_resource_group.jumpbox-rg.name
  subnet_id                           = module.spoke_network.subnet_ids[var.vm_subnet_name]
  os_disk_storage_account_type        = var.vm_os_disk_storage_account_type
  boot_diagnostics_storage_account    = module.storage_account.primary_blob_endpoint
  log_analytics_workspace_id          = module.log_analytics_workspace.workspace_id
  log_analytics_workspace_key         = module.log_analytics_workspace.primary_shared_key
  log_analytics_workspace_resource_id = module.log_analytics_workspace.id
  log_analytics_retention_days        = var.log_analytics_retention_days
  script_storage_account_name         = var.script_storage_account_name
  script_storage_account_key          = var.script_storage_account_key
  container_name                      = var.container_name
  script_name                         = var.jumpbox_configuration_script_name

  depends_on = [ 
    azurerm_resource_group.jumpbox-rg, module.spoke_network, module.storage_account, module.log_analytics_workspace
  ]
}

module "linux_build_agent_virtual_machine" {
  source                              = "./modules/virtual_machine"
  name                                = var.linux_build_vm_name
  size                                = var.vm_size
  location                            = var.location
  public_ip                           = var.vm_public_ip
  vm_user                             = var.admin_username
  az_devops_url                       = var.azure_devops_url
  az_devops_pat                       = var.azure_devops_pat
  az_devops_agentpool_name            = var.azure_devops_agent_pool_name
  admin_ssh_public_key                = var.ssh_public_key
  os_disk_image                       = var.vm_os_disk_image
  domain_name_label                   = var.domain_name_label
  resource_group_name                 = azurerm_resource_group.jumpbox-rg.name
  subnet_id                           = module.spoke_network.subnet_ids[var.vm_subnet_name]
  os_disk_storage_account_type        = var.vm_os_disk_storage_account_type
  boot_diagnostics_storage_account    = module.storage_account.primary_blob_endpoint
  log_analytics_workspace_id          = module.log_analytics_workspace.workspace_id
  log_analytics_workspace_key         = module.log_analytics_workspace.primary_shared_key
  log_analytics_workspace_resource_id = module.log_analytics_workspace.id
  log_analytics_retention_days        = var.log_analytics_retention_days
  script_storage_account_name         = var.script_storage_account_name
  script_storage_account_key          = var.script_storage_account_key
  container_name                      = var.container_name
  script_name                         = var.linux_build_agent_configiuration_script_name

  depends_on = [
    azurerm_resource_group.jumpbox-rg, module.spoke_network, module.storage_account, module.log_analytics_workspace
  ]
}

module "windows_build_agent_virtual_machine" {
  source                              = "./modules/windows_virtual_machine"
  name                                = var.windows_build_vm_name
  size                                = var.windows_vm_size
  location                            = var.location
  public_ip                           = var.vm_public_ip
  vm_user                             = var.admin_username
/*   az_devops_url                       = var.azure_devops_url
  az_devops_pat                       = var.azure_devops_pat
  az_devops_agentpool_name            = var.azure_devops_agent_pool_name */
  os_disk_image                       = var.vm_windows_os_disk_image
  disk_size                           = 500
  domain_name_label                   = var.domain_name_label
  resource_group_name                 = azurerm_resource_group.jumpbox-rg.name
  subnet_id                           = module.spoke_network.subnet_ids[var.vm_subnet_name]
  os_disk_storage_account_type        = var.vm_os_disk_storage_account_type
  boot_diagnostics_storage_account    = module.storage_account.primary_blob_endpoint
  log_analytics_workspace_id          = module.log_analytics_workspace.workspace_id
  log_analytics_workspace_key         = module.log_analytics_workspace.primary_shared_key
  log_analytics_workspace_resource_id = module.log_analytics_workspace.id
  log_analytics_retention_days        = var.log_analytics_retention_days
  script_storage_account_name         = var.script_storage_account_name
  script_storage_account_key          = var.script_storage_account_key
  container_name                      = var.container_name
  script_name                         = var.windows_build_agent_configiuration_script_name
  script_arguments = [var.azure_devops_url,var.azure_devops_pat,var.azure_devops_agent_pool_name]

  depends_on = [ 
    azurerm_resource_group.jumpbox-rg, module.spoke_network, module.storage_account, module.log_analytics_workspace
  ]
}

module "key_vault" {
  source                          = "./modules/key_vault"
  name                            = var.key_vault_name
  location                        = var.location
  resource_group_name             = azurerm_resource_group.rg.name
  principal_id                    = var.admin_group_object_ids[0]
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  sku_name                        = var.key_vault_sku_name
  tags                            = var.tags
  kubernetes_cluster              = module.aks_cluster
  enabled_for_deployment          = var.key_vault_enabled_for_deployment
  enabled_for_disk_encryption     = var.key_vault_enabled_for_disk_encryption
  enabled_for_template_deployment = var.key_vault_enabled_for_template_deployment
  enable_rbac_authorization       = var.key_vault_enable_rbac_authorization
  purge_protection_enabled        = var.key_vault_purge_protection_enabled
  soft_delete_retention_days      = var.key_vault_soft_delete_retention_days
  bypass                          = var.key_vault_bypass
  default_action                  = var.key_vault_default_action
  log_analytics_workspace_id      = module.log_analytics_workspace.id
  log_analytics_retention_days    = var.log_analytics_retention_days

  depends_on = [
    azurerm_resource_group.rg, module.log_analytics_workspace
  ]
}

/*module "sql_managed_instance" {
  source = "./modules/sql_managed_instance"
  name                = var.sql_managed_instance_name
  location            = var.location
  resource_group_name = azurerm_resource_group.sql-mi-rg.name
  subnet_id           = module.spoke_network.subnet_ids[var.sqlmi_subnet_name]
  address_prefixes    = var.sqlmi_subnet_address_prefix[0]
  
  depends_on = [
    azurerm_resource_group.sql-mi-rg, module.spoke_network, module.routetable
  ]
}*/


module "acr_private_dns_zone" {
  source                       = "./modules/private_dns_zone"
  name                         = "privatelink.azurecr.io"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_networks_to_link     = {
    (module.hub_network.name) = {
      subscription_id = data.azurerm_client_config.current.subscription_id
      resource_group_name = azurerm_resource_group.hub-rg.name
    }
    (module.spoke_network.name) = {
      subscription_id = data.azurerm_client_config.current.subscription_id
      resource_group_name = azurerm_resource_group.spoke-rg.name
    }
  }

  depends_on = [
    azurerm_resource_group.rg, azurerm_resource_group.hub-rg, azurerm_resource_group.spoke-rg
  ]
}

module "key_vault_private_dns_zone" {
  source                       = "./modules/private_dns_zone"
  name                         = "privatelink.vaultcore.azure.net"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_networks_to_link     = {
    (module.hub_network.name) = {
      subscription_id = data.azurerm_client_config.current.subscription_id
      resource_group_name = azurerm_resource_group.hub-rg.name
    }
    (module.spoke_network.name) = {
      subscription_id = data.azurerm_client_config.current.subscription_id
      resource_group_name = azurerm_resource_group.spoke-rg.name
    }
  }

  depends_on = [
    azurerm_resource_group.rg, azurerm_resource_group.hub-rg, azurerm_resource_group.spoke-rg
  ]
}

module "sqlmi_private_dns_zone" {
  source                       = "./modules/private_dns_zone"
  name                         = "privatelink.database.windows.net"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_networks_to_link     = {
    (module.hub_network.name) = {
      subscription_id = data.azurerm_client_config.current.subscription_id
      resource_group_name = azurerm_resource_group.hub-rg.name
    }
    (module.spoke_network.name) = {
      subscription_id = data.azurerm_client_config.current.subscription_id
      resource_group_name = azurerm_resource_group.spoke-rg.name
    }
  }

  depends_on = [
    azurerm_resource_group.rg, azurerm_resource_group.hub-rg, azurerm_resource_group.spoke-rg
  ]
}

module "blob_private_dns_zone" {
  source                       = "./modules/private_dns_zone"
  name                         = "privatelink.blob.core.windows.net"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_networks_to_link     = {
    (module.hub_network.name) = {
      subscription_id = data.azurerm_client_config.current.subscription_id
      resource_group_name = azurerm_resource_group.hub-rg.name
    }
    (module.spoke_network.name) = {
      subscription_id = data.azurerm_client_config.current.subscription_id
      resource_group_name = azurerm_resource_group.spoke-rg.name
    }
  }

  depends_on = [
    azurerm_resource_group.rg, azurerm_resource_group.hub-rg, azurerm_resource_group.spoke-rg
  ]
}

module "acr_private_endpoint" {
  source                         = "./modules/private_endpoint"
  name                           = "${module.container_registry.name}PrivateEndpoint"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.rg.name
  subnet_id                      = module.spoke_network.subnet_ids[var.vm_subnet_name]
  tags                           = var.tags
  private_connection_resource_id = module.container_registry.id
  is_manual_connection           = false
  subresource_name               = "registry"
  private_dns_zone_group_name    = "AcrPrivateDnsZoneGroup"
  private_dns_zone_group_ids     = [module.acr_private_dns_zone.id]

  depends_on = [
    module.container_registry, module.acr_private_dns_zone, azurerm_resource_group.rg, module.spoke_network
  ]
}

module "key_vault_private_endpoint" {
  source                         = "./modules/private_endpoint"
  name                           = "${title(module.key_vault.name)}PrivateEndpoint"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.rg.name
  subnet_id                      = module.spoke_network.subnet_ids[var.vm_subnet_name]
  tags                           = var.tags
  private_connection_resource_id = module.key_vault.id
  is_manual_connection           = false
  subresource_name               = "vault"
  private_dns_zone_group_name    = "KeyVaultPrivateDnsZoneGroup"
  private_dns_zone_group_ids     = [module.key_vault_private_dns_zone.id]

  depends_on = [
    module.key_vault, module.key_vault_private_dns_zone, azurerm_resource_group.rg, module.spoke_network
  ]
}

module "blob_private_endpoint" {
  source                         = "./modules/private_endpoint"
  name                           = "${title(module.storage_account.name)}PrivateEndpoint"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.rg.name
  subnet_id                      = module.spoke_network.subnet_ids[var.vm_subnet_name]
  tags                           = var.tags
  private_connection_resource_id = module.storage_account.id
  is_manual_connection           = false
  subresource_name               = "blob"
  private_dns_zone_group_name    = "BlobPrivateDnsZoneGroup"
  private_dns_zone_group_ids     = [module.blob_private_dns_zone.id]

  depends_on = [
    module.storage_account, module.blob_private_dns_zone, azurerm_resource_group.rg, module.spoke_network
  ]
}

module "managedPrometheus" {
  source                          = "./modules/monitor_workspace"
  name                            = var.monitor_workspace_name
  location                        = var.location
  resource_group_name             = azurerm_resource_group.rg.name
  resource_group_id               = azurerm_resource_group.rg.id
  principal_id                    = var.admin_group_object_ids[0]
  kubernetes_cluster              = module.aks_cluster
}

/*module "sqlmi_private_endpoint" {
  source                         = "./modules/private_endpoint"
  name                           = "${var.sql_managed_instance_name}PrivateEndpoint"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.rg.name
  subnet_id                      = module.spoke_network.subnet_ids[var.vm_subnet_name]
  tags                           = var.tags
  private_connection_resource_id = module.sql_managed_instance.id
  is_manual_connection           = false
  subresource_name               = "managedInstance"
  private_dns_zone_group_name    = "SqlmiPrivateDnsZoneGroup"
  private_dns_zone_group_ids     = [module.sqlmi_private_dns_zone.id]

  depends_on = [
    module.sql_managed_instance, module.sqlmi_private_dns_zone, azurerm_resource_group.rg, module.spoke_network
  ]
}*/