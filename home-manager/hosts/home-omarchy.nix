{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

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

  # starship.toml IS Home-Manager-owned here, unlike btop: common.nix mirrors
  # Omarchy's shipped starship.toml and uses named colours, so Omarchy themes
  # (which repaint the terminal palette and never edit starship.toml) still
  # apply. First switch on a machine that has Omarchy's copy in place:
  #   mv ~/.config/starship.toml ~/.config/starship.toml.omarchy
  # Note `omarchy-refresh-config starship.toml` would overwrite the HM symlink
  # with a plain file; the next `nh home switch` then needs `-b backup`.
  #
  # Keep common.nix in step with upstream: the fish greeting flags when the
  # shipped file changes from the version common.nix was copied from.
  #
  # It also flags when the live Omarchy config (~/.config/hypr, ~/.config/omarchy)
  # has drifted from the copies tracked in $NIX_HOME/omarchy — see
  # bin/omarchy-sync (on PATH via home.sessionPath in common.nix). Those files
  # are plain copies, never HM-managed: Omarchy rewrites them in place.
  programs.fish.functions.fish_greeting = ''
    set -l shipped /usr/share/omarchy/config/starship.toml
    if test -r $shipped
      and test (sha256sum $shipped | string split ' ')[1] != b17c9b5f096fc125e97050e359171c6011d6b3c7d7e9ac28f630e75b4d4bb9db
      set_color yellow
      echo "Omarchy updated $shipped — re-sync programs.starship.settings in common.nix (then bump the hash in home-omarchy.nix)"
      set_color normal
    end
    if type -q omarchy-sync; and not omarchy-sync status
      set_color yellow
      echo "Omarchy config differs from $NIX_HOME/omarchy — run `omarchy-sync diff`, then `omarchy-sync pull` and commit (or `omarchy-sync push` to apply the repo's copy)"
      set_color normal
    end
  '';

  # Hostname colour in the SSH prompt marker (see common.nix).
  programs.starship.settings.hostname.style = "purple bold";

  # Ghostty config comes from ../ghostty.nix, but as with alacritty the
  # nix-built GUI app would need nixGL here — `sudo pacman -S ghostty`
  # instead; HM only writes ~/.config/ghostty/config.
  programs.ghostty.package = null;
  programs.ghostty.systemd.enable = false;
  # 14 (the shared default) is too big on this machine's 32" 4K monitor.
  programs.ghostty.settings.font-size = 12;

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
