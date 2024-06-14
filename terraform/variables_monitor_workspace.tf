variable "monitor_workspace_name" {
  description = "(Required) Specifies the name of the managed prometheus."
  type        = string
}

variable "kubernetes_cluster" {
  description = "(Required) Specify the kubernetes cluster"
  type = any
}