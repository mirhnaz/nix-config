{ config, pkgs, lib, username, homeDirectory, ... }:

let
  # The active Ghostty theme. Some settings below are theme-specific and only
  # applied when this matches (see selection colors).
  #ghosttyTheme = "Catppuccin Mocha";
  #ghosttyTheme = "Monokai Pro Light Sun";
  ghosttyTheme = "Hacktober";
in
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
      font-size = 13;
      font-thicken = true;

      # Theme — run `ghostty +list-themes` to browse built-ins.
      theme = ghosttyTheme;

      unfocused-split-opacity = 0.6;
      split-divider-color = "#216276";

      # macOS app icon — tweak without touching the .app bundle.
      # "custom" + macos-custom-icon uses our own .icns instead of a built-in.
      # Path must be absolute; point straight at the icon in this repo.
      macos-icon = "custom";
      macos-custom-icon = "${homeDirectory}/dev/nix-config/.config/ayu-dark.icns";
      # macos-icon-frame = "aluminum";
      # macos-icon-ghost-color = "#ff5500";
      # macos-icon-screen-color = "#1a1a2e";
    }
    # The Hacktober theme's selection background is ~the same as the window
    # background, making selected text invisible. Override with a visible
    # highlight, but only when that theme is active. (Alternatively:
    # selection-invert-fg-bg = true to just swap fg/bg regardless of theme.)
    // lib.optionalAttrs (ghosttyTheme == "Hacktober") {
      selection-background = "#f5c355";
      selection-foreground = "#1a1a1a";
      foreground = "#979797";
    };
  };
}
