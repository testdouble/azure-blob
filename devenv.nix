{ pkgs, ... }:

{
  packages = with pkgs; [
    git
    libyaml
    terraform
    azure-cli
  ];


  scripts.generate-env-file.exec = ''
    terraform output -raw devenv_local_nix > devenv.local.nix
  '';

  languages.ruby.enable = true;
  languages.ruby.version = "3.1.5";
}
