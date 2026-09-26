{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  # Omarchy (Arch) host — Home Manager runs standalone here. GUI apps come
  # from pacman: nix-built GUI apps on a non-NixOS distro have OpenGL/driver
  # issues (would need nixGL).
  imports = [
    ../common.nix
  ];

  home.username = "mir";
  home.homeDirectory = "/home/mir";

  # btop is deliberately not configured here (it's in home-mac.nix only):
  # Omarchy's theme system owns ~/.config/btop, and an HM store symlink would
  # break its theme switching.

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
  # No font size here: 14 (the shared default) is too big on this machine's
  # 32" 4K monitor, and an empty `font-size =` resets to Ghostty's default
  # (12 on Linux). Was: programs.ghostty.settings.font-size = 12;
  # Don't use Omarchy's text-size slider: it `sed -i`s this file (as
  # px * 9/12 pt), replacing the HM symlink so the next switch fails.
  programs.ghostty.settings.font-size = "";
  # Follow Omarchy's theme (as its shipped ghostty config does) instead of
  # ghosttyTheme: Omarchy's theme switcher rewrites this file and reloads
  # Ghostty. An empty `theme =` resets it to Ghostty's default, so no
  # ghosttyTheme colours leak through (null would print `theme = null`).
  programs.ghostty.settings.theme = "";
  programs.ghostty.settings.config-file = ''?"~/.local/state/omarchy/current/theme/ghostty.conf"'';

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
