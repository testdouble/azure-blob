terraform {
  backend "azurerm" {
    resource_group_name  = "azure-blob"
    storage_account_name = "azureblobrubygemdev"
    container_name       = "terraform"
    key                  = "terraform.tfstate"
  }
}
