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

The repo is expected to live at `~/dev/nix-config`. The `bin/rename-and-link.sh`
helper backs up a system-generated file and replaces it with a symlink into this
repo, bringing it under version control.

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

Used on every host (macOS, Omarchy). Link the generated config
into the repo before the first switch.

```sh
cd ~/dev/nix-config

# Initialize Home Manager; places a config at ~/.config/home-manager/home.nix
nix run home-manager/master -- init --switch

# Drop the generated flake and link our host file in its place
rm ~/.config/home-manager/flake.*
~/dev/nix-config/bin/rename-and-link.sh ~/.config/home-manager/home.nix ~/dev/nix-config/home-manager/hosts/home-<host>.nix

# Initial evaluation with flakes
home-manager switch --flake ~/dev/nix-config/.#<user>@<host>
```

## macOS setup

macOS (`aarch64-darwin`) follows the shared flow —
[Initial setup](#initial-setup), [Installing Nix](#installing-nix), and
[Home Manager (standalone)](#home-manager-standalone) — with the macOS-specific
notes below.

1. **git** comes from the Xcode Command Line Tools

   ```sh
   xcode-select --install
   ```

2. **Home Manager** uses the macOS host file and flake target when you reach the
   [Home Manager](#home-manager-standalone) step:

   ```sh
   ~/dev/nix-config/bin/rename-and-link.sh ~/.config/home-manager/home.nix ~/dev/nix-config/home-manager/hosts/home-mac.nix
   home-manager switch --flake ~/dev/nix-config/.#nazishhussainmir@K-H-2005735-M
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
  breaks against read-only store symlinks. That's why `home-omarchy.nix`
  disables btop and doesn't import any GUI packages.
- **Over non-interactive SSH** (`ssh host 'cmd'`), Omarchy's `.bashrc` returns
  before the Home Manager line, so aliases and `NH_FLAKE` aren't set. Use
  `ssh host 'bash -lc "nh home switch ~/dev/nix-config"'` with an explicit
  flake path.

## Everyday commands

The `nh` helper (installed via Home Manager) is the preferred entrypoint for
rebuilds.

```sh
nh home switch --ask        # Ask for confirmation before applying
# The Mac's hostname doesn't match its flake output, so name it:
nh home switch -c nazishhussainmir@K-H-2005735-M ~/dev/nix-config
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
nix eval --raw '.#homeConfigurations."nazishhussainmir@K-H-2005735-M".activationPackage.drvPath'
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
`mir.indicators` bar widget — is kept in git as plain copies under `omarchy/`.
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

### Doom Emacs

Install Doom Emacs, then run `doom doctor` to check for issues. Back up an
existing `~/.emacs.d` first:

```sh
mv ~/.emacs.d ~/.emacs.d.orig
```

`~/.config/emacs/bin` is already on `PATH` via `home-manager/common.nix`. The
Doom config itself (`~/.config/doom`) is not managed by this repo.

## License

Released under the [MIT License](LICENSE) — free to use, copy, and adapt.
