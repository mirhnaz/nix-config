# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

A personal Nix flake managing system (NixOS) and user (Home Manager) configuration across several hosts and platforms — NixOS x86_64 desktops/laptops, macOS (aarch64-darwin), and Pop!_OS and Omarchy (Arch + Hyprland) as Home-Manager-only targets. There is no application code here; every change is configuration that gets evaluated by Nix and activated on a host.

**Current deployments (as of 2026-09): macOS, Omarchy, and Pop!_OS — all standalone Home Manager.** No machine currently runs NixOS; the `nixosConfigurations` are kept for future use and are only validated by CI evaluation, never activated. Test Home Manager changes on the live hosts; treat NixOS changes as eval-only.

## Apply / rebuild commands

The repo lives at `~/dev/nix-config`. The `nh` helper is installed via Home Manager (see `home-manager/common.nix`) and is the preferred entrypoint:

```sh
# NixOS system rebuild — uses current hostname to pick the flake output
nh os switch --ask                          # confirm before activating
nh os switch --ask ~/dev/nix-config/.#mir-nixos-thinkpad   # explicit flake ref

# Home Manager
nh home switch --ask
nh home switch -c mir@mir-m4pro-mbp ~/dev/nix-config

# Update inputs (run from repo root)
nix flake update

# Garbage collection
nh clean all     # both system and home profiles
nh clean user
```

When `nh` is unavailable (fresh install, before first switch), fall back to:

```sh
sudo nixos-rebuild switch --flake ~/dev/nix-config/.#mir-nixos-pc
home-manager switch --flake ~/dev/nix-config/.#mir@mir-nixos-pc
```

To inspect what a rebuild *would* change without activating:

```sh
sudo nixos-rebuild build --flake ~/dev/nix-config/.#mir-nixos-thinkpad
nvd diff /run/current-system/ ./result/
```

## CI

`.github/workflows/check.yml` runs on push to `main` and on PRs. It does `nix fmt -- --ci` (nixfmt, via the flake's `formatter` output), `nix flake show`, plus a pure `nix eval` of every output's derivation path (`config.system.build.toplevel.drvPath` for NixOS hosts, `activationPackage.drvPath` for home configs) — nothing is built. `nix flake check` is *not* used: it ignores `homeConfigurations` and fails on placeholder hardware configs. When adding a host, add it to the matrix. `mir-nixos-thinkpad` is commented out of the matrix until its real `hardware-configuration.nix` is committed.

Run the same evals locally before pushing (see README, "Continuous integration").

`.github/workflows/update-flake.yml` runs `nix flake update` every Monday (or on manual dispatch), evaluates every output the same way, and opens a PR on branch `update-flake-lock` only if that passes. Because the PR is created with `GITHUB_TOKEN`, `check.yml` does *not* run on it — the in-job checks are the gate; `check.yml` runs again on merge. The host lists in that workflow mirror `check.yml`'s matrices; update both when adding a host. Needs the repo setting "Allow GitHub Actions to create and approve pull requests".

## Formatting / linting

The whole repo is `nixfmt`-formatted and CI fails on drift. Run `nix fmt` from the repo root before committing (there is no pre-commit hook). This includes `hardware-configuration.nix` files — after regenerating one, run `nix fmt` before committing. `nixfmt` is also installed via `home-manager/common.nix` for editor use.

## Architecture

### Flake outputs (`flake.nix`)

Two output sets, keyed by host:

- `nixosConfigurations.<host>` — full NixOS systems (`mir-nixos-pc`, `mir-nixos-thinkpad`). Modules: `./nixos/hosts/<dir>/configuration-<dir>.nix`, where `<dir>` is the short machine name (`pc`, `thinkpad`), not the hostname.
- `homeConfigurations."mir@<host>"` — standalone Home Manager (used on macOS and Pop!_OS, and also on NixOS hosts since Home Manager is *not* imported as a NixOS module here). Modules: `./home-manager/hosts/home-<host>.nix`.

Both pass `inputs` via `specialArgs` / `extraSpecialArgs` so modules can reference flake inputs.

When adding a new host, both an entry in `flake.nix` *and* the corresponding host file under `nixos/hosts/` or `home-manager/hosts/` are required.

### NixOS layout (`nixos/`)

- `nixos/default.nix` — shared system config imported by every host (boot, networking, audio, users, nix settings, desktop env). This is the "common module" for NixOS.
- `nixos/hosts/<dir>/configuration-<dir>.nix` (e.g. `nixos/hosts/pc/configuration-pc.nix`) — host entrypoint. Imports `hardware-configuration.nix`, `../../default.nix`, and any per-host services from `nixos/services/`.
- `nixos/hosts/<dir>/hardware-configuration.nix` — generated on the target machine with `sudo nixos-generate-config --show-hardware-config > nixos/hosts/<dir>/hardware-configuration.nix` and **committed verbatim** (then `nix fmt`) (flakes only see tracked files; no `/etc/nixos` symlink needed). Never hand-edit; regenerate and re-commit when hardware changes. The thinkpad's file is currently a commented placeholder stub pending regeneration on that machine — the host evaluates structurally but can't be built until then.
- `nixos/services/*.nix` — opt-in service modules (currently `sunshine.nix`, a thin wrapper over the nixpkgs `services.sunshine` module) imported selectively by hosts.

### Home Manager layout (`home-manager/`)

Layered imports — each host file picks its layers:

- `common.nix` — the **universal super-import**, shared by *every* home config (macOS and Linux): packages, shell (fish; the zsh block is commented out, kept as an off switch), git, starship (single shared prompt config, see the Omarchy section), nh (with weekly `nh clean user` via `programs.nh.clean`), fonts, and on macOS a fish greeting that warns when the Mac drifts from `macos/Brewfile`. Anything meant for all machines lives here or is imported from here (e.g. `ghostty.nix`).
- `common-linux.nix` — the **Linux super-import**, a pure package layer (nvd, nixd, alacritty, vscode, windsurf). Imported by NixOS Linux hosts and Pop!_OS — but *not* by `home-omarchy.nix`, deliberately (see the foreign-distro section).
- `aliases.nix` — **all shell shortcuts.** `home.shellAliases` (plain aliases, HM fans them out to fish and to bash/zsh if ever enabled) + `programs.fish.shellAbbrs`, and a generated POSIX copy at `~/.config/hm/aliases.sh` for shells HM doesn't manage (Omarchy's bash). Edit shortcuts here, nowhere else.
- `services.nix` — dconf / user services. Linux-only.
- `hosts/home-<host>.nix` — **every** host file sets `home.username`, `home.homeDirectory`, `home.stateVersion` (the mac file gets them via `extraSpecialArgs` from `flake.nix`), picks which layers to import, adds host-specific packages and program configs (e.g. `home-nixos.nix` configures kitty; `home-mac.nix` imports only `common.nix` and adds macOS Ghostty bits; `home-omarchy.nix` imports only `common.nix` and disables what Omarchy owns).

When adding a new program: prefer `home-manager/common.nix` if it should run everywhere, `common-linux.nix` if it's Linux-specific, or the host file if it's truly per-machine. macOS-specific bits go in `home-manager/hosts/home-mac.nix`.

### Ghostty (`home-manager/ghostty.nix`)

Shared Ghostty config, imported by every host via `common.nix`: theme (a `ghosttyTheme` let-binding at the top, with theme-conditional selection-color fixes), MesloLGM Nerd Font, split settings, macOS icon, and all keybinds. **Every** Ghostty setting belongs here so hosts stay identical. Changing `ghosttyTheme` re-themes every machine. Per-host differences stay in host files:

- **macOS**: the app comes from Homebrew (the nix ghostty package is Linux-only) → `package = null`. `macos-*` settings and keybinds also live in `ghostty.nix` (accepted everywhere, no-ops off macOS) — don't add Ghostty settings to host files.
- **NixOS hosts**: the module's default `pkgs.ghostty` gets installed.
- **Omarchy / Pop!_OS**: `package = null` **and** `systemd.enable = false` (the HM module's systemd unit requires a package); install the app from the distro (`sudo pacman -S ghostty` on Omarchy).

### Helper scripts (`bin/`)

- `rename-and-link.sh <source> <target>` — backs up `source` to `source.orig` and replaces it with a symlink pointing at `target`. Used to bring system-generated files (e.g. `/etc/nixos/configuration.nix`, `~/.config/home-manager/home.nix`) under repo control. See README for the exact incantations used during initial setup.
- `nvidia-offload` — PRIME render-offload wrapper for hybrid-graphics laptops; not wired into any config today (the thinkpad's `nvidia.nix` import is commented out).

## Foreign-distro hosts (Omarchy, Pop!_OS)

Home Manager runs standalone on top of a non-NixOS distro on these hosts. Rules that keep them conflict-free:

- **Omarchy is Arch + Hyprland and heavily bash-based.** Its theme/update system owns and rewrites its dotfiles: `~/.bashrc`, `~/.config/hypr/`, waybar, **alacritty** (Omarchy's default terminal), `~/.config/btop/`. Home Manager must **never** manage those files — HM's read-only store symlinks would break Omarchy's theme switching, and HM activation refuses to clobber them anyway. Hence in `home-omarchy.nix`: `programs.btop.enable = lib.mkForce false`. `~/.config/starship.toml` is the exception and **is** HM-owned: the shared starship settings in `common.nix` mirror Omarchy's shipped `/usr/share/omarchy/config/starship.toml` and use named ANSI colours, and Omarchy themes only repaint the terminal palette (no theme touches `starship.toml`), so theming keeps working. `home-omarchy.nix`'s fish greeting warns when Omarchy's shipped file changes (sha256 pinned there) so `common.nix` can be re-synced. On a fresh Omarchy install move Omarchy's copy aside (`mv ~/.config/starship.toml ~/.config/starship.toml.omarchy`) before the first switch. Fish is safe to manage (Omarchy doesn't touch `~/.config/fish`); git config is HM-owned (Omarchy's original was moved to `~/.config/git/config.backup` by the first `-b backup` switch).
- **Don't switch Omarchy's login shell to fish** — Omarchy relies on bash. Fish is used as a working shell launched from bash instead.
- **GUI apps come from the distro, not nix.** Nix-built GUI apps on a foreign distro hit OpenGL/driver issues (they'd need nixGL). Pattern for HM modules that ship an app: `package = null` (+ `systemd.enable = false` if the module has a unit) so HM only writes config. Same reason `home-omarchy.nix` skips `common-linux.nix` (it pulls alacritty/vscode/windsurf as nix packages).
- **Shell bootstrap on Omarchy:** HM reaches bash via exactly one line at the *bottom* of `~/.bashrc`: `. "$HOME/.config/hm/bashrc.sh"`. That HM-generated file (from `aliases.nix`) sources `hm-session-vars.sh` (`NH_FLAKE`, `NIX_HOME`, PATH), then `~/.config/hm/aliases.sh`, then `~/.config/hm/ssh-prompt.sh` if present (written by `home-omarchy.nix`: a right-aligned `user@host` above the bash prompt when `SSH_CONNECTION` is set, since bash has no right prompt; fish gets it from starship's `right_format` in `common.nix` like every other host). It runs after Omarchy's own `default/bash/rc`, so our aliases override Omarchy's on clashes (`c` = clear, not opencode) — intentional. Caveat: the Arch/Omarchy `.bashrc` returns early for non-interactive shells, so `ssh host 'cmd'` won't see these vars or aliases. A login shell (`ssh host 'bash -lc "…"'`) gets `nh` on PATH via `/etc/profile.d/nix.sh` but still no `NH_FLAKE` (`.bash_profile` only sources `.bashrc`, which returns first), so pass the flake explicitly: `nh home switch ~/dev/nix-config`. Interactive sessions have everything.
- **First activation on a fresh foreign-distro machine:** install Nix (Determinate installer), clone this repo to `~/dev/nix-config`, then `nix run home-manager/master -- switch -b backup --flake ~/dev/nix-config/.#mir@<host>`. From then on plain `nh home switch --ask` works.
- The Omarchy PC (`mir@mir-omarchy-pc`) accepts key-based SSH from the macOS machine for remote edits when asked.

## Conventions worth knowing

- Hostnames in `flake.nix` (e.g. `mir-nixos-pc`, `mir-m4pro-mbp`) must match the machine's `networking.hostName` (NixOS) or be passed explicitly to `nh`/`home-manager`.
- `home.stateVersion` and `system.stateVersion` are pinned to `"23.05"` — do not bump them casually; they encode migration state, not "current version."
- `nixpkgs.config.allowUnfree` is set both system-wide (NixOS `default.nix`) and per-user (`home-manager/common.nix`) — unfree packages work in either context.
- Platform-specific env in `home-manager/common.nix` (Homebrew vars/paths for macOS, `MOZ_USE_XINPUT2` for Linux) is guarded with `lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin` / `isLinux` — keep new platform-specific vars behind the same guards.
- Commented-out blocks are common throughout (alternative DEs, disabled services, zsh config preserved alongside the active fish config). Treat them as the user's "off switches" — don't delete them when making unrelated edits.
