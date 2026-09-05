{ config, pkgs, ... }:

{

  #Boot Loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  #boot.loader.systemd-boot.consoleMode = "max";

  #Boot Options
  boot.initrd.verbose = false;
  boot.initrd.systemd.enable = true;
  boot.kernelParams = [
    "quiet"
    "udev.log_level=0"
  ];
  boot.consoleLogLevel = 0;
  boot.plymouth.enable = true;
  # boot.plymouth.theme = "breeze";

  # Enable the X11 windowing system.
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # services.displayManager.cosmic-greeter.enable = true;

  # services.displayManager = {
  #  defaultSession = "plasma";
  #  autoLogin = {
  #      enable = true;
  #      user = "mir";
  #  };
  # };

  services.desktopManager = {
    plasma6.enable = true;
    cosmic.enable = true;
  };

  # services.xserver = {
  #   enable = true;
  #   displayManager.gdm = {
  #     enable = true;
  #     wayland = true;
  #   };
  #   desktopManager.gnome.enable = true;
  # };

  # services.gnome = {
  #  gnome-remote-desktop.enable = true;
  # };

  # programs.ssh.askPassword = pkgs.lib.mkForce "${pkgs.ksshaskpass.out}/bin/ksshaskpass";
  # programs.ssh.askPassword = pkgs.lib.mkForce "${pkgs.seahorse.out}/libexec/seahorse/ssh-askpass";

  security.pam.services = {
    login.kwallet = {
      enable = true;
    };
    kde = {
      kwallet = {
        enable = true;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    #vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #wget
    pciutils
    desktop-file-utils
    virt-manager
    gparted
    git
    firefox
    # krfb
    # pkgs.gnome-remote-desktop
  ];

  # Set your time zone.
  time.timeZone = "Asia/Kolkata";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Configure keymap in X11
  services.xserver = {
    xkb.layout = "us";
    xkb.variant = "";
  };

  # Enable Network Manager
  networking.networkmanager.enable = true;
  #This is needed in case of for example servers that rely on network resources as part of the boot process
  systemd.services.NetworkManager-wait-online.enable = false;

  # Firewall and enable SSH 22 port
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      53
      3389
      3390
      5353
      33293
    ];
    allowedUDPPorts = [
      53
      5353
      33293
    ];
  };

  #Tailscale
  services.tailscale.enable = true;

  #Avahi
  services.avahi = {
    enable = true;
    openFirewall = true;
    domainName = "local";
    nssmdns4 = true;
    publish = {
      enable = true;
      domain = true;
      workstation = true;
      hinfo = true;
      addresses = true;
      userServices = true;
    };
  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Enable OpenSSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
    };
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  #sound.enable = true;
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Allow unfree packages and nix flakes
  nixpkgs.config.allowUnfree = true;
  nix = {
    package = pkgs.nixVersions.latest;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  #Flatpak, fish and other customization
  services.flatpak.enable = true;
  programs.fish.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mir = {
    isNormalUser = true;
    description = "Naz Mir";
    extraGroups = [
      "networkmanager"
      "wheel"
      "libvirtd"
      "systemd-journal"
    ];
    shell = pkgs.fish;
    packages = with pkgs; [
    ];
  };

  # Virtualization Config
  virtualisation.libvirtd.enable = true;

  # nano config
  programs.nano = {
    nanorc = ''
            set tabsize 2
      			set linenumbers
    '';
  };

  # Systemd config
  systemd.settings.Manager = {
    DefaultTimeoutStopSec = "10s";
  };

  system.stateVersion = "23.05"; # Did you read the comment?

}
