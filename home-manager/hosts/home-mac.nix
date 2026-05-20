{ config, pkgs, lib, username, homeDirectory, ... }:

{

  imports = [
    ../common.nix
  ];

  home.username = username;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "23.05"; # Please read the comment before changing.

  home.packages = with pkgs; [

  ];
}
