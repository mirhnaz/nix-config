# nix-config

A personal [Nix](https://nixos.org/) flake managing user (Home Manager)
configuration on macOS (`aarch64-darwin`) and Omarchy (Arch + Hyprland).

There is no application code here — every change is configuration that gets
evaluated by Nix and activated on a host.

## Contents

- [Overview](#overview)
- [Initial setup](#initial-setup)
- [Installing Nix](#installing-nix)
- [Home Manager (standalone)](#home-manager-standalone)
- [macOS setup](#macos-setup)
- [Omarchy setup](#omarchy-setup)
- [Everyday commands](#everyday-commands)
- [Services](#services)
- [Application configuration](#application-configuration)
- [License](#license)

## Overview

Each host is a standalone Home Manager configuration in `flake.nix`,
`homeConfigurations."<user>@<host>"`, built from
`home-manager/hosts/home-<host>.nix`.

The repo is expected to live at `~/dev/nix-config`.

## Initial setup

These steps are common to every platform.

### Generate SSH keys

Generate a key on the new system so it can clone this repo from GitHub, then add
the public key to your GitHub account.

```sh
ssh-keygen -t ed25519 -C "abcdef@gmail.com"
cat ~/.ssh/id_ed25519.pub
```

### Clone the repository

`git` may not be available yet, so pull it into a temporary `nix shell` for the
session instead of installing it.

```sh
nix shell --extra-experimental-features nix-command --extra-experimental-features flakes nixpkgs#git
mkdir -p ~/dev && git clone git@github.com:mirhnaz/nix-config.git ~/dev/nix-config
```

## Installing Nix

Install Nix first:

```sh
# Installs upstream Nix (not the Determinate distribution) via the
# Determinate Systems installer.
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

## Home Manager (standalone)

Used on every host (macOS, Omarchy). Home Manager builds straight from the
flake, so there's nothing to link into `~/.config/home-manager`. The first
switch runs Home Manager from its flake, since it isn't installed yet;
`-b backup` moves any existing dotfile it would overwrite to `*.backup`:

```sh
nix run home-manager/master -- switch -b backup --flake ~/dev/nix-config/.#<user>@<host>
```

After that, `nh home switch --ask` (see [Everyday commands](#everyday-commands))
does the same.

## macOS setup

macOS (`aarch64-darwin`) follows the shared flow —
[Initial setup](#initial-setup), [Installing Nix](#installing-nix), and
[Home Manager (standalone)](#home-manager-standalone) — with the macOS-specific
notes below.

1. **git** comes from the Xcode Command Line Tools

   ```sh
   xcode-select --install
   ```

2. **Home Manager** uses the Mac's flake target when you reach the
   [Home Manager](#home-manager-standalone) step:

   ```sh
   nix run home-manager/master -- switch -b backup --flake ~/dev/nix-config/.#nazishhussainmir@kfin-mbp-mac
   ```

3. **Set fish as the login shell** — see
   [Fish shell](#fish-shell) under Application configuration.

4. **Ghostty** — the nixpkgs `ghostty` package is Linux-only, so the app itself
   is installed via Homebrew (declared in `macos/Brewfile`, see below), while its
   configuration is managed declaratively by Home Manager in
   `home-manager/hosts/home-mac.nix`.

5. **Non-Nix channels** — on macOS this repo runs *standalone* Home Manager (no
   nix-darwin), so the flake only manages Nix packages. Homebrew, global `uv`
   tools, and hand-downloaded apps are tracked separately under `macos/`. After
   the Home Manager switch, run:

   ```sh
   # Homebrew formulae + casks (and uv tools) — adopts already-installed apps
   brew bundle install --file=~/dev/nix-config/macos/Brewfile

   # Global uv tools, if you skipped brew or want them brew-independent
   # (grep + xargs, so it works from fish as well as bash)
   grep -v -e '^#' -e '^$' ~/dev/nix-config/macos/uv-tools.txt | xargs -n1 uv tool install

   # Hand-downloaded / App Store apps — open the checklist and reinstall each
   open ~/dev/nix-config/macos/apps.md
   ```

   After installing or removing apps, run `macos-apps` (`bin/macos-apps`, on
   `PATH` via Home Manager) to regenerate the inventory in `macos/apps.md`: it
   sorts every app in `/Applications` into Homebrew, App Store, work-managed,
   Apple or manual, and names the Homebrew cask for manual installs that have
   one.

   See [`macos/README.md`](macos/README.md) for the full bootstrap order, how to
   re-snapshot state after installing new things, and when adopting nix-darwin
   becomes worthwhile.

## Omarchy setup

[Omarchy](https://omarchy.org/) (Arch + Hyprland) runs standalone Home Manager
on top of the distro, but Omarchy owns and rewrites most of its dotfiles
(`~/.bashrc`, `~/.config/hypr/`, waybar, alacritty, btop), so setup differs
from the generic [Home Manager](#home-manager-standalone) flow: Home Manager
only manages fish, git, starship, Ghostty's config and CLI packages, and
Omarchy's own customisations are copied in with `omarchy-sync`.

1. **Install Omarchy** and set the hostname to match the flake output (or add a
   new `mir@<host>` entry to `flake.nix` and a `home-manager/hosts/` file):

   ```sh
   sudo hostnamectl set-hostname mir-omarchy-pc
   ```

2. **SSH key and clone** — `git` ships with Omarchy, so no `nix shell` is
   needed. Generate a key and add it to GitHub as in
   [Generate SSH keys](#generate-ssh-keys), then:

   ```sh
   mkdir -p ~/dev && git clone git@github.com:mirhnaz/nix-config.git ~/dev/nix-config
   ```

3. **Install Nix** with the Determinate Systems installer (see
   [Installing Nix](#installing-nix)), then open a new terminal so
   `/etc/profile.d/nix.sh` puts `nix` on `PATH`.

4. **Move Omarchy's starship config aside.** Home Manager owns
   `~/.config/starship.toml` (the shared config in `common.nix` mirrors
   Omarchy's and uses named colours, so Omarchy themes still apply):

   ```sh
   mv ~/.config/starship.toml ~/.config/starship.toml.omarchy
   ```

5. **First Home Manager switch.** `-b backup` moves any file Home Manager
   would overwrite (e.g. Omarchy's `~/.config/git/config`) to `*.backup`:

   ```sh
   nix run home-manager/master -- switch -b backup --flake ~/dev/nix-config/.#mir@mir-omarchy-pc
   ```

   From then on, `nh home switch --ask` works.

6. **Hook Home Manager into bash.** Omarchy's login shell stays bash (Omarchy
   relies on it; don't `chsh` to fish, launch `fish` from bash instead). Add
   this line near the bottom of `~/.bashrc`, after Omarchy's own lines:

   ```sh
   . "$HOME/.config/hm/bashrc.sh"
   ```

   It loads the Home Manager session variables (`NH_FLAKE`, `PATH`), the shared
   aliases and atuin's bash hooks. See
   [Shell shortcuts](#shell-shortcuts-fish--bash).

7. **Apps come from the distro, not Nix** (Nix-built GUI apps need nixGL on a
   foreign distro). Home Manager only writes Ghostty's config; install the app
   with Omarchy's package helper, which is a no-op if it's already there:

   ```sh
   omarchy pkg add ghostty
   ```

   On Omarchy, Ghostty follows the active Omarchy theme rather than
   `ghosttyTheme` in `ghostty.nix`.

8. **Apply the Omarchy customisations** tracked in `omarchy/` (Hyprland Lua
   config, shell settings, the `mir.indicators` bar widget). `monitors.lua` is
   deliberately not tracked, so set displays up per machine.

   ```sh
   omarchy-sync push                        # repo -> ~/.config, originals kept as *.orig
   hyprctl reload && omarchy restart shell
   ```

   See [Omarchy desktop config](#omarchy-desktop-config-hyprland--shell) for
   the day-to-day `diff` / `pull` workflow.

9. **Optional: SSH access from the Mac** for remote edits and rollouts:

   ```sh
   omarchy pkg add openssh
   sudo systemctl enable --now sshd
   # then, on the Mac:
   ssh-copy-id mir@mir-omarchy-pc
   ```

Things to avoid afterwards:

- **Omarchy's text-size slider** (`omarchy display text size`) edits
  `~/.config/ghostty/config` in place, replacing Home Manager's symlink, and
  the next switch fails with "would be clobbered". Move the file aside (or
  switch with `-b backup`) and switch again.
- **Letting Home Manager manage files Omarchy owns** (`~/.bashrc`, hypr,
  waybar, alacritty, btop): Omarchy's theme switching rewrites them, which
  breaks against read-only store symlinks. That's why btop is configured only
  in `home-mac.nix` and `home-omarchy.nix` doesn't install any GUI packages.
- **Over non-interactive SSH** (`ssh host 'cmd'`), Omarchy's `.bashrc` returns
  before the Home Manager line, so aliases and `NH_FLAKE` aren't set. Use
  `ssh host 'bash -lc "nh home switch ~/dev/nix-config"'` with an explicit
  flake path.

## Everyday commands

The `nh` helper (installed via Home Manager) is the preferred entrypoint for
rebuilds.

```sh
nh home switch --ask        # Ask for confirmation before applying
```

### Update flake inputs

```sh
nix flake update
```

### Continuous integration

`.github/workflows/check.yml` evaluates every flake output on push and pull
request (`nix eval` of each home config's derivation path — nothing is
built). Run the same checks locally before pushing:

```sh
nix fmt -- --ci          # nixfmt via treefmt; plain `nix fmt` rewrites the files
nix flake show
nix eval --raw '.#homeConfigurations."mir@mir-omarchy-pc".activationPackage.drvPath'
nix eval --raw '.#homeConfigurations."nazishhussainmir@kfin-mbp-mac".activationPackage.drvPath'
```

The repo is `nixfmt`-formatted and CI fails on drift, so run `nix fmt` before
committing.

Flake inputs are bumped automatically: `.github/workflows/update-flake.yml`
runs `nix flake update` every Monday, evaluates every output, and only if
that passes opens a pull request (branch `update-flake-lock`) and merges it
straight away. `check.yml` skips lock-only PRs (a run on a bot-authored PR
would just wait for manual approval), so the in-job checks are the gate. If
they fail, no PR appears and the run shows red in the Actions tab. Afterwards
just `git pull` and `nh home switch` on each host as usual. It can also be run by
hand from the Actions tab. One-time repo setting: Settings → Actions → General
→ "Allow GitHub Actions to create and approve pull requests".

### Garbage collection

`nh clean user --keep 5 --keep-since 14d` runs weekly on every host
(`programs.nh.clean` in `home-manager/common.nix`: a systemd user timer on
Linux, a launchd agent on macOS). Manually:

```sh
nh clean user    # Clean user profiles
```

Clean a specific profile:

```sh
nix profile list
nh clean profile -a nixGL   # nixGL is the profile name; -a asks for confirmation
```

## Services

### Tailscale

```sh
sudo tailscale up -authkey tskey-auth-KEY   # Get the key from the Tailscale console
```

## Application configuration

The shell prompt uses [starship](https://starship.rs/), configured once for
every host in `home-manager/common.nix` — no manual setup step is required.
The layout mirrors Omarchy's shipped `starship.toml` and uses named colours, so
Omarchy's themes still restyle it. On a fresh Omarchy install move Omarchy's
copy aside before the first switch:

```sh
mv ~/.config/starship.toml ~/.config/starship.toml.omarchy
```

Over SSH the prompt starts with `⇄ <hostname>` so a remote shell is obvious
(fish and Omarchy's bash alike). Each host file sets its own hostname colour
(`programs.starship.settings.hostname.style`): macOS green (the default),
Omarchy purple.

On macOS, a new fish shell warns when the Mac has drifted from
`macos/Brewfile` (checked at most once a day); fix it with
`brew bundle install --file=macos/Brewfile`.

### Omarchy desktop config (Hyprland + shell)

Omarchy's own user config — `~/.config/hypr/*.lua`, `hyprsunset.conf`,
`xdph.conf`, `~/.config/omarchy/shell.json`, `shell.toml` and the cloned
`mir.indicators` and `mir.switch-user` bar widgets — is kept in git as plain copies under `omarchy/`.
Home Manager does not manage these files and they are never symlinked:
Omarchy's shell saves `shell.json` atomically and its migrations move new
files over the Lua config, either of which would replace a symlink with a
regular file. `monitors.lua` is left out because it holds one machine's
outputs and scale.

`bin/omarchy-sync` (on `PATH` via Home Manager) copies in either direction:

```sh
omarchy-sync diff   # what differs between ~/.config and omarchy/
omarchy-sync pull   # ~/.config -> omarchy/, then commit
omarchy-sync push   # omarchy/ -> ~/.config (overwritten files kept as *.orig)
hyprctl reload && omarchy restart shell   # after a push
```

Day to day: edit the live files in `~/.config`, then `pull` and commit. A new
fish shell on Omarchy warns when the live files and the repo differ. On a
fresh Omarchy machine, run the first Home Manager switch, then `omarchy-sync
push`.

### ScrollOverview plugin

The tracked `hyprland.lua` loads
`~/.local/share/hyprland-scroll-overview/scrolloverview.so`, and `bindings.lua`
binds **Super+Ctrl+G** to toggle the overview across monitors. These are captured
from the working live configuration and travel through `omarchy-sync`.

The compiled plugin is not committed or built with Nix. The known-working
source/Hyprland pair is recorded in
[`omarchy/system/scrolloverview/pins.json`](omarchy/system/scrolloverview/pins.json).
The source is [yayuuu/hyprland-scroll-overview](https://github.com/yayuuu/hyprland-scroll-overview),
at `07a944e4d16f11d2d9be6ce10bea74a6f1e5f2ae` for Hyprland 0.56.2 commit
`efb50993780079460b0cbed1363e2166a2de1d9f`.

On a new installation, build the plugin **before** pushing the Lua config:

```sh
omarchy-scrolloverview-setup
# Before the repo's bin directory is on PATH:
bash ~/dev/nix-config/bin/omarchy-scrolloverview-setup
omarchy-sync push
```

The helper checks native build tools, pkg-config dependencies and the exact
Hyprland header commit, builds the pinned source in a temporary directory using
upstream's Makefile, and installs the shared library with a backup. It reuses
the existing source checkout as a cache when available. It does not invoke
sudo, load/unload plugins, or reload the compositor. Native dependencies come
from Arch: `base-devel`, `git`, `pkgconf` and the development headers named by
upstream's Makefile; missing pkg-config dependencies are reported before a build.

To check the current installation without changing it:

```sh
omarchy-scrolloverview-setup --check
```

After a Hyprland upgrade, review plugin compatibility and update both revisions
in `pins.json` before rebuilding. The helper refuses mismatched headers rather
than building the old plugin against a new compositor. It checks installed
headers, not the running compositor; if the package was updated mid-session,
the running and installed versions may differ. Do not load a rebuilt plugin
into an incompatible running session. The current working setup needs no rebuild.

### Omarchy family user switching

The working `mir`/`ayaan` setup is tracked in
[`omarchy/system/family-switch`](omarchy/system/family-switch). It uses Omarchy's
existing UWSM desktop command and the upstream
[omarchy-multi-user](https://github.com/drodol/omarchy-multi-user) bar widget,
with a local helper that avoids SDDM's failing second-greeter path.

Boot still automatically enters `mir`. The first Switch user opens tty3's
normal username/password login; signing in as `ayaan` automatically starts his
desktop. Later switches lock the current desktop and resume the other one,
retaining both users' open applications. No passwords are stored. Ayaan's
desktop is not started automatically at boot.

After cloning this repo, or after changing these system-side files, run:

```sh
omarchy-family-setup
# Before the repo's bin directory is on PATH:
bash ~/dev/nix-config/bin/omarchy-family-setup
```

This explicit setup command requests sudo. It installs the shared helper at
`/usr/local/bin/omarchy-family-switch`, merges a tty3-only block into Ayaan's
`.bash_profile`, enables the standard password-based `getty@tty3.service`, and
installs each user's switch widget before their bar's power button. It saves
backups and prints a rollback command. It does not reboot, restart SDDM, log
anyone out, or switch the screen. The setup is intentionally outside Home
Manager activation: HM manages neither system login services nor Ayaan's home.

Prerequisites: `mir` and `ayaan` must already exist with initialized, independent
Omarchy desktops and plain `shell.json` files; Ayaan needs a Bash login shell
and a password. Account creation, administrator permissions, user provisioning,
and SDDM's boot-autologin configuration remain separate. The old custom SDDM
Family theme is not required by this workaround and is not installed here.

`omarchy-sync` tracks mir's widget and bar config. The explicit setup command
generates Ayaan's widget from that tracked widget; do not copy his entire home
or manage it through mir's Home Manager configuration. The former
`~/dev/omarchy-multi-user` working directory is no longer needed to reproduce
the switching customisation.

Validation without changing live sessions:

```sh
python3 omarchy/system/family-switch/check-switching.py
shellcheck bin/omarchy-family-setup bin/omarchy-sync omarchy/system/family-switch/*.sh \
  omarchy/system/family-switch/omarchy-family-switch omarchy/system/family-switch/ayaan-tty3.bash
/usr/local/bin/omarchy-family-switch --check  # from mir's desktop terminal, no sudo
```

UWSM's startup preflight must explicitly allow tty3 (`uwsm check may-start -v
3`); its default permits only tty1. The profile block excludes SSH, graphical
terminals, other consoles, and already-running UWSM desktops.

Keep SSH open for the first live test after deployment. Verify `mir → ayaan →
mir → ayaan` retains both desktops' windows. If the physical seat freezes on
mir's occupied tty1, the recovery that worked on this host is `sudo chvt 3`
followed by `sudo chvt 1`; restarting SDDM would instead terminate desktops.

### Shell shortcuts (fish + bash)

Aliases and abbreviations are defined once in `home-manager/aliases.nix` and
reach fish on every host automatically. For a bash that Home Manager does not
manage (Omarchy), add this single line at the bottom of `~/.bashrc`:

```sh
. "$HOME/.config/hm/bashrc.sh"
```

It loads the Home Manager session variables, the generated
`~/.config/hm/aliases.sh` (so the same shortcuts work in bash), and atuin's
bash hooks (`~/.config/hm/atuin.sh`).

### Fish shell

Fish is installed and configured for every host via `home-manager/common.nix`.
To make it the **login shell** on macOS, register and switch to the
Home-Manager-provided fish (not on Omarchy, which relies on bash):

```sh
sudo sh -c 'echo $HOME/.nix-profile/bin/fish >> /etc/shells'
chsh -s $HOME/.nix-profile/bin/fish
```

## License

Released under the [MIT License](LICENSE) — free to use, copy, and adapt.
