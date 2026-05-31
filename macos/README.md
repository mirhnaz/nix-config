# macOS non-Nix channels

This directory tracks the parts of a macOS setup that live **outside** the Nix
flake. On macOS this repo runs standalone Home Manager (no nix-darwin), so
`nh`/Home Manager only manages Nix packages. Homebrew, global `uv` tools, and
hand-downloaded apps are not reproducible from the flake — they are tracked here
instead.

| File | Channel | Reproducible? |
|---|---|---|
| `Brewfile` | Homebrew formulae + casks (and `uv` tools) | ✅ `brew bundle install` |
| `uv-tools.txt` | Global `uv` tools (brew-independent fallback) | ✅ loop below |
| `apps.md` | Hand-downloaded / App Store GUI apps | ⚠️ checklist, not auto-restore |

## New-machine bootstrap (run in order)

```sh
# 0. Prerequisites: install Nix, Homebrew, and uv if not already present.
#    Nix:  https://nixos.org/download  (or Determinate Systems installer)
#    Brew: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
#    uv:   curl -LsSf https://astral.sh/uv/install.sh | sh

# 1. Nix layer (Home Manager) — the bulk of your CLI + dotfiles
nh home switch -c mir@mir-m4pro-mbp ~/dev/nix-config
#   (use mir@mir-air-mbp or the matching host output as appropriate)

# 2. Homebrew layer — formulae, casks, and uv tools in one shot
brew bundle install --file=~/dev/nix-config/macos/Brewfile

# 3. (Optional) uv tools, if you skipped brew or want them brew-independent
while read -r t; do [ -n "$t" ] && [ "${t#\#}" = "$t" ] && uv tool install "$t"; done \
  < ~/dev/nix-config/macos/uv-tools.txt

# 4. Manual apps — open the checklist and reinstall each
open ~/dev/nix-config/macos/apps.md
```

## Keeping it current

Re-snapshot after you install/remove things, then commit:

```sh
brew bundle dump --file=~/dev/nix-config/macos/Brewfile --describe --force
uv tool list | awk '/^[^ -]/ {print $1}' > ~/dev/nix-config/macos/uv-tools.txt
```

## When to consider nix-darwin

Today you have ~4 brew formulae and 0 casks — a Brewfile is the right,
low-effort choice. Revisit [nix-darwin](https://github.com/LnL7/nix-darwin) if:

- your Homebrew list grows past ~15–20 packages, **or**
- you want macOS system defaults (Dock, Finder, keyboard, launchd) managed
  declaratively, **or**
- you want one `nh os switch` to rebuild the whole Mac (Nix **and** brew).

nix-darwin's `homebrew.casks = [ ... ]` block folds the Brewfile contents into
the flake — at the cost of a larger migration that takes over system config.
