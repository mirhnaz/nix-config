{
  config,
  pkgs,
  lib,
  username,
  homeDirectory,
  ...
}:

{

  imports = [
    ../common.nix
  ];

  home.username = username;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "23.05"; # Please read the comment before changing.

  home.packages = with pkgs; [

  ];

  # Ghostty is installed via Homebrew on macOS (the Nix package is Linux-only);
  # package = null means HM only writes ~/.config/ghostty/config. All settings
  # and keybinds live in ../ghostty.nix so every host gets the same config.
  programs.ghostty.package = null;
}
