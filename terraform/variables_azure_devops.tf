variable "azure_devops_url" {
  description = "(Required) Specifies the URL of the target Azure DevOps organization."
  type        = string
}

variable "azure_devops_pat" {
  description = "(Required) Specifies the personal access token of the target Azure DevOps organization."
  type        = string
}

variable "azure_devops_agent_pool_name" {
  description = "(Required) Specifies the name of the agent pool in the Azure DevOps organization."
  type        = string
}