variable "hub_vnet_name" {
  description = "Specifies the name of the hub virtual network"
  default     = "vent-hub"
  type        = string
}

variable "hub_address_space" {
  description = "Specifies the address space of the hub virtual network"
  default     = ["10.200.0.0/24"]
  type        = list(string)
}

variable "hub_firewall_subnet_address_prefix" {
  description = "Specifies the address prefix of the firewall subnet"
  default     = ["10.200.0.0/26"]
  type        = list(string)
}

variable "hub_bastion_subnet_address_prefix" {
  description = "Specifies the address prefix of the bastion subnet"
  default     = ["10.200.0.96/27"]
  type        = list(string)
}

variable "spoke_vnet_name" {
  description = "Specifies the name of the spoke virtual network"
  default     = "vnets-spokes"
  type        = string
}

variable "spoke_vnet_address_space" {
  description = "Specifies the address prefix of the spoke virtual network"
  default     =  ["10.240.0.0/16"]
  type        = list(string)
}

variable "aks_subnet_name" {
  description = "Specifies the name of the AKS subnet"
  default     = "snet-clusternodes"
  type        = string
}

variable "aks_subnet_address_prefix" {
  description = "Specifies the address prefix of the subnet that hosts the default node pool"
  default     =  ["10.240.0.0/22"]
  type        = list(string)
}


variable "vm_subnet_name" {
  description = "Specifies the name of the jumpbox subnet"
  default     = "snet-virtualmachines"
  type        = string
}

variable "vm_subnet_address_prefix" {
  description = "Specifies the address prefix of the jumbox subnet"
  default     = ["10.240.5.16/28"]
  type        = list(string)
}
#spg: 20230305: Added Variables for Application Gateway, SQL Managed INstance and SSRS
variable "application_gateway_subnet_name" {
  description = "Specifies the name of the app gateway subnet"
  default     =  "snet-applicationgateway"
  type        = string
}

variable "application_gateway_subnet_address_prefix" {
  description = "Specifies the address prefix of the app gateway subnet"
  default     = ["10.240.4.16/28"]
  type        = list(string)
}

variable "sqlmi_subnet_name" {
  description = "Specifies the name of the sql managed instance subnet"
  default     =  "snet-sqlmi"
  type        = string
}

variable "sqlmi_subnet_address_prefix" {
  description = "Specifies the address prefix of the sql managed instance subnet"
  default     = ["10.240.4.64/26"]
  type        = list(string)
}
variable "ssrs_subnet_name" {
  description = "Specifies the name of the ssrs subnet"
  default     =  "snet-ssrs"
  type        = string
}

variable "ssrs_subnet_address_prefix" {
  description = "Specifies the address prefix of the ssrs subnet"
  default     = ["10.240.4.32/28"]
  type        = list(string)
}

variable "nat_gateway_subnet_name" {
  description = "Specifies the name of the Nat_gateway subnet"
  default     = "NatGatewaySubnet"
  type        = string
}

variable "nat_gateway_subnet_address_prefix" {
  description = "Specifies the address prefix of the Nat_gateway subnet"
  default     = ["10.0.9.0/21"]
  type        = list(string)
}


#firewall settings
variable "firewall_name" {
  description = "Specifies the name of the Azure Firewall"
  default     = "fw-eastus"
  type        = string
}

variable "firewall_sku_tier" {
  description = "Specifies the SKU tier of the Azure Firewall"
  default     = "Standard"
  type        = string
}

variable "firewall_threat_intel_mode" {
  description = "(Optional) The operation mode for threat intelligence-based filtering. Possible values are: Off, Alert, Deny. Defaults to Alert."
  default     = "Deny"
  type        = string

  validation {
    condition = contains(["Off", "Alert", "Deny"], var.firewall_threat_intel_mode)
    error_message = "The threat intel mode is invalid."
  }
}

variable "firewall_zones" {
  description = "Specifies the availability zones of the Azure Firewall"
  default     = ["1", "2", "3"]
  type        = list(string)
}
