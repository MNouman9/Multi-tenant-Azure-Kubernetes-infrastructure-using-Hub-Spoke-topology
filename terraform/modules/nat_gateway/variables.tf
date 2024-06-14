variable "name" {
  description = "(Required) Specifies the name of the NAT Gateway."
  type        = string
}

variable "resource_group_name" {
  description = "(Required) Specifies the name of the resource group."
  type        = string
}

variable "location" {
  description = "(Required) Specifies the location where the NAT Gateway will be deployed."
  type        = string
}

variable "availability_zones" {
  description = "(Optional) A list of Availability Zones where the NAT Gateway should be created in. Changing this forces a new resource to be created."
  type        = list(string)
  default     = [] #["1", "2", "3"]
}

variable "sku_name" {
  description = "(Optional) The SKU which should be used. At this time the only supported value is Standard. Defaults to Standard."
  type        = string
  default     = "Standard"
}

variable "idle_timeout_in_minutes" {
  description = "(Optional) The idle timeout which should be used in minutes. Defaults to 4."
  type        = number
  default     = 4
}

variable "subnet_id" {
  description = "(Required) The ID of the Subnet. Changing this forces a new resource to be created."
  type        = string
}