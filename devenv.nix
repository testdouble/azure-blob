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
    azurite
  ];

  languages.ruby.enable = true;
  languages.ruby.version = "3.1.6";

  scripts.generate-env-file.exec = ''
    terraform output -raw devenv_local_nix > devenv.local.nix
  '';
}
