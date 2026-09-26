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

  # Mac only: on Omarchy, Omarchy's theme system owns ~/.config/btop.
  programs.btop = {
    enable = true;
    settings = {
      shown_boxes = "cpu gpu0 proc";
    };
  };

  # Ghostty is installed via Homebrew on macOS (the Nix package is Linux-only);
  # package = null means HM only writes ~/.config/ghostty/config. All settings
  # and keybinds live in ../ghostty.nix so every host gets the same config.
  programs.ghostty.package = null;
}
