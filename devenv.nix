{ pkgs, config, ... }:

{
  env = {
    LD_LIBRARY_PATH = "${config.devenv.profile}/lib";
  };

  packages = with pkgs; [
    git
    libyaml
    terraform
    azure-cli
    glib
    vips
    sshuttle
    sshpass
    rsync
  ];

  languages.ruby.enable = true;
  languages.ruby.version = "3.1.6";

  scripts.sync-vm.exec = ''
    vm_username=$(terraform output --raw "vm_username")
    vm_ip=$(terraform output --raw "vm_ip")
    rsync -avx --progress --exclude .devenv --exclude .terraform . $vm_username@$vm_ip:azure-blob/
  '';

  scripts.generate-env-file.exec = ''
    terraform output -raw devenv_local_nix > devenv.local.nix
  '';

  scripts.proxy-vps.exec = ''
    exec sshuttle -e "ssh -o CheckHostIP=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" -r "$(terraform output --raw vm_username)@$(terraform output --raw vm_ip)" 0/0
  '';

  scripts.start-app-service-ssh.exec = ''
      resource_group=$(terraform output --raw "resource_group")
      app_name=$(terraform output --raw "app_service_app_name")
      exec az webapp create-remote-connection --resource-group $resource_group --name $app_name
  '';
}
