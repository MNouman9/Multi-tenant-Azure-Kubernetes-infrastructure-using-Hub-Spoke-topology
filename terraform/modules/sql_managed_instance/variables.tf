variable "prefix" {
  type        = string
  default     = "mi"
  description = "Prefix of the resource name"
}

variable "name" {
  description = "(Required) Specifies the name of the resource."
  type        = string
}

variable "resource_group_name" {
  description = "(Required) Specifies the resource group name of the resource."
  type        = string
}

variable "location" {
  type        = string
  description = "Enter the location where you want to deploy the resources"
  default     = "eastus"
}

variable "subnet_id" {
  description = "The ID of a Subnet where the SQL MI should exist."
  type        = string
}


variable "sku_name" {
  type        = string
  description = "Enter SKU"
  default     = "GP_Gen5"
}

variable "license_type" {
  type        = string
  description = "Enter license type"
  default     = "LicenseIncluded"
}

variable "vcores" {
  type        = number
  description = "Enter number of vCores you want to deploy"
  default     = 4
}

variable "storage_size_in_gb" {
  type        = number
  description = "Enter storage size in GB"
  default     = 256
}

variable "timezone_id" {
  type        = string
  description = "(Optional) The TimeZone ID that the SQL Managed Instance will be operating in. Default value is UTC. Changing this forces a new resource to be created."
  default     = "Eastern Standard Time"
}

variable sql_user {
  description = "(Required) Specifies the username of the sql managed instance"
  type        = string
  default     = "orderlogixSqlAdmin"
}
variable sql_user_password {
  description = "(Required) Specifies the username of the sql managed instance"
  type        = string
  default     = "P@ssw0rd1234!"
}

variable "maintenance_configuration_name" {
  type        = string
  description = "Enter maintenance configuration name"
  default     = "SQL_EastUS_MI_2"
}

variable "address_prefixes" {
  type        = string
  description = "subnet address prefix"
  default     = "10.0.0.0/24"
}

variable "tags" {
  description = "(Optional) Specifies the tags of theresource"
  default     = {}
}