{ config, pkgs, lib, username, homeDirectory, ... }:

{

  imports = [
    ../common.nix
    ../ghostty.nix
  ];

  home.username = username;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "23.05"; # Please read the comment before changing.

  home.packages = with pkgs; [

  ];

  # Ghostty is installed via Homebrew on macOS (the Nix package is Linux-only);
  # package = null means HM only writes ~/.config/ghostty/config. Shared
  # settings live in ../ghostty.nix — only macOS-specific bits belong here.
  programs.ghostty = {
    package = null;

    settings = {
      # macOS app icon — tweak without touching the .app bundle.
      # "custom" + macos-custom-icon uses our own .icns instead of a built-in.
      # Path must be absolute; point straight at the icon in this repo.
      macos-icon = "chalkboard";
      #macos-custom-icon = "${homeDirectory}/dev/nix-config/.config/ayu-dark.icns";
      # macos-icon-frame = "aluminum";
      # macos-icon-ghost-color = "#ff5500";
      # macos-icon-screen-color = "#1a1a2e";
    };
  };
}
