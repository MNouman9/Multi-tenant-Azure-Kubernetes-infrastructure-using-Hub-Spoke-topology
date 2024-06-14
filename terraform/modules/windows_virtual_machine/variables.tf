variable resource_group_name {
  description = "(Required) Specifies the resource group name of the virtual machine"
  type = string
}

variable name {
  description = "(Required) Specifies the name of the virtual machine"
  type = string
}

variable size {
  description = "(Required) Specifies the size of the virtual machine"
  type = string
}

variable "os_disk_image" {
  type        = map(string)
  description = "(Optional) Specifies the os disk image of the virtual machine"
  default     = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter"
    version   = "latest"
  }
}

variable "disk_size" {
  description = "Enable or disable the second disk"
  type        = string
  default     = 100
}

variable "os_disk_storage_account_type" {
  description = "(Optional) Specifies the storage account type of the os disk of the virtual machine"
  default     = "StandardSSD_LRS"
  type        = string

  validation {
    condition = contains(["Premium_LRS", "Premium_ZRS", "StandardSSD_LRS", "StandardSSD_ZRS",  "Standard_LRS"], var.os_disk_storage_account_type)
    error_message = "The storage account type of the OS disk is invalid."
  }
}

variable public_ip {
  description = "(Optional) Specifies whether create a public IP for the virtual machine"
  type = bool
  default = false
}

variable location {
  description = "(Required) Specifies the location of the virtual machine"
  type = string
}

variable domain_name_label {
  description = "(Required) Specifies the DNS domain name of the virtual machine"
  type = string
}

variable subnet_id {
  description = "(Required) Specifies the resource id of the subnet hosting the virtual machine"
  type        = string
}

variable vm_user {
  description = "(Required) Specifies the username of the virtual machine"
  type        = string
  default     = "azadmin"
}
variable vm_password {
  description = "(Required) Specifies the username of the virtual machine"
  type        = string
  default     = "P@ssw0rd1234!"
}

variable "boot_diagnostics_storage_account" {
  description = "(Optional) The Primary/Secondary Endpoint for the Azure Storage Account (general purpose) which should be used to store Boot Diagnostics, including Console Output and Screenshots from the Hypervisor."
  default     = null
}

variable "tags" {
  description = "(Optional) Specifies the tags of the storage account"
  default     = {}
}

variable "log_analytics_workspace_id" {
  description = "Specifies the log analytics workspace id"
  type        = string
}

variable "log_analytics_workspace_key" {
  description = "Specifies the log analytics workspace key"
  type        = string
}

variable "log_analytics_workspace_resource_id" {
  description = "Specifies the log analytics workspace resource id"
  type        = string
}


variable "log_analytics_retention_days" {
  description = "Specifies the number of days of the retention policy"
  type        = number
  default     = 7
}

variable "script_storage_account_name" {
  description = "(Required) Specifies the name of the storage account that contains the custom script."
  type        = string
}

variable "script_storage_account_key" {
  description = "(Required) Specifies the name of the storage account that contains the custom script."
  type        = string
}

variable "container_name" {
  description = "(Required) Specifies the name of the container that contains the custom script."
  type        = string
}

variable "script_name" {
  description = "(Required) Specifies the name of the custom script."
  type        = string
}

variable "enable_automatic_updates" {
  description = "(Optional) Specifies whether enable automatic updates"
  type        = bool
  default     = true
}
variable "encryption_at_host_enabled" {
  description = "(Optional) Specifies whether enable encryption at host"
  type        = bool
  default     = true
  
}
variable "timezone" {
  description = "(Optional) Specifies the timezone of the virtual machine"
  type        = string
  default     = "Eastern Standard Time"
  
}

variable "script_arguments" {
  description = "(Optional) Specifies the arguments of the custom script."
  type        = list(string)
  default     = []
}

/* variable "az_devops_url" {
  description = "(Required) Specifies the URL of the target Azure DevOps organization."
  type        = string
}

variable "az_devops_pat" {
  description = "(Required) Specifies the personal access token of the target Azure DevOps organization."
  type        = string
}

variable "az_devops_agentpool_name" {
  description = "(Required) Specifies the name of the agent pool in the Azure DevOps organization."
  type        = string
} */