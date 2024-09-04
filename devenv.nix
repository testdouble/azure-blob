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
  ];

  languages.ruby.enable = true;
  languages.ruby.version = "3.2.1";

  scripts.sync-vm.exec = ''
    vm_username=$(terraform output --raw "vm_username")
    vm_ip=$(terraform output --raw "vm_ip")
    rsync -avx --progress --exclude .devenv --exclude .terraform . $vm_username@$vm_ip:azure-blob/
  '';

  scripts.generate-env-file.exec = ''
    terraform output -raw devenv_local_nix > devenv.local.nix
  '';

  scripts.proxy-vps.exec = ''
    sshuttle -r "$(terraform output --raw vm_username)@$(terraform output --raw vm_ip)" 0/0
  '';
}
