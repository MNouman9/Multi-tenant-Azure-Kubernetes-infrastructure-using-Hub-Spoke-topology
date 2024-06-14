variable "location" {
  description = "Specifies the location for the resource group and all the resources"
  default     = "eastus"
  type        = string
}

variable "tags" {
  description = "(Optional) Specifies tags for all the resources"
  default     = {
    createdWith = "Terraform"
  }
}

variable "security_contact_email" {
  description = "Specifies the security contact email"
  default     = "sgiftos@orderlogix.com"
  type        = string
}
variable "security_contact_phone" {
  description = "Specifies the security contact phone"
  default     = "+12077126756"
  type        = string
}

variable "security_resource_group_name" {
  description = "Specifies the resource group name"
  default     = "rg-security"
  type        = string
}

variable "resource_group_name" {
  description = "Specifies the resource group name"
  default     = "rg-orderlogix"
  type        = string
}

variable "hub_network_resource_group_name" {
  description = "Specifies the resource group name"
  default     = "rg-enterprise-networking-hubs"
  type        = string
}

variable "spoke_network_resource_group_name" {
  description = "Specifies the resource group name"
  default     = "rg-enterprise-networking-spokes"
  type        = string
}

variable "vm_network_resource_group_name" {
  description = "Specifies the resource group name"
  default     = "rg-virtual-machines"
  type        = string
}

variable "sql_mi_resource_group_name" {
  description = "Specifies the resource group name"
  default     = "rg-sql-managed-instances"
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "Specifies the name of the log analytics workspace"
  default     = "BaboAksWorkspace"
  type        = string
}

variable "log_analytics_retention_days" {
  description = "Specifies the number of days of the retention policy"
  type        = number
  default     = 30
}

variable "solution_plan_map" {
  description = "Specifies solutions to deploy to log analytics workspace"
  default     = {
    ContainerInsights= {
      product   = "OMSGallery/ContainerInsights"
      publisher = "Microsoft"
    }
  }
  type = map(any)
}

variable "acr_name" {
  description = "Specifies the name of the container registry"
  type        = string
  default     = "acr-orderlogix"
}

variable "aks_cluster_name" {
  description = "(Required) Specifies the name of the AKS cluster."
  default     = "aks-orderlogix-private"
  type        = string
}

variable "bastion_host_name" {
  description = "(Optional) Specifies the name of the bastion host"
  default     = "bh-orderlogix"
  type        = string
}

variable "key_vault_name" {
  description = "Specifies the name of the key vault."
  type        = string
  default     = "kv-orderlogix"
}

variable "application_gateway_name" {
  description = "Specifies the name of the app gateway"
  default     =  "appgw-orderlogix"
  type        = string
}

variable "nat_gateway_name" {
  description = "Specifies the name of the app gateway"
  default     =  "natgw-orderlogix"
  type        = string
}

variable "sql_managed_instance_name" {
  description = "Specifies the name of the SQL Managed Instance"
  default     =  "sql-mi-orderlogix"
  type        = string
}
