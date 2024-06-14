variable "name" {
  description = "(Required) Specifies the name of the managed prometheus and grafana."
  type        = string
}
variable "resource_group_name" {
  description = "(Required) Specifies the name of the resource group."
  type        = string
}

variable "resource_group_id" {
  description = "(Required) Specifies the resource id of the resource group."
  type        = string
}

variable "location" {
  description = "(Required) Specifies the location where the AKS cluster will be deployed."
  type        = string
}

variable "principal_id" {
  description = "specify admin group ID"
  type = string
}

variable "kubernetes_cluster" {
  description = "Sprecify Kubernetes"
  type = string
}