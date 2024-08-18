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
    ruby
    glib
    vips
  ];

  scripts.sync-vm.exec = ''
    vm_username=$(terraform output --raw "vm_username")
    vm_ip=$(terraform output --raw "vm_ip")
    rsync -avx --progress --exclude .devenv --exclude .terraform . $vm_username@$vm_ip:azure-blob/
  '';

  scripts.generate-env-file.exec = ''
    terraform output -raw devenv_local_nix > devenv.local.nix
  '';
}
