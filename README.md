# nix-config

A personal [Nix](https://nixos.org/) flake managing system (NixOS) and user
(Home Manager) configuration across several hosts and platforms: NixOS
desktops/laptops, an aarch64 NixOS VM, macOS (`aarch64-darwin`), and Pop!_OS as
a Home-Manager-only target.

There is no application code here — every change is configuration that gets
evaluated by Nix and activated on a host.

## Contents

- [Overview](#overview)
- [Initial setup](#initial-setup)
- [Installing Nix](#installing-nix)
- [NixOS setup](#nixos-setup)
- [Home Manager (standalone)](#home-manager-standalone)
- [macOS setup](#macos-setup)
- [Everyday commands](#everyday-commands)
- [Inspecting changes](#inspecting-changes)
- [Services](#services)
- [Application configuration](#application-configuration)

## Overview

Configuration is split into two output sets in `flake.nix`, keyed by host:

- `nixosConfigurations.<host>` — full NixOS systems.
- `homeConfigurations."mir@<host>"` — standalone Home Manager (used on macOS and
  Pop!_OS, and on NixOS hosts too, since Home Manager is not imported as a NixOS
  module here).

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
git clone git@github.com:nazmir/nix-config.git
```

## Installing Nix

NixOS already ships with Nix. On non-NixOS systems (macOS, Pop!_OS) install it
first:

```sh
# Installs upstream Nix (not the Determinate distribution) via the
# Determinate Systems installer.
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

## NixOS setup

Bring the system-generated config files under repo control, then rebuild. The
`rename-and-link.sh` script backs up the source file (arg 1) and links it to the
target (arg 2).

> **Note:** Don't rename the hardware config to a machine-specific name the way
> `configuration.nix` is renamed — keep it as `hardware-configuration.nix`.

```sh
sudo ~/dev/nix-config/bin/rename-and-link.sh /etc/nixos/configuration.nix ~/dev/nix-config/nixos/hosts/pc/configuration-pc.nix
sudo ~/dev/nix-config/bin/rename-and-link.sh /etc/nixos/hardware-configuration.nix ~/dev/nix-config/nixos/hosts/pc/hardware-configuration.nix
sudo nixos-rebuild switch --flake $HOME/dev/nix-config/.#mir-nixos-pc
```

## Home Manager (standalone)

Used on every host (NixOS, macOS, Pop!_OS). Update inputs and link the generated
config into the repo before the first switch.

```sh
cd ~/dev/nix-config
nix flake update

# Initialize Home Manager; places a config at ~/.config/home-manager/home.nix
nix run home-manager/master -- init --switch

# Drop the generated flake and link our host file in its place
rm ~/.config/home-manager/flake.*
~/dev/nix-config/bin/rename-and-link.sh ~/.config/home-manager/home.nix ~/dev/nix-config/home-manager/hosts/home-nixos.nix

# Initial evaluation with flakes
home-manager switch --flake ~/dev/nix-config/.#mir@mir-nixos-pc
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
   home-manager switch --flake ~/dev/nix-config/.#mir@mir-m4pro-mbp
   ```

3. **Set fish as the login shell** (fish is installed via Home Manager):

   ```sh
   sudo sh -c 'echo $HOME/.nix-profile/bin/fish >> /etc/shells'
   chsh -s $HOME/.nix-profile/bin/fish
   ```

4. **Ghostty** — the nixpkgs `ghostty` package is Linux-only, so the app itself
   is installed via Homebrew, while its configuration is managed declaratively by
   Home Manager in `home-manager/hosts/home-mac.nix`:

   ```sh
   brew install --cask ghostty
   ```

## Everyday commands

The `nh` helper (installed via Home Manager) is the preferred entrypoint for
rebuilds.

```sh
nh os switch --ask          # Ask for confirmation before applying
nh home switch --ask
#home-manager switch --flake '.#mir@mir-nixos-pc'
nh home switch -c mir@mir-nixos-pc ./

# Specify the flake explicitly:
nh os switch --ask ~/dev/nix-config/.#mir-nixos-thinkpad

# Use the current hostname with an explicit flake path:
nh os switch --ask ~/dev/nix-config/
```

### Update flake inputs

```sh
nix flake update
```

### Garbage collection

```sh
nh clean all     # Clean OS and Home profiles
nh clean user    # Clean user profiles
```

Clean a specific profile:

```sh
nix profile list
nh clean profile -a nixGL   # nixGL is the profile name; -a asks for confirmation
```

### Rebuild without `nh`

If the `nh` helper isn't installed yet (e.g. a fresh install):

```sh
sudo nixos-rebuild switch --flake $HOME/dev/nix-config/.#mir-nixos-thinkpad
home-manager switch --flake $HOME/dev/nix-config/.#mir@mir-nixos-thinkpad
```

## Inspecting changes

Build the result before switching, then diff it against the running system:

```sh
sudo nixos-rebuild build --flake $HOME/dev/nix-config/.#mir-nixos-thinkpad
```

```sh
nvd diff /run/current-system/ ./result/
nvd diff $(ls -d1v /nix/var/nix/profiles/system-*-link|tail -n 2)   # Compare after a switch
```

`nvd` wraps `nix store diff-closures` with improved reporting. The underlying
command is:

```sh
nix store diff-closures $(ls -d1v /nix/var/nix/profiles/system-*-link|tail -n 2)
```

## Services

### Tailscale

```sh
sudo tailscale up -authkey tskey-auth-KEY   # Get the key from the Tailscale console
```

## Application configuration

The shell prompt uses [starship](https://starship.rs/), configured declaratively
in `home-manager/common.nix` — no manual setup step is required.

### Doom Emacs

Install Doom Emacs, then run `doom doctor` to check for issues. Back up an
existing `~/.emacs.d` first:

```sh
mv ~/.emacs.d ~/.emacs.d.orig
```

Link the Doom configuration into the repo:

```sh
~/dev/nix-config/bin/rename-and-link.sh ~/.config/doom/ ~/dev/nix-config/.config/doom
```

### Sway

```sh
~/dev/nix-config/bin/rename-and-link ~/.config/sway/config ~/.config/sway/config
```

### Kitty

```sh
~/dev/nix-config/bin/rename-and-link ~/.config/kitty/ ~/dev/nix-config/.config/kitty
# The result will be in the current folder
```
