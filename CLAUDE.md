# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

A personal Nix flake managing user (Home Manager) configuration on macOS (aarch64-darwin) and Omarchy (Arch + Hyprland, x86_64-linux). There is no application code here; every change is configuration that gets evaluated by Nix and activated on a host.

**Current deployments (as of 2026-09): macOS and Omarchy — both standalone Home Manager.** There are no NixOS configurations (the NixOS, Pop!_OS and older MBP hosts were removed 2026-09; recover them from git history if needed). Test changes on the live hosts.

## Apply / rebuild commands

The repo lives at `~/dev/nix-config`. The `nh` helper is installed via Home Manager (see `home-manager/common.nix`) and is the preferred entrypoint:

```sh
# Home Manager (Omarchy auto-detects from $USER@$(hostname))
nh home switch --ask
# macOS: the flake's Mac config is nazishhussainmir@K-H-2005735-M, but the
# machine's hostname is "x", so nh can't auto-detect it — always pass -c.
nh home switch -c nazishhussainmir@K-H-2005735-M ~/dev/nix-config

# Update inputs (run from repo root)
nix flake update

# Garbage collection
nh clean user
```

When `nh` is unavailable (fresh install, before first switch), fall back to:

```sh
home-manager switch --flake ~/dev/nix-config/.#mir@mir-omarchy-pc
```

## CI

`.github/workflows/check.yml` runs on push to `main` and on PRs. It does `nix fmt -- --ci` (nixfmt, via the flake's `formatter` output), `nix flake show`, plus a pure `nix eval` of every home config's `activationPackage.drvPath` — nothing is built. `nix flake check` is *not* used: it ignores `homeConfigurations`. When adding a host, add it to the matrix.

Run the same evals locally before pushing (see README, "Continuous integration").

`.github/workflows/update-flake.yml` runs `nix flake update` every Monday (or on manual dispatch), evaluates every output the same way, and only if that passes opens a PR on branch `update-flake-lock` and merges it in the same job (`gh pr merge --merge --delete-branch`). The PR is authored by github-actions[bot], so a `check.yml` run on it would sit in "awaiting approval"; `check.yml` therefore has `paths-ignore: [flake.lock]` on `pull_request` and the in-job checks are the gate. The merge is pushed with `GITHUB_TOKEN`, so `check.yml` does *not* run again on main. Post-merge workflow on each host: `git pull` then `nh home switch --ask`; nothing else is automated. The host lists in that workflow mirror `check.yml`'s matrices; update both when adding a host. Needs the repo setting "Allow GitHub Actions to create and approve pull requests".

## Formatting / linting

The whole repo is `nixfmt`-formatted and CI fails on drift. Run `nix fmt` from the repo root before committing (there is no pre-commit hook). `nixfmt` is also installed via `home-manager/common.nix` for editor use.

## Architecture

### Flake outputs (`flake.nix`)

- `homeConfigurations."<user>@<host>"` — standalone Home Manager. Modules: `./home-manager/hosts/home-<host>.nix`. Two entries: `mir@mir-omarchy-pc` and `nazishhussainmir@K-H-2005735-M` (the Mac; `home-mac.nix`, username/home dir passed via `extraSpecialArgs`).

Each passes `inputs` via `extraSpecialArgs` so modules can reference flake inputs.

When adding a new host, both an entry in `flake.nix` *and* the corresponding host file under `home-manager/hosts/` are required.

### Home Manager layout (`home-manager/`)

Layered imports — each host file picks its layers:

- `common.nix` — the **universal super-import**, shared by *every* home config (macOS and Linux): packages, shell (fish; the zsh block is commented out, kept as an off switch), git, starship (single shared prompt config, see the Omarchy section), nh (with weekly `nh clean user` via `programs.nh.clean`), fonts, and on macOS a fish greeting that warns when the Mac drifts from `macos/Brewfile`. Anything meant for all machines lives here or is imported from here (e.g. `ghostty.nix`).
- `aliases.nix` — **all shell shortcuts.** `home.shellAliases` (plain aliases, HM fans them out to fish and to bash/zsh if ever enabled) + `programs.fish.shellAbbrs`, and a generated POSIX copy at `~/.config/hm/aliases.sh` for shells HM doesn't manage (Omarchy's bash). Edit shortcuts here, nowhere else.
- `hosts/home-<host>.nix` — **every** host file sets `home.username` and `home.homeDirectory` (the mac file gets them via `extraSpecialArgs` from `flake.nix`; `home.stateVersion` is shared in `common.nix`), picks which layers to import, adds host-specific packages and program configs (e.g. `home-mac.nix` imports only `common.nix` and adds btop and macOS Ghostty bits; `home-omarchy.nix` imports only `common.nix` and leaves alone what Omarchy owns).

When adding a new program: prefer `home-manager/common.nix` if it should run everywhere (guard platform-specific bits with `isDarwin`/`isLinux`), or the host file if it's truly per-machine. macOS-specific bits go in `home-manager/hosts/home-mac.nix`.

### Ghostty (`home-manager/ghostty.nix`)

Shared Ghostty config, imported by every host via `common.nix`: theme (a `ghosttyTheme` let-binding at the top, with theme-conditional selection-color fixes), font (`BlexMono Nerd Font`, i.e. IBM Plex Mono, from `nerd-fonts.blex-mono` in `common.nix`), split settings, macOS icon, and all keybinds. **Every** Ghostty setting belongs here so hosts stay identical. Changing `ghosttyTheme` re-themes every machine. Per-host differences stay in host files:

- **macOS**: the app comes from Homebrew (the nix ghostty package is Linux-only) → `package = null`. `macos-*` settings and keybinds also live in `ghostty.nix` (accepted everywhere, no-ops off macOS) — don't add Ghostty settings to host files.
- **Omarchy**: `package = null` **and** `systemd.enable = false` (the HM module's systemd unit requires a package); install the app from the distro (`sudo pacman -S ghostty` on Omarchy).

### Helper scripts (`bin/`)

- `macos-apps` — regenerates the inventory block of `macos/apps.md` from `/Applications` (Homebrew cask / App Store / work MDM / Apple / manual, with matching casks from Homebrew's index). Python, so it runs from fish; only the text between the GENERATED markers is rewritten, and the work-MDM list is read from the `managed:start/end` markers.
- `omarchy-sync <diff|pull|push|status>` — copies Omarchy's user config between `~/.config` and `omarchy/` (see the foreign-distro section).

## Foreign-distro host (Omarchy)

Home Manager runs standalone on top of a non-NixOS distro here. Rules that keep them conflict-free:

- **Omarchy is Arch + Hyprland and heavily bash-based.** Its theme/update system owns and rewrites its dotfiles: `~/.bashrc`, `~/.config/hypr/`, waybar, **alacritty** (Omarchy's default terminal), `~/.config/btop/`. Home Manager must **never** manage those files — HM's read-only store symlinks would break Omarchy's theme switching, and HM activation refuses to clobber them anyway. Hence btop is configured only in `home-mac.nix`, never in `common.nix`. `~/.config/starship.toml` is the exception and **is** HM-owned: the shared starship settings in `common.nix` mirror Omarchy's shipped `/usr/share/omarchy/config/starship.toml` and use named ANSI colours, and Omarchy themes only repaint the terminal palette (no theme touches `starship.toml`), so theming keeps working. `home-omarchy.nix`'s fish greeting warns when Omarchy's shipped file changes (sha256 pinned there) so `common.nix` can be re-synced. On a fresh Omarchy install move Omarchy's copy aside (`mv ~/.config/starship.toml ~/.config/starship.toml.omarchy`) before the first switch. Fish is safe to manage (Omarchy doesn't touch `~/.config/fish`); git config is HM-owned (Omarchy's original was moved to `~/.config/git/config.backup` by the first `-b backup` switch).
- **Don't switch Omarchy's login shell to fish** — Omarchy relies on bash. Fish is used as a working shell launched from bash instead.
- **GUI apps come from the distro, not nix.** Nix-built GUI apps on a foreign distro hit OpenGL/driver issues (they'd need nixGL). Pattern for HM modules that ship an app: `package = null` (+ `systemd.enable = false` if the module has a unit) so HM only writes config.
- **Shell bootstrap on Omarchy:** HM reaches bash via exactly one line at the *bottom* of `~/.bashrc`: `. "$HOME/.config/hm/bashrc.sh"`. That HM-generated file (from `aliases.nix`) sources `hm-session-vars.sh` (`NH_FLAKE`, `NIX_HOME`, PATH), then `~/.config/hm/aliases.sh`, then `~/.config/hm/atuin.sh` (written by `common.nix`; atuin's bash hooks — it deliberately does *not* source nixpkgs' bash-preexec 0.6.0, which drops the first command of every session when PROMPT_COMMAND is an array as on Arch; atuin's embedded hooks are used instead). The SSH host marker needs no bash hook: starship's left `format` in `common.nix` leads with `⇄ <hostname>` over SSH in bash and fish alike, coloured per host via `programs.starship.settings.hostname.style` in the host files. It runs after Omarchy's own `default/bash/rc`, so our aliases override Omarchy's on clashes (`c` = clear, not opencode) — intentional. Caveat: the Arch/Omarchy `.bashrc` returns early for non-interactive shells, so `ssh host 'cmd'` won't see these vars or aliases. A login shell (`ssh host 'bash -lc "…"'`) gets `nh` on PATH via `/etc/profile.d/nix.sh` but still no `NH_FLAKE` (`.bash_profile` only sources `.bashrc`, which returns first), so pass the flake explicitly: `nh home switch ~/dev/nix-config`. Interactive sessions have everything.
- **First activation on a fresh foreign-distro machine:** install Nix (Determinate installer), clone this repo to `~/dev/nix-config`, then `nix run home-manager/master -- switch -b backup --flake ~/dev/nix-config/.#mir@<host>`. From then on plain `nh home switch --ask` works.
- The Omarchy PC (`mir@mir-omarchy-pc`) accepts key-based SSH from the macOS machine for remote edits when asked.
- **Omarchy's text-size tool breaks the HM ghostty symlink.** `omarchy display text size N` (also run by the bar's monitor panel text-size slider) does `sed -i` on `~/.config/ghostty/config`, replacing HM's symlink with a plain file; the next `nh home switch` then fails with "would be clobbered". Fix: move the plain file aside (or switch with `-b backup`) and re-switch; HM's `ghostty.nix` font size wins again.
- **Omarchy's own config is tracked as plain copies, not managed by HM.** `omarchy/` mirrors the user-edited files under `~/.config` (`hypr/*.lua` except `monitors.lua`, `hypr/*.conf`, `omarchy/shell.json`, `omarchy/shell.toml`, `omarchy/plugins/mir.indicators/`). `bin/omarchy-sync` (on PATH via `home.sessionPath`) moves them: `diff` shows drift, `pull` copies live → repo (then commit), `push` copies repo → live with `*.orig` backups (then `hyprctl reload && omarchy restart shell`). Never symlink these: the shell writes `shell.json` atomically (tmp + rename) and Omarchy migrations `mv` over the Lua files, which would replace a symlink with a plain file. `monitors.lua` is excluded on purpose (per-machine outputs/scale). The Omarchy fish greeting warns when live and repo differ. To edit Omarchy config, edit the live file in `~/.config`, verify, then `omarchy-sync pull` — not the copy in `omarchy/`.

## Conventions worth knowing

- Hostnames in `flake.nix` (e.g. `mir-omarchy-pc`) must match the machine's `$USER@$(hostname)` (Home Manager auto-detect) or be passed explicitly to `nh`/`home-manager`. The current Mac's hostname is `x`, not `K-H-2005735-M`, so its config never auto-detects — use `nh home switch -c nazishhussainmir@K-H-2005735-M ~/dev/nix-config` there.
- `home.stateVersion` is pinned to `"23.05"` once, in `common.nix` — do not bump it casually; it encodes migration state, not "current version."
- `nixpkgs.config.allowUnfree` is set in `home-manager/common.nix`.
- Platform-specific env in `home-manager/common.nix` (Homebrew vars/paths for macOS) is guarded with `lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin` / `isLinux` — keep new platform-specific vars behind the same guards.
- Commented-out blocks are common throughout (alternative DEs, disabled services, zsh config preserved alongside the active fish config). Treat them as the user's "off switches" — don't delete them when making unrelated edits.
