{
  config,
  lib,
  pkgs,
  ...
}:

# Kitty mirrors Ghostty: font, size and colours are read from
# programs.ghostty.settings (ghostty.nix + host overrides), so changing
# `ghosttyTheme` or the Ghostty font re-themes kitty too. Don't set them here.
#
# The colours come from Ghostty's own theme file, converted to kitty syntax at
# build time. kitty-themes has a "Doom_One" too, but its palette differs from
# Ghostty's (blue/cyan/black/white are all different), so it wouldn't match.
#
# macOS only, app included. On Omarchy, Omarchy owns ~/.config/kitty/kitty.conf
# (its font, text-size and glass tools `sed -i` it, and it includes the current
# Omarchy theme, as Ghostty does there), so it is tracked by bin/omarchy-sync
# instead.

let
  # Repeatable Ghostty keys (font-family, ...) come through as lists; the
  # last value is the one that applies.
  ghostty = lib.mapAttrs (
    _: v: if builtins.isList v then lib.last v else v
  ) config.programs.ghostty.settings;

  # Ghostty's built-in themes, as bundled with the Ghostty release nixpkgs
  # builds (URL from pkgs/by-name/gh/ghostty/deps.nix, "iterm2_themes"; the
  # hash differs, nixpkgs hashes it unpacked). Bump together
  # with Ghostty if a theme you pick is missing.
  ghosttyThemes = pkgs.fetchurl {
    url = "https://deps.files.ghostty.org/ghostty-themes-release-20261019-151001-86a776d.tgz";
    hash = "sha256-qyUT4xY3LEXJ+G4+URrr2/psOfoDwhAJaxkVL+KIUFs=";
  };

  # Ghostty key -> kitty key, for colours.
  colorKeys = {
    background = "background";
    foreground = "foreground";
    cursor-color = "cursor";
    cursor-text = "cursor_text_color";
    selection-background = "selection_background";
    selection-foreground = "selection_foreground";
  };

  # `palette = N=#rrggbb` -> `colorN #rrggbb`; the keys above are renamed.
  # Other Ghostty keys (none in practice) are dropped.
  kittyTheme =
    pkgs.runCommand "kitty-ghostty-theme.conf"
      {
        theme = ghostty.theme;
        nativeBuildInputs = [ pkgs.gawk ];
      }
      ''
        tar xzf ${ghosttyThemes} --strip-components=1 "ghostty/$theme"
        awk -F' *= *' '
          BEGIN { ${lib.concatStrings (lib.mapAttrsToList (g: k: ''map["${g}"] = "${k}"; '') colorKeys)} }
          # "palette = 0=#000000" splits into: palette, 0, #000000
          $1 == "palette" { print "color" $2, $3; next }
          $1 in map { print map[$1], $2 }
        ' "$theme" > $out
      '';

  # Colour overrides set in ghostty.nix (e.g. the Hacktober selection fix).
  colorOverrides = lib.mapAttrs' (g: k: lib.nameValuePair k ghostty.${g}) (
    lib.filterAttrs (g: _: ghostty ? ${g}) colorKeys
  );
in
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  programs.kitty = {
    enable = true;
    # The app comes from nixpkgs (the default package): the `kitty` CLI goes on
    # PATH and kitty.app is copied to ~/Applications/Home Manager Apps by
    # targets.darwin.copyApps (home-mac.nix). Updates arrive with
    # `nix flake update`; kitty's own update notice can be ignored.

    font = {
      name = ghostty.font-family;
      size = ghostty.font-size;
    };

    # Loaded before `settings`, so the overrides below win.
    extraConfig = lib.mkOrder 520 "include ${kittyTheme}";

    settings = {
      # Ghostty's minimum-contrast (a WCAG contrast ratio).
      text_fg_override_threshold = "${toString ghostty.minimum-contrast} ratio";
    }
    // colorOverrides;
  };
}
