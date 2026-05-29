{ config, pkgs, inputs, ... }:

{

  home.packages = with pkgs; [
    
    #basics
    git

    #shell utilities
    grc
    fzf

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
    meslo-lgs-nf
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

    #development
    github-cli
    cloc

    #other utils
    #yt-dlp
    #ffmpeg
 
  ];

  home.sessionVariables = {
    FONTCONFIG_FILE = "${pkgs.fontconfig.out}/etc/fonts/fonts.conf";
    NIX_HOME = "$HOME/dev/nix-config";
    NIXPKGS_ALLOW_UNFREE = 1;
    
    #needed for CISCO SASE VPN client to work without breaking certs on the system
    # UV_SYSTEM_CERTS = 1;
    # SSL_CERT_FILE = "$HOME/dev/CiscoSecureAccessRootCA.pem";
    # REQUESTS_CA_BUNDLE = "$HOME/dev/CiscoSecureAccessRootCA.pem";

    #macos specific env
    HOMEBREW_PREFIX = "/opt/homebrew";
    HOMEBREW_CELLAR = "/opt/homebrew/Cellar";
    HOMEBREW_REPOSITORY = "/opt/homebrew";
    INFOPATH = "/opt/homebrew/share/info";

    #linux specific env
    MOZ_USE_XINPUT2 = 1;
  };

  home.sessionPath = [
    "$HOME/.config/emacs/bin"
    "$NIX_HOME/bin"
    "$HOME/.nix-profile/bin/"
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"

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
      # Put user + host on the right side of the prompt.                                                    
      right_format = "$username$hostname";            
                                   
      username = {                                    
        show_always = true;                           
        format = "[$user]($style)";                   
        style_user = "yellow bold";                   
        style_root = "red bold";
      };     

      hostname = {                                    
        ssh_only = false;                             
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
  
    interactiveShellInit = ''
      starship init fish | source
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
  
    shellAliases = {
      ll = "ls -al";
      rm = "safe-rm";
      "..." = "cd ../..";
    };
  
    shellAbbrs = {
      gs = "git status";
      ga = "git add .";
      gc = "git commit -m";
      gpull = "git pull origin main";
      gpush = "git push origin main";
      nhos = "nh os switch";
      nhh = "nh home switch";
      c = "clear";
      ff = "fastfetch";
    };
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

}
