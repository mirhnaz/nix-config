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

  # Ghostty is installed via Homebrew on macOS (the Nix package is Linux-only);
  # package = null means HM only writes ~/.config/ghostty/config. Shared
  # settings live in ../ghostty.nix — only macOS-specific bits belong here.
  programs.ghostty = {
    package = null;

    settings = {
      # macOS app icon — tweak without touching the .app bundle.
      # "custom" + macos-custom-icon (absolute path to an .icns) uses a
      # custom icon instead of a built-in one.
      macos-icon = "chalkboard";
      # macos-icon-frame = "aluminum";
      # macos-icon-ghost-color = "#ff5500";
      # macos-icon-screen-color = "#1a1a2e";

      # Cmd+Enter: Ghostty's default is toggle_fullscreen, so the key never
      # reaches the shell. Send ESC CR instead (the same bytes as Alt+Enter)
      # so TUI apps like Claude Code can bind it (see ~/.claude/keybindings.json,
      # where Enter = newline and alt+enter = submit).
      keybind = "cmd+enter=text:\\x1b\\r";
    };
  };
}
