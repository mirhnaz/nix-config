{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{

  imports = [
    ./ghostty.nix
    ./aliases.nix # shared shell shortcuts (fish + Omarchy bash)
  ];

  home.packages =
    with pkgs;
    [

      #basics
      git

      #shell utilities
      grc
      fzf
      eza # `ll` in aliases.nix

      #fonts
      fira-code
      fira-code-symbols
      source-code-pro
      # Provides both "MesloLGM Nerd Font" (ghostty.nix) and "MesloLGS Nerd
      # Font Mono" (kitty in home-nixos.nix); the unpatched meslo-lg and the
      # powerlevel10k meslo-lgs-nf builds were redundant with it.
      nerd-fonts.meslo-lg
      nerd-fonts.ubuntu-sans
      nerd-fonts.zed-mono
      #nerd-fonts.iosevka
      #nerd-fonts.iosevka-term
      nerd-fonts.symbols-only
      nerd-fonts.jetbrains-mono

      #lang utils
      ripgrep
      fd
      pandoc
      shellcheck
      nixfmt # `nix fmt` uses the flake's nixfmt-tree; this is for editors/CLI

      #sytem utils
      tldr
      nmap
      safe-rm

      #development
      github-cli
      cloc
      git-lfs

      #other utils
      #yt-dlp
      #ffmpeg

    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      # fastfetch's darwin build drags apple-sdk (~1.3 GiB) + imagemagick/vulkan
      # into the profile closure; on macOS it comes from Homebrew instead
      # (macos/Brewfile).
      fastfetch
    ];

  home.sessionVariables = {
    FONTCONFIG_FILE = "${pkgs.fontconfig.out}/etc/fonts/fonts.conf";
    NIX_HOME = "$HOME/dev/nix-config";
    NIXPKGS_ALLOW_UNFREE = 1;

    #needed for CISCO SASE VPN client to work without breaking certs on the system
    # UV_SYSTEM_CERTS = 1;
    # SSL_CERT_FILE = "$HOME/dev/CiscoSecureAccessRootCA.pem";
    # REQUESTS_CA_BUNDLE = "$HOME/dev/CiscoSecureAccessRootCA.pem";
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    #macos specific env
    HOMEBREW_PREFIX = "/opt/homebrew";
    HOMEBREW_CELLAR = "/opt/homebrew/Cellar";
    HOMEBREW_REPOSITORY = "/opt/homebrew";
    INFOPATH = "/opt/homebrew/share/info";
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    #linux specific env
    MOZ_USE_XINPUT2 = 1;
  };

  home.sessionPath = [
    "$HOME/.config/emacs/bin"
    "$NIX_HOME/bin"
    "$HOME/.nix-profile/bin/"
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    #macos specific paths
    "/nix/var/nix/profiles/default/bin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];

  programs.git = {
    enable = true;
    signing.format = null;
    settings = {
      user.email = "mirnaz.hussain@gmail.com";
      user.name = "Naz Mir";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.default = "simple";
    };
  };

  programs.nh = {
    enable = true;
    flake = "$HOME/dev/nix-config";
    # Weekly `nh clean user`: systemd user timer on Linux, launchd agent on
    # macOS. Keeps the last 5 generations and anything newer than 14 days.
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep 5 --keep-since 14d";
    };
  };

  # Shell history: one SQLite database, fuzzy Ctrl+R / Up search, shared by
  # every shell on the host. HM wires the fish side itself
  # (enableFishIntegration defaults on). Its bash integration only reaches
  # `programs.bash`, which is not enabled here (Omarchy owns ~/.bashrc), so the
  # same init is written to ~/.config/hm/atuin.sh and sourced from
  # ~/.config/hm/bashrc.sh (aliases.nix) — see below.
  programs.atuin = {
    enable = true;
    settings = {
      update_check = false; # the binary comes from nixpkgs
    };
  };

  # fzf-fish also binds Ctrl+R (to its own history search). Drop that one
  # binding so atuin owns Ctrl+R; the other fzf-fish binds stay. Lives in
  # conf.d ("zz-" sorts after HM's "plugin-fzf-fish") so it runs after the
  # plugin installs its defaults but before config.fish sources atuin.
  xdg.configFile."fish/conf.d/zz-fzf-bindings.fish".text = ''
    fzf_configure_bindings --history=
  '';

  # Counterpart of HM's programs.bash.initExtra snippet (modules/programs/atuin.nix)
  # for a bash HM does not manage. The SHELLOPTS guard skips shells without
  # line editing, as upstream does.
  #
  # Deliberately does NOT source pkgs.bash-preexec first, unlike HM's snippet.
  # On Arch, /etc/bash.bashrc makes PROMPT_COMMAND an array, and bash-preexec
  # 0.6.0 (nixpkgs, 2026-09) mishandles that during its lazy first-prompt
  # install: the remaining array elements (title printf, zoxide/mise hooks)
  # run with "interactive mode" already on, so the DEBUG trap records the
  # stale last line of ~/.bash_history and skips the real first command of
  # every session. Fixed upstream in 0.7.0 (rcaloras/bash-preexec #180,
  # #188). atuin's `init bash` embeds its own copy of the hooks, already
  # carrying those fixes, and uses it when no external bash-preexec (or
  # ble.sh) is loaded — verified 2026-09-06 with atuin 18.19.0 on Omarchy.
  xdg.configFile."hm/atuin.sh".text = ''
    # Generated by Home Manager from home-manager/common.nix.
    if [[ :$SHELLOPTS: =~ :(vi|emacs): ]]; then
      eval "$(${lib.getExe config.programs.atuin.package} init bash ${lib.escapeShellArgs config.programs.atuin.flags})"
    fi
  '';

  programs.btop = {
    enable = true;
    settings = {
      shown_boxes = "cpu gpu0 proc";
    };
  };

  # Prompt: one starship config for every host. The layout mirrors Omarchy's
  # shipped /usr/share/omarchy/config/starship.toml (Omarchy 4.0) so the prompt
  # looks the same on macOS, Pop!_OS and Omarchy. Colours are *named* ANSI
  # colours ("cyan"), never hex: that is how Omarchy's themes reach the prompt
  # (they repaint the terminal palette; starship.toml itself is never touched
  # by a theme), so theming keeps working with HM owning the file. If Omarchy
  # changes its shipped file, home-omarchy.nix's fish greeting says so —
  # re-sync the values here.
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      command_timeout = 200;
      format = "[$directory$git_branch$git_status]($style)$character";

      # user@host on the right side of the prompt — only over SSH (hostname
      # is ssh_only, username hides for the local user), so a remote shell is
      # obvious. Fish/zsh only: bash has no right prompt (starship needs
      # ble.sh there) — see hosts/home-omarchy.nix for the bash fallback.
      right_format = "$username$hostname";

      character = {
        success_symbol = "[❯](bold cyan)";
        error_symbol = "[✗](bold cyan)";
      };

      directory = {
        truncation_length = 2;
        truncation_symbol = "…/";
        repo_root_style = "bold cyan";
        repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) ";
      };

      git_branch = {
        format = "[$branch]($style) ";
        style = "italic cyan";
      };

      git_status = {
        format = "[$all_status]($style)";
        style = "cyan";
        ahead = "⇡\${count} ";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count} ";
        behind = "⇣\${count} ";
        conflicted = " "; # nerd-font glyphs, as in Omarchy's file
        up_to_date = " ";
        untracked = "? ";
        modified = " ";
        stashed = "";
        staged = "";
        renamed = "";
        deleted = "";
      };

      username = {
        show_always = false;
        format = "[$user]($style)";
        style_user = "yellow bold";
        style_root = "red bold";
      };

      hostname = {
        ssh_only = true;
        format = "[@$hostname]($style) ";
        style = "green bold";
      };
    };
  };

  # # Configure direnv
  # programs.direnv = {
  #   enable = true;
  #   package = pkgs.direnv.overrideAttrs (old: {
  #     doCheck = false;
  #     doInstallCheck = false;
  #   });
  # };

  programs.fish = {
    enable = true;

    plugins = [
      # grc colourises output of common CLI tools (ping, df, ps, dig, ...); the
      # `grc` package is in home.packages. `ls` is excluded — see the conf.d
      # file below — so plain ls stays plain and `ll`/eza is untouched.
      {
        name = "grc";
        src = pkgs.fishPlugins.grc.src;
      }
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
      {
        name = "colored-man-pages";
        src = pkgs.fishPlugins.colored-man-pages.src;
      }
      {
        name = "sponge";
        src = pkgs.fishPlugins.sponge.src;
      }
    ];

    # macOS: warn at shell start when the Mac has drifted from macos/Brewfile
    # (a missing brew formula silently breaks things like the `ff` abbr, since
    # fastfetch comes from Homebrew there). `brew bundle check` costs ~0.3s, so
    # it runs at most once a day — or every shell while drift is known, so the
    # notice keeps showing until it is fixed.
    functions.fish_greeting = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin ''
      command -q brew; or return
      set -l brewfile $NIX_HOME/macos/Brewfile
      set -l stamp $HOME/.cache/hm/brewfile-check
      if not test -f $stamp; or test "$(cat $stamp)" = drift; or test -z "$(find $stamp -mmin -1440)"
        mkdir -p (dirname $stamp)
        if HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 brew bundle check --file=$brewfile >/dev/null 2>&1
          echo ok > $stamp
        else
          echo drift > $stamp
        end
      end
      if test "$(cat $stamp)" = drift
        set_color yellow
        echo "Homebrew drift — run: brew bundle install --file=$brewfile"
        set_color normal
      end
    '';

    shellInitLast = ''
      if test "$TERM" = "dumb"
        function fish_prompt
          echo "\$ "
        end
        function fish_right_prompt; end
        function fish_greeting; end
        function fish_title; end
      end
    '';

    # Aliases/abbreviations live in ./aliases.nix (shared with bash on Omarchy).
  };

  # Must be set before the grc plugin's conf.d runs (fish loads conf.d before
  # config.fish, alphabetically — "00-" sorts before HM's "plugin-grc").
  xdg.configFile."fish/conf.d/00-grc-ignore.fish".text = ''
    set -g grc_plugin_ignore_execs ls
  '';

  # programs.zsh = {
  #   enable = true;
  #   enableCompletion = true;
  #   autosuggestion.enable = true;
  #   syntaxHighlighting.enable = true;

  #   history = {
  #     size = 10000;
  #     save = 10000;
  #     ignoreDups = true;
  #     ignoreAllDups = true;
  #     share = true;
  #   };

  #   shellAliases = {
  #     ll = "ls -al";
  #     "..." = "cd ../..";
  #     gs = "git status";
  #     ga = "git add .";
  #     gc = "git commit -m";
  #     gpull = "git pull origin main";
  #     gpush = "git push origin main";
  #     nhos = "nh os switch --ask";
  #     nhhome = "nh home switch --ask";
  #     rm = "safe-rm";
  #     c = "clear";
  #   };

  # plugins = [
  #   {
  #     name = "fzf-tab";
  #     src = pkgs.zsh-fzf-tab;
  #     file = "share/fzf-tab/fzf-tab.plugin.zsh";
  #   }
  # ];

  #   initContent = ''
  #     # Dumb terminal support (Emacs TRAMP etc.)
  #     if [[ "$TERM" == "dumb" ]]; then
  #       unsetopt zle
  #       PS1='$ '
  #       return
  #     fi
  #   '';
  # };

  # programs.fzf = {
  #   enable = true;
  #   enableZshIntegration = true;
  # };

  fonts.fontconfig.enable = true;
  #Allow unfree
  nixpkgs.config.allowUnfreePredicate = _: true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Skip the generated `man home-configuration.nix` page. Building it evaluates
  # every option declaration and, with Nix >= 2.34, warns "'options.json'
  # references the store path ... without a proper context". The online docs
  # at https://nix-community.github.io/home-manager/options.xhtml are the same
  # content. Flip to true if you want the manpage back.
  manual.manpages.enable = false;

}
