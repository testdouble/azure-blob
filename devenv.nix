{ pkgs, config, ... }:

{
  cachix.enable = false;

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
  languages.ruby.versionFile = ./.ruby-version;

  scripts.generate-env-file.exec = ''
    terraform output -raw devenv_local_nix > devenv.local.nix
  '';
}
