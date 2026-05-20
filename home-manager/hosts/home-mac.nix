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

  # Ghostty is installed via Homebrew on macOS (the Nix package is Linux-only),
  # but its config is managed declaratively here. package = null means HM
  # writes ~/.config/ghostty/config without trying to install the app.
  programs.ghostty = {
    enable = true;
    package = null;

    settings = {
      # Fonts (the font files themselves come from the nerd-fonts.* packages
      # in common.nix / fontconfig).
      font-family = "MesloLGM Nerd Font";
      font-size = 12;
      font-thicken = true;

      # Theme — run `ghostty +list-themes` to browse built-ins.
      #theme = "Catppuccin Mocha";
      theme = "Ayu";

      # macOS app icon — tweak without touching the .app bundle.
      macos-icon = "official";
      # macos-icon-frame = "aluminum";
      # macos-icon-ghost-color = "#ff5500";
      # macos-icon-screen-color = "#1a1a2e";
    };
  };
}
