terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

data "azurerm_kubernetes_cluster" "main" {
  count               = var.create_aks ? 0 : 1
  name                = "${var.prefix}-aks"
  resource_group_name = var.prefix
}

provider "azurerm" {
  features {}
}

provider "kubernetes" {
  host                   = var.create_aks ? azurerm_kubernetes_cluster.main[0].kube_config[0].host : (length(data.azurerm_kubernetes_cluster.main) > 0 ? data.azurerm_kubernetes_cluster.main[0].kube_config[0].host : "")
  client_certificate     = var.create_aks ? base64decode(azurerm_kubernetes_cluster.main[0].kube_config[0].client_certificate) : (length(data.azurerm_kubernetes_cluster.main) > 0 ? base64decode(data.azurerm_kubernetes_cluster.main[0].kube_config[0].client_certificate) : "")
  client_key             = var.create_aks ? base64decode(azurerm_kubernetes_cluster.main[0].kube_config[0].client_key) : (length(data.azurerm_kubernetes_cluster.main) > 0 ? base64decode(data.azurerm_kubernetes_cluster.main[0].kube_config[0].client_key) : "")
  cluster_ca_certificate = var.create_aks ? base64decode(azurerm_kubernetes_cluster.main[0].kube_config[0].cluster_ca_certificate) : (length(data.azurerm_kubernetes_cluster.main) > 0 ? base64decode(data.azurerm_kubernetes_cluster.main[0].kube_config[0].cluster_ca_certificate) : "")
}

locals {
  public_ssh_key = var.create_vm && var.ssh_key == "" ?  file("~/.ssh/id_rsa.pub") : var.ssh_key
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

resource "azurerm_storage_container" "azureblobrubygemdev_private" {
  name                  = "azureblobrubygemdev-private"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "azureblobrubygemdev_public" {
  name                  = "azureblobrubygemdev-public"
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

# AKS Resources
resource "azurerm_kubernetes_cluster" "main" {
  count               = var.create_aks ? 1 : 0
  name                = "${var.prefix}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.prefix}-aks"

  default_node_pool {
    name       = "default"
    node_count = var.aks_node_count
    vm_size    = var.vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = {
    source = "Terraform"
  }

  lifecycle {
    ignore_changes = [
      default_node_pool[0].upgrade_settings
    ]
  }
}

resource "azurerm_role_assignment" "aks_kubelet" {
  count                = var.create_aks ? 1 : 0
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_kubernetes_cluster.main[0].kubelet_identity[0].object_id
}

resource "azurerm_federated_identity_credential" "aks" {
  count               = var.create_aks ? 1 : 0
  name                = "${var.prefix}-aks-federated-identity"
  resource_group_name = azurerm_resource_group.main.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main[0].oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.vm.id
  subject             = "system:serviceaccount:default:azure-blob-test"
}

# Kubernetes Resources for SSH Pod
resource "kubernetes_service_account" "azure_blob_test" {
  count = var.create_aks ? 1 : 0
  metadata {
    name      = "azure-blob-test"
    namespace = "default"
    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.vm.client_id
    }
    labels = {
      "azure.workload.identity/use" = "true"
    }
  }
}

resource "kubernetes_deployment" "ssh" {
  count = var.create_aks ? 1 : 0
  metadata {
    name      = "azure-blob-test"
    namespace = "default"
    labels = {
      app = "azure-blob-test"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "azure-blob-test"
      }
    }

    template {
      metadata {
        labels = {
          app                               = "azure-blob-test"
          "azure.workload.identity/use"     = "true"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.azure_blob_test[0].metadata[0].name

        container {
          name  = "openssh-server"
          image = "lscr.io/linuxserver/openssh-server:latest"

          port {
            container_port = 2222
            protocol       = "TCP"
          }

          env {
            name  = "PUID"
            value = "1000"
          }

          env {
            name  = "PGID"
            value = "1000"
          }

          env {
            name  = "TZ"
            value = "Etc/UTC"
          }

          env {
            name  = "USER_NAME"
            value = var.aks_ssh_username
          }

          env {
            name  = "PUBLIC_KEY"
            value = local.public_ssh_key
          }

          env {
            name  = "SUDO_ACCESS"
            value = "true"
          }

          volume_mount {
            name       = "install-python-script"
            mount_path = "/custom-cont-init.d"
          }
        }

        volume {
          name = "install-python-script"
          config_map {
            name         = kubernetes_config_map.install_python[0].metadata[0].name
            default_mode = "0755"
          }
        }
      }
    }
  }
}

resource "kubernetes_config_map" "install_python" {
  count = var.create_aks ? 1 : 0
  metadata {
    name      = "install-python"
    namespace = "default"
  }

  data = {
    "install-python.sh" = <<-EOF
      #!/bin/sh
      apk add --no-cache python3
    EOF
  }
}

resource "kubernetes_service" "ssh" {
  count = var.create_aks ? 1 : 0
  metadata {
    name      = "azure-blob-test-ssh"
    namespace = "default"
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = "azure-blob-test"
    }

    port {
      port        = 22
      target_port = 2222
      protocol    = "TCP"
    }
  }
}
