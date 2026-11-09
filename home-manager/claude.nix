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
# hand there. A nested .envrc under ~/personal must start with `source_up`,
# or it replaces ours (direnv only loads the nearest one).
#
# The account: the personal setup token (Keychain item cos.claude-agent-token,
# account "personal", on a Mac; ~/.mantle/server/claude/personal.token, mode
# 600, elsewhere) is exported as CLAUDE_CODE_OAUTH_TOKEN, the same store Mantle
# reads per project. Without it, cd ~/personal && claude, then /login with the
# personal account. /status shows which account a directory uses.

let
  home = config.home.homeDirectory;
  profileDir = "${home}/.claude-personal";

  # Relative to $HOME. "personal" is created if missing; the rest are only
  # touched where they exist (so a repo absent on one host isn't conjured).
  personalDirs = [
    "personal"
    "dev/thingsand-systems"
    "dev/safe-rm-rust"
    "dev/science-chatbot"
    "dev/omarchy-wallpapers"
    "dev/SimpleNoteTaker"
    "dev/timer-app"
    "dev/practo-rust"
    "dev/spacemacs-windsurf"
    "dev/tv-vibehack"
  ];

  marker = "Managed by Home Manager (home-manager/claude.nix)";
  # The personal account's long-lived token (`claude setup-token`), where Mantle keeps its tokens too: on a Mac the
  # login Keychain item first, else the file (mode 600). Read when you cd in, never written to the Nix store or git.
  # With no token yet, claude falls back to the profile's own /login.
  tokenFile = "${home}/.mantle/server/claude/personal.token";
  envrc = pkgs.writeText "claude-personal.envrc" ''
    # ${marker} — personal Claude account.
    export CLAUDE_CONFIG_DIR="${profileDir}"
    if [ "$(uname)" = Darwin ] && t=$(security find-generic-password -s cos.claude-agent-token -a personal -w 2>/dev/null); then
      export CLAUDE_CODE_OAUTH_TOKEN="$t"
    elif [ -r "${tokenFile}" ]; then
      export CLAUDE_CODE_OAUTH_TOKEN="$(cat "${tokenFile}")"
    fi
    unset t
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
    for d in ${lib.escapeShellArgs personalDirs}; do
      d="$HOME/$d"
      [ -d "$d" ] || continue
      if [ -e "$d/.envrc" ] && ! grep -qF ${lib.escapeShellArg marker} "$d/.envrc"; then
        warnEcho "claude.nix: $d/.envrc exists and isn't ours; add: export CLAUDE_CONFIG_DIR=\"${profileDir}\""
        continue
      fi
      if ! cmp -s ${envrc} "$d/.envrc"; then
        run install -m 644 ${envrc} "$d/.envrc"
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
