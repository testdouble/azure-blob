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

locals {
  public_ssh_key = var.ssh_key != "" ? var.ssh_key : file("~/.ssh/id_rsa.pub")
}

resource "azurerm_resource_group" "main" {
  name     = var.prefix
  location = var.location
  tags = {
    source = "Terraform"
  }
}

resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
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

resource "azurerm_virtual_network" "main" {
  count               = var.create_vm ? 1 : 0
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    source = "Terraform"
  }
}

resource "azurerm_subnet" "main" {
  count                = var.create_vm ? 1 : 0
  name                 = "${var.prefix}-main"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "main" {
  count               = var.create_vm ? 1 : 0
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "${var.prefix}-ip-config"
    subnet_id                     = azurerm_subnet.main[0].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main[0].id
  }

  tags = {
    source = "Terraform"
  }
}

resource "azurerm_public_ip" "main" {
  count               = var.create_vm ? 1 : 0
  name                = "${var.prefix}-public-ip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"

  tags = {
    source = "Terraform"
  }
}

resource "azurerm_user_assigned_identity" "vm" {
  location            = azurerm_resource_group.main.location
  name                = "${var.prefix}-vm"
  resource_group_name = azurerm_resource_group.main.name
}


resource "azurerm_role_assignment" "vm" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.vm.principal_id
}

resource "azurerm_linux_virtual_machine" "main" {
  count                           = var.create_vm ? 1 : 0
  name                            = "${var.prefix}-vm"
  computer_name                   = var.prefix
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = var.vm_size
  admin_username                  = var.vm_username
  admin_password                  = var.vm_password
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.main[0].id]

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.vm.id]
  }

  admin_ssh_key {
    username   = var.vm_username
    public_key = local.public_ssh_key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  tags = {
    source = "Terraform"
  }
}

resource "azurerm_service_plan" "main" {
  count               = var.create_app_service ? 1 : 0
  name                = "${var.prefix}-appserviceplan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "main" {
  count               = var.create_app_service ? 1 : 0
  name                = "${var.prefix}-app"
  service_plan_id     = azurerm_service_plan.main[0].id
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.vm.id]
  }

  site_config {
    application_stack {
      node_version = "20-lts"
    }
  }
}

resource "azurerm_app_service_source_control" "main" {
  count                  = var.create_app_service ? 1 : 0
  app_id                 = azurerm_linux_web_app.main[0].id
  repo_url               = "https://github.com/Azure-Samples/nodejs-docs-hello-world"
  branch                 = "master"
  use_manual_integration = true
  use_mercurial          = false
}
