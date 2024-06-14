variable "resource_group_name" {
  description = "(Required) Specifies the resource group name of the bastion host"
  type        = string
}

variable "name" {
  description = "(Required) Specifies the name of the bastion host"
  type        = string
}

variable "location" {
  description = "(Required) Specifies the location of the bastion host"
  type        = string
}

variable "tags" {
  description = "(Optional) Specifies the tags of the bastion host"
  default     = {}
}

variable "sku" {
  description = " (Optional) The SKU of the Bastion Host. Accepted values are Basic and Standard. Defaults to Basic."
  default     = "Standard"
  
  validation {
    condition = contains( ["Basic", "Standard"], var.sku)
    error_message = "The SKU of the Bastion Host is invalid."
  }
}

variable "subnet_id" {
  description = "(Required) Specifies subnet id of the bastion host"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Specifies the log analytics workspace id"
  type        = string
}

variable "log_analytics_retention_days" {
  description = "Specifies the number of days of the retention policy"
  type        = number
  default     = 7
}