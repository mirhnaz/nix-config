{ config, lib, pkgs, inputs, ... }:

{
  # Omarchy (Arch) host — Home Manager runs standalone here, like Pop!_OS.
  #
  # Deliberately NOT imported:
  #   ../common-linux.nix — pulls in alacritty/vscode/windsurf as nix packages.
  #     Omarchy already ships alacritty/chromium via pacman, and nix-built GUI
  #     apps on a non-NixOS distro have OpenGL/driver issues (would need nixGL).
  #   ../services.nix — dconf/GNOME + virt-manager settings; Omarchy is Hyprland.
  imports = [
    ../common.nix
  ];

  home.username = "mir";
  home.homeDirectory = "/home/mir";
  home.stateVersion = "23.05"; # Please read the comment before changing.

  # Omarchy's theme system owns ~/.config/btop — if HM also writes
  # btop.conf, activation refuses to clobber it and Omarchy theme
  # switching would break against a store symlink. Let Omarchy keep it.
  programs.btop.enable = lib.mkForce false;

  # Same story for ~/.config/starship.toml — Omarchy ships and themes it.
  # Empty settings means HM generates no starship.toml, so Omarchy's file
  # stays in place; starship itself remains enabled (fish integration works
  # and picks up Omarchy's config). Drop this override + move the file
  # aside if you'd rather use the HM starship settings from common.nix.
  programs.starship.settings = lib.mkForce { };

  home.packages = with pkgs; [
    # CLI-only tools are safe on a foreign distro
    nvd
    killall
    ethtool

    # lang utils
    nixd
    nil
  ];
}
