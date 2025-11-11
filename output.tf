output "devenv_local_nix" {
  sensitive = true
  value     = <<EOT
{pkgs, lib, ...}:{
  env = {
    AZURE_ACCOUNT_NAME = "${azurerm_storage_account.main.name}";
    AZURE_ACCESS_KEY = "${azurerm_storage_account.main.primary_access_key}";
    AZURE_PRIVATE_CONTAINER = "${azurerm_storage_container.private.name}";
    AZURE_PUBLIC_CONTAINER = "${azurerm_storage_container.public.name}";
    AZURE_PRINCIPAL_ID = "${azurerm_user_assigned_identity.vm.principal_id}";
  };
}
EOT
}

output "vm_ip" {
  value = var.create_vm ? azurerm_public_ip.main[0].ip_address : ""
}

output "vm_username" {
  value = var.vm_username
}

output "app_service_app_name" {
  value = var.create_app_service ? azurerm_linux_web_app.main[0].name : ""
}

output "resource_group" {
  value = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  value = var.create_aks ? azurerm_kubernetes_cluster.main[0].name : ""
}

output "aks_ssh_ip" {
  value = var.create_aks && length(kubernetes_service.ssh) > 0 && length(kubernetes_service.ssh[0].status) > 0 && length(kubernetes_service.ssh[0].status[0].load_balancer) > 0 && length(kubernetes_service.ssh[0].status[0].load_balancer[0].ingress) > 0 ? kubernetes_service.ssh[0].status[0].load_balancer[0].ingress[0].ip : ""
}

output "aks_ssh_username" {
  value = var.aks_ssh_username
}

output "aks_ssh_password" {
  value     = var.create_aks ? random_password.aks_ssh[0].result : ""
  sensitive = true
}
