{ config, lib, pkgs, ... }:

# Shared Ghostty configuration for every host. The app itself differs per
# platform: NixOS hosts get pkgs.ghostty installed via this module's default
# package; macOS (Homebrew install) and foreign-distro Linux (pacman/apt
# install) set `programs.ghostty.package = null` in their host file so HM
# only writes ~/.config/ghostty/config.

let
  # The active Ghostty theme. Some settings below are theme-specific and only
  # applied when this matches (see selection colors).
  #ghosttyTheme = "Catppuccin Mocha";
  #ghosttyTheme = "Monokai Pro Light Sun";
  ghosttyTheme = "Hacktober";
in
{
  programs.ghostty = {
    enable = true;

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
