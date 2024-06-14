terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
    }
  }

  required_version = ">= 0.14.9"
}

resource "azurerm_public_ip" "public_ip" {
  name                = "${var.name}PublicIp"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
  domain_name_label   = lower(var.domain_name_label)
  count               = var.public_ip ? 1 : 0
  tags                = var.tags

  lifecycle {
    ignore_changes = [
        tags
    ]
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.name}Nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  lifecycle {
    ignore_changes = [
        tags
    ]
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.name}Nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "Configuration"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    #public_ip_address_id          = try(azurerm_public_ip.public_ip[0].id, "")
  }

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
  depends_on = [azurerm_network_security_group.nsg]
}

resource "azurerm_linux_virtual_machine" "virtual_machine" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  network_interface_ids         = [azurerm_network_interface.nic.id]
  size                          = var.size
  computer_name                 = var.name
  admin_username                = var.vm_user
  custom_data                   = base64encode(data.template_file.linux-vm-init.rendered)
  tags                          = var.tags

  os_disk {
    name                 = "${var.name}OsDisk"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_storage_account_type
  }

  admin_ssh_key {
    username   = var.vm_user
    public_key = var.admin_ssh_public_key
  }

  source_image_reference {
    offer     = lookup(var.os_disk_image, "offer", null)
    publisher = lookup(var.os_disk_image, "publisher", null)
    sku       = lookup(var.os_disk_image, "sku", null)
    version   = lookup(var.os_disk_image, "version", null)
  }

  boot_diagnostics {
    storage_account_uri = var.boot_diagnostics_storage_account == "" ? null : var.boot_diagnostics_storage_account
  }

  lifecycle {
    ignore_changes = [
        tags
    ]
  }

  depends_on = [
    azurerm_network_interface.nic,
    azurerm_network_security_group.nsg
  ]
}

data "template_file" "linux-vm-init" {
  template = file("./scripts/${var.script_name}")
  vars = {
    vm_name = var.name
    vm_user = var.vm_user
    az_devops_url = var.az_devops_url
    az_devops_pat = var.az_devops_pat
    az_devops_agentpool_name = var.az_devops_agentpool_name
  }
}

resource "azurerm_virtual_machine_extension" "monitor_agent" {
  name                       = "${var.name}MonitoringAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.virtual_machine.id
  publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
  type                       = "OmsAgentForLinux"
  type_handler_version       = "1.12"
  auto_upgrade_minor_version = true
 
  settings = <<SETTINGS
    {
      "workspaceId": "${var.log_analytics_workspace_id}"
    }
  SETTINGS
 
  protected_settings = <<PROTECTED_SETTINGS
    {
      "workspaceKey": "${var.log_analytics_workspace_key}"
    }
  PROTECTED_SETTINGS

  lifecycle {
    ignore_changes = [
      tags
    ]
  }

  timeouts {
    create = "20m"
    delete = "30m"
  }

  depends_on = [
    azurerm_linux_virtual_machine.virtual_machine
    ]
}

resource "azurerm_virtual_machine_extension" "dependency_agent" {
  name                       = "${var.name}DependencyAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.virtual_machine.id
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentLinux"
  type_handler_version       = "9.10"
  auto_upgrade_minor_version = true
 
  settings = <<SETTINGS
    {
      "workspaceId": "${var.log_analytics_workspace_id}"
    }
  SETTINGS
 
  protected_settings = <<PROTECTED_SETTINGS
    {
      "workspaceKey": "${var.log_analytics_workspace_key}"
    }
  PROTECTED_SETTINGS

  lifecycle {
    ignore_changes = [
      tags
    ]
  }

  timeouts {
    create = "20m"
    delete = "30m"
  }

  depends_on = [
    azurerm_linux_virtual_machine.virtual_machine,
    azurerm_virtual_machine_extension.monitor_agent
    ]
}

resource "azurerm_security_center_server_vulnerability_assessment_virtual_machine" "linux_vm_vuln_assessment" {
  virtual_machine_id = azurerm_linux_virtual_machine.virtual_machine.id

  depends_on = [
    azurerm_linux_virtual_machine.virtual_machine,
    azurerm_virtual_machine_extension.monitor_agent,
    azurerm_virtual_machine_extension.dependency_agent
    ]
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "virtual_machine_auto_shutdown" {
  virtual_machine_id = azurerm_linux_virtual_machine.virtual_machine.id
  location           = var.location
  enabled            = true

  daily_recurrence_time = "2200"
  timezone              = "Eastern Standard Time"


  notification_settings {
    enabled         = true
    email           = "sgiftos@orderlogix.com"
    time_in_minutes = "60"
  }

  depends_on = [azurerm_linux_virtual_machine.virtual_machine]

 }

resource "azurerm_monitor_diagnostic_setting" "nsg_settings" {
  name                       = "DiagnosticsSettings"
  target_resource_id         = azurerm_network_security_group.nsg.id
  log_analytics_workspace_id = var.log_analytics_workspace_resource_id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

 enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }

  timeouts {
    create = "20m"
    delete = "30m"
  }

  depends_on = [azurerm_network_security_group.nsg]
}