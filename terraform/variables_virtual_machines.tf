variable "domain_name_label" {
  description = "Specifies the domain name for the jumbox virtual machine"
  default     = "babotestvm"
  type        = string
}

variable "linux_build_vm_name" {
  description = "Specifies the name of the jumpbox virtual machine"
  default     = "LinuxBuildAgent"
  type        = string
}
variable "windows_build_vm_name" {
  description = "Specifies the name of the jumpbox virtual machine"
  default     = "WinBuildAgent"
  type        = string
}
variable "jumpbox_vm_name" {
  description = "Specifies the name of the jumpbox virtual machine"
  default     = "aksJumpbox"
  type        = string
}

variable "vm_public_ip" {
  description = "(Optional) Specifies whether create a public IP for the virtual machine"
  type = bool
  default = false
}

variable "vm_size" {
  description = "Specifies the size of the jumpbox virtual machine"
  default     = "Standard_DS1_v2"
  type        = string
}

variable "windows_vm_size" {
  description = "Specifies the size of the windows jumpbox virtual machine"
  default     = "Standard_D4s_v3"
  type        = string
}

variable "vm_os_disk_storage_account_type" {
  description = "Specifies the storage account type of the os disk of the jumpbox virtual machine"
  default     = "Premium_LRS"
  type        = string

  validation {
    condition = contains(["Premium_LRS", "Premium_ZRS", "StandardSSD_LRS", "StandardSSD_ZRS",  "Standard_LRS"], var.vm_os_disk_storage_account_type)
    error_message = "The storage account type of the OS disk is invalid."
  }
}

variable "vm_os_disk_image" {
  type        = map(string)
  description = "Specifies the os disk image of the virtual machine"
  default     = {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS" 
    version   = "latest"
  }
}

variable "vm_windows_os_disk_image" {
  type        = map(string)
  description = "(Optional) Specifies the os disk image of the virtual machine"
  default     = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter"
    version   = "latest"
  }
}

variable "enable_second_disk" {
  description = "Enable or disable the second disk"
  type        = bool
  default     = false
}

variable "disk_size" {
  description = "Enable or disable the second disk"
  type        = string
  default     = 100
}

variable "admin_username" {
  description = "(Required) Specifies the admin username of the jumpbox virtual machine and AKS worker nodes."
  type        = string
  default     = "azadmin"
}

variable "ssh_public_key" {
  description = "(Required) Specifies the SSH public key for the jumpbox virtual machine and AKS worker nodes."
  type        = string
}


variable "container_name" {
  description = "(Required) Specifies the name of the container that contains the custom script."
  type        = string
  default     = "scripts"
}

variable "script_storage_account_name" {
  description = "(Required) Specifies the name of the storage account that contains the custom script."
  type        = string
}

variable "script_storage_account_key" {
  description = "(Required) Specifies the name of the storage account that contains the custom script."
  type        = string
}


variable "linux_build_agent_configiuration_script_name" {
  description = "(Required) Specifies the name of the custom script."
  type        = string
  default     = "configure-linux-build-agent-vm.sh.tftpl"
}
variable "windows_build_agent_configiuration_script_name" {
  description = "(Required) Specifies the name of the custom script."
  type        = string
  default     = "configure-windows-build-agent-vm.ps1"
}

variable "jumpbox_configuration_script_name" {
  description = "(Required) Specifies the name of the custom script."
  type        = string
  default     = "configure-jumpbox-vm.ps1"
}
