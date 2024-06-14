variable "resource_group_name" {
  description = "(Required) Specifies the name of the resource group."
  type        = string
}

variable "location" {
  description = "(Required) Specifies the location where the resource will be deployed."
  type        = string
}

variable "security_contact_email" {
  description = "(Required) Specifies the email address for security alerts."
  type        = string
}

variable "security_contact_phone" {
  description = "(Optional) Specifies the phone number for security alerts.."
  type        = string
}


