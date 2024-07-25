terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "azure-blob"
  location = var.location
  tags = {
    source = "Terraform"
  }
}

resource "azurerm_storage_account" "main" {
  name                     = "azureblobrubygemdev"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    source = "Terraform"
  }
}

resource "azurerm_storage_container" "private" {
  name                  = "private"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "public" {
  name                  = "public"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "blob"
}

output "devenv_local_nix" {
  sensitive = true
  value = <<EOT
{pkgs, lib, ...}:{
  env = {
    AZURE_ACCOUNT_NAME = "${azurerm_storage_account.main.name}";
    AZURE_ACCESS_KEY = "${azurerm_storage_account.main.primary_access_key}";
    AZURE_PRIVATE_CONTAINER = "${azurerm_storage_container.private.name}";
    AZURE_PUBLIC_CONTAINER = "${azurerm_storage_container.public.name}";
  };
}
EOT
}
