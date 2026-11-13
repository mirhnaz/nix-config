{
  config,
  lib,
  pkgs,
  ...
}:

# Second Claude Code account (personal Max) next to the default one (work).
#
# Claude Code keeps login, settings, history and sessions in
# $CLAUDE_CONFIG_DIR (default ~/.claude); on macOS each config dir gets its
# own Keychain entry. direnv sets CLAUDE_CONFIG_DIR to ~/.claude-personal
# inside the directories listed below and unsets it when you leave them, so
# everywhere else `claude` is the untouched work profile.
#
# This module never writes to ~/.claude. It only reads settings.json and
# keybindings.json from it once, to seed the personal profile.
#
# Add a personal repo: append it to `personalDirs` and switch. A repo's own
# .envrc is never overwritten (activation warns instead); add the export by
# hand there. A nested .envrc under ~/personal or ~/dev must start with `source_up`,
# or it replaces ours (direnv only loads the nearest one).
#
# Keep a folder inside a personal one on the work account: append it to
# `workDirs`. It gets an .envrc that sets nothing, which stops direnv from
# walking up to the personal one.
#
# The account: the personal setup token
# (~/.mantle/server/claude/personal.token, mode 600, on every host) is exported as CLAUDE_CODE_OAUTH_TOKEN, the same store Mantle
# reads per project. Without it, cd ~/personal && claude, then /login with the
# personal account. /status shows which account a directory uses.

let
  home = config.home.homeDirectory;
  profileDir = "${home}/.claude-personal";

  # Relative to $HOME. "personal" is created if missing; the rest are only
  # touched where they exist (so a repo absent on one host isn't conjured).
  personalDirs = [
    "personal"
    "dev" # everything under ~/dev; the entries below keep working standalone
    "dev/thingsand-systems"
    "dev/safe-rm-rust"
    "dev/science-chatbot"
    "dev/omarchy-wallpapers"
    "dev/SimpleNoteTaker"
    "dev/timer-app"
    "dev/practo-rust"
    "dev/spacemacs-windsurf"
    "dev/tv-vibehack"
    "dev/nix-config"
  ];

  # Relative to $HOME: folders inside a personal dir that stay on the work
  # account. Only touched where they exist.
  workDirs = [
    "dev/mantle"
  ];

  marker = "Managed by Home Manager (home-manager/claude.nix)";
  # The personal account's long-lived token (`claude setup-token`), in Mantle's token store: one file, mode 600, on
  # every host. Read when you cd in, never written to the Nix store or git. With no file yet, claude falls back to
  # the profile's own /login.
  tokenFile = "${home}/.mantle/server/claude/personal.token";
  envrc = pkgs.writeText "claude-personal.envrc" ''
    # ${marker} — personal Claude account.
    export CLAUDE_CONFIG_DIR="${profileDir}"
    if [ -r "${tokenFile}" ]; then
      export CLAUDE_CODE_OAUTH_TOKEN="$(cat "${tokenFile}")"
    fi
  '';
  workEnvrc = pkgs.writeText "claude-work.envrc" ''
    # ${marker} — work Claude account.
    # Deliberately no `source_up`: this file shadows the personal .envrc of a
    # parent folder, so `claude` here is the default ~/.claude profile.
    unset CLAUDE_CONFIG_DIR CLAUDE_CODE_OAUTH_TOKEN
  '';
  direnv = "${config.programs.direnv.package}/bin/direnv";
in
{
  programs.direnv = {
    enable = true; # fish hook comes from HM; Omarchy bash via hm/bashrc.sh
    nix-direnv.enable = true;
  };

  home.activation.claudePersonal = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${lib.escapeShellArg profileDir}
    run chmod 700 ${lib.escapeShellArg profileDir}
    for f in settings.json keybindings.json; do
      if [ ! -e ${lib.escapeShellArg profileDir}/"$f" ] && [ -f "$HOME/.claude/$f" ]; then
        run cp "$HOME/.claude/$f" ${lib.escapeShellArg profileDir}/"$f"
      fi
    done

    run mkdir -p "$HOME/personal"
    for entry in ${
      lib.escapeShellArgs (map (d: "${envrc}:${d}") personalDirs ++ map (d: "${workEnvrc}:${d}") workDirs)
    }; do
      src="''${entry%%:*}"
      d="$HOME/''${entry#*:}"
      [ -d "$d" ] || continue
      if [ -e "$d/.envrc" ] && ! grep -qF ${lib.escapeShellArg marker} "$d/.envrc"; then
        warnEcho "claude.nix: $d/.envrc exists and isn't ours; set the Claude account there by hand (personal: export CLAUDE_CONFIG_DIR=\"${profileDir}\")"
        continue
      fi
      if ! cmp -s "$src" "$d/.envrc"; then
        run install -m 644 "$src" "$d/.envrc"
      fi
      run ${direnv} allow "$d" # content-hash based; re-run after every change
      # Keep it out of git without a global ignore (some repos commit .envrc).
      if [ -d "$d/.git" ] && ! grep -qxF .envrc "$d/.git/info/exclude" 2>/dev/null; then
        run mkdir -p "$d/.git/info"
        run sh -c 'echo .envrc >> "$1/.git/info/exclude"' _ "$d"
      fi
    done
  '';
}
