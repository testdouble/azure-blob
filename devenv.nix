{ pkgs, ... }:

{
  packages = with pkgs; [
    git
    libyaml
    terraform
    azure-cli
  ];


  languages.ruby.enable = true;
  languages.ruby.version = "3.1.5";
}
