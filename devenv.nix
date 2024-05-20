{ pkgs, ... }:

{
  packages = with pkgs; [
    git
  ];


  languages.ruby.enable = true;
  languages.ruby.version = "3.1.5";
}
