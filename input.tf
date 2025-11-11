variable "location" {
  type    = string
  default = "westus2"
}

variable "prefix" {
  type    = string
  default = "azure-blob"
}

variable "storage_account_name" {
  type    = string
  default = "azureblobrubygemdev"
}

variable "create_vm" {
  type    = bool
  default = false
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "vm_username" {
  type    = string
  default = "azureblob"
}

variable "vm_password" {
  type    = string
  default = "qwe123QWE!@#"
}

variable "create_app_service" {
  type    = bool
  default = false
}

variable "create_aks" {
  type    = bool
  default = false
}

variable "aks_node_count" {
  type    = number
  default = 1
}

variable "aks_ssh_username" {
  type    = string
  default = "testuser"
}

variable "ssh_key" {
  type    = string
  default = ""
}
