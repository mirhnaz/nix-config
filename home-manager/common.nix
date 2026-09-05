{ config, lib, pkgs, inputs, ... }:

{

  imports = [
    ./ghostty.nix
    ./aliases.nix # shared shell shortcuts (fish + Omarchy bash)
  ];

  home.packages = with pkgs; [
    
    #basics
    git

    #shell utilities
    grc
    fzf
    eza # `ll` in aliases.nix

    #fonts
    meslo-lgs-nf
    fira-code
    fira-code-symbols
    source-code-pro
    nerd-fonts.meslo-lg
    nerd-fonts.ubuntu-sans
    nerd-fonts.zed-mono
    #nerd-fonts.iosevka
    #nerd-fonts.iosevka-term
    nerd-fonts.symbols-only
    nerd-fonts.jetbrains-mono
    meslo-lg

    #lang utils
    ripgrep
    fd
    pandoc
    shellcheck
    nixfmt
    nixpkgs-fmt

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
  };

  programs.btop = {
    enable = true;
    settings = {
      shown_boxes = "cpu gpu0 proc";
    };
  };

  programs.starship = {
    enable = true;
    settings = {                                      
      # user@host on the right side of the prompt — only over SSH (hostname
      # is ssh_only, username hides for the local user), so a remote shell is
      # obvious. Fish/zsh only: bash has no right prompt (starship needs
      # ble.sh there). Omarchy forces settings empty and uses its own
      # starship.toml — see hosts/home-omarchy.nix for its SSH marker.
      right_format = "$username$hostname";
                                   
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
      #{ name = "grc"; src = pkgs.fishPlugins.grc.src; }
      { name = "fzf-fish"; src = pkgs.fishPlugins.fzf-fish.src; }
      { name = "colored-man-pages"; src = pkgs.fishPlugins.colored-man-pages.src; }
      { name = "sponge"; src = pkgs.fishPlugins.sponge.src; }
    ];
  
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
