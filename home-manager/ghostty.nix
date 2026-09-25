{
  config,
  lib,
  pkgs,
  ...
}:

# Shared Ghostty configuration for every host — settings AND keybinds live
# here so the terminal behaves identically everywhere. Host files only decide
# where the app comes from: macOS (Homebrew install) and Omarchy (pacman
# install) both set `programs.ghostty.package = null` so HM only writes
# ~/.config/ghostty/config.
#
# macos-* keys are accepted on every platform and ignored off macOS, and the
# `cmd` key modifier is an alias for `super` on Linux, so nothing here needs
# to be platform-guarded.

let
  # The active Ghostty theme. Some settings below are theme-specific and only
  # applied when this matches (see selection colors).
  #ghosttyTheme = "Catppuccin Mocha";
  #ghosttyTheme = "Monokai Pro Light Sun";
  #ghosttyTheme = "Hacktober";
  # Other variants: "TokyoNight Storm", "TokyoNight Moon", "TokyoNight Night",
  # "TokyoNight Day" (light).
  #ghosttyTheme = "TokyoNight";
  # Alabaster (light) was too harsh for long reading; Everforest's cream text
  # on grey-green (~8.6:1 contrast) is easier on the eyes.
  #ghosttyTheme = "Alabaster";
  #ghosttyTheme = "Everforest Dark Med";
  #ghosttyTheme = "Doom One";
  # Trying Nord (#d8dee9 on #2e3440, ~9.2:1) against Everforest/Doom One.
  ghosttyTheme = "Nord";
in
{
  programs.ghostty = {
    enable = true;

    settings = {
      # Fonts (the font files themselves come from the nerd-fonts.* packages
      # in common.nix / fontconfig).
      # JetBrainsMono matches Omarchy's default terminal font. Was:
      # font-family = "MesloLGM Nerd Font";
      font-family = lib.mkDefault "JetBrainsMono Nerd Font";
      # Hosts may override (e.g. home-omarchy.nix, on a 32" 4K monitor).
      font-size = lib.mkDefault 14;
      font-thicken = false;
      # Extra line spacing for easier long-form reading.
      adjust-cell-height = "5%";
      minimum-contrast = 3;
      background-opacity = 1;

      # Theme — run `ghostty +list-themes` to browse built-ins.
      # Hosts may override (home-omarchy.nix follows Omarchy's theme instead).
      theme = lib.mkDefault ghosttyTheme;

      unfocused-split-opacity = 0.6;
      split-divider-color = "#216276";
      # Focus the split under the mouse pointer instead of needing
      # cmd+alt+arrow to move between splits.
      focus-follows-mouse = true;

      # macOS app icon (no-op elsewhere) — tweak without touching the .app
      # bundle. "custom" + macos-custom-icon (absolute path to an .icns) uses
      # a custom icon instead of a built-in one.
      macos-icon = "chalkboard";
      # macos-icon-frame = "aluminum";
      # macos-icon-ghost-color = "#ff5500";
      # macos-icon-screen-color = "#1a1a2e";

      # Keybinds (one string per binding).
      keybind = [ ];
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
