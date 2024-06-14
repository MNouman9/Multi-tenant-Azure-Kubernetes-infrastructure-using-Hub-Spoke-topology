terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }

  required_version = ">= 0.14.9"
}

resource "azurerm_public_ip" "pip-fw-eastus-default" {
  name                = var.pip-fw-eastus-default
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  zones               = var.zones
  sku                 = "Standard"
  tags                = var.tags

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_public_ip" "pip-fw-eastus-01" {
  name                = var.pip-fw-eastus-01
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  zones               = var.zones
  sku                 = "Standard"
  tags                = var.tags

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_public_ip" "pip-fw-eastus-02" {
  name                = var.pip-fw-eastus-02
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  zones               = var.zones
  sku                 = "Standard"
  tags                = var.tags

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_firewall" "firewall" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
  zones               = var.zones
  threat_intel_mode   = var.threat_intel_mode
  sku_tier            = var.sku_tier
  sku_name            = "AZFW_VNet"
  firewall_policy_id  = azurerm_firewall_policy.policy.id


  ip_configuration {
    name                 = "fw_ip_config"
    subnet_id            = var.subnet_id
    public_ip_address_id = azurerm_public_ip.pip-fw-eastus-default.id
  }

  lifecycle {
    ignore_changes = [
      tags,
      
    ]
  }
}

resource "azurerm_firewall_policy" "policy" {
  name                = "${var.name}Policy"
  resource_group_name = var.resource_group_name
  location            = var.location

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "policy" {
  name               = "AksEgressPolicyRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.policy.id
  priority           = 500

  application_rule_collection {
    name     = "ApplicationRules"
    priority = 500
    action   = "Allow"

    rule {
      name             = "AllowMicrosoftFqdns"
      source_addresses = ["*"]

      destination_fqdns = [
        "*.cdn.mscr.io",
        "mcr.microsoft.com",
        "*.data.mcr.microsoft.com",
        "management.azure.com",
        "login.microsoftonline.com",
        "acs-mirror.azureedge.net",
        "dc.services.visualstudio.com",
        "*.opinsights.azure.com",
        "*.oms.opinsights.azure.com",
        "*.microsoftonline.com",
        "*.monitoring.azure.com",
      ]

      protocols {
        port = "80"
        type = "Http"
      }

      protocols {
        port = "443"
        type = "Https"
      }
    }

    rule {
      name             = "AllowFqdnsForOsUpdates"
      source_addresses = ["*"]

      destination_fqdns = [
        "download.opensuse.org",
        "security.ubuntu.com",
        "ntp.ubuntu.com",
        "packages.microsoft.com",
        "snapcraft.io"
      ]

      protocols {
        port = "80"
        type = "Http"
      }

      protocols {
        port = "443"
        type = "Https"
      }
    }
    
    rule {
      name             = "AllowImagesFqdns"
      source_addresses = ["*"]

      destination_fqdns = [
        "auth.docker.io",
        "registry-1.docker.io",
        "production.cloudflare.docker.com"
      ]

      protocols {
        port = "80"
        type = "Http"
      }

      protocols {
        port = "443"
        type = "Https"
      }
    }

    rule {
      name             = "AllowBing"
      source_addresses = ["*"]

      destination_fqdns = [
        "*.bing.com"
      ]

      protocols {
        port = "80"
        type = "Http"
      }

      protocols {
        port = "443"
        type = "Https"
      }
    }

    rule {
      name             = "AllowGoogle"
      source_addresses = ["*"]

      destination_fqdns = [
        "*.google.com"
      ]

      protocols {
        port = "80"
        type = "Http"
      }

      protocols {
        port = "443"
        type = "Https"
      }
    }
  }

  network_rule_collection {
    name     = "NetworkRules"
    priority = 400
    action   = "Allow"

    rule {
      name                  = "Time"
      source_addresses      = ["*"]
      destination_ports     = ["123"]
      destination_addresses = ["*"]
      protocols             = ["UDP"]
    }

    rule {
      name                  = "DNS"
      source_addresses      = ["*"]
      destination_ports     = ["53"]
      destination_addresses = ["*"]
      protocols             = ["UDP"]
    }

    rule {
      name                  = "ServiceTags"
      source_addresses      = ["*"]
      destination_ports     = ["*"]
      destination_addresses = [
        "AzureContainerRegistry",
        "MicrosoftContainerRegistry",
        "AzureActiveDirectory"
      ]
      protocols             = ["Any"]
    }

    rule {
      name                  = "Internet"
      source_addresses      = ["*"]
      destination_ports     = ["*"]
      destination_addresses = ["*"]
      protocols             = ["TCP"]
    }
#The following rules are configured specifically from the portal when we first tested it
    rule {
      name                  = "Allow_80"
      source_addresses      = ["10.240.0.66","10.240.4.36","10.240.4.37"]
      destination_ports     = ["443"]
      destination_addresses = ["80"]
      protocols             = ["TCP"]
    }
    
    rule {
      name                  = "443_out"
      source_addresses      = ["10.240.0.0/16"]
      destination_ports     = ["443"]
      destination_addresses = ["*"]
      protocols             = ["TCP"]
    }

    rule {
      name                  = "SQLMail-fqdn"
      source_addresses      = ["10.240.4.64/26"]
      destination_ports     = ["587"]
      destination_addresses = ["mx.tidalhosting.com"]
      protocols             = ["TCP"]
    }

    rule {
      name                  = "FTP-clientx"
      source_addresses      = ["10.240.0.0/22"]
      destination_ports     = ["22"]
      destination_addresses = ["abc.com"]
      protocols             = ["TCP"]
    }

    rule {
      name                  = "FTP-clienty"
      source_addresses      = ["10.240.0.0/22"]
      destination_ports     = ["22"]
      destination_addresses = ["def.com"]
      protocols             = ["TCP"]
    }
  }

  lifecycle {
    ignore_changes = [
      application_rule_collection,
      network_rule_collection,
      nat_rule_collection
    ]
  }
}

resource "azurerm_monitor_diagnostic_setting" "settings" {
  name                       = "DiagnosticsSettings"
  target_resource_id         = azurerm_firewall.firewall.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AzureFirewallApplicationRule"
  }

  enabled_log {
    category = "AzureFirewallNetworkRule"
  }

  enabled_log {
    category = "AzureFirewallDnsProxy"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "pip_settings" {
  name                       = "DiagnosticsSettings"
  target_resource_id         = azurerm_public_ip.pip-fw-eastus-default.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "DDoSProtectionNotifications"
  }

  enabled_log {
    category = "DDoSMitigationFlowLogs"
  }

  enabled_log {
    category = "DDoSMitigationReports"
  }

  metric {
    category = "AllMetrics"
  }
}