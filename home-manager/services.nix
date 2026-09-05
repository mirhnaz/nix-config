{
  config,
  lib,
  pkgs,
  ...
}:

{
  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };

    "org/gnome/mutter" = {
      experimental-features = [
        "scale-monitor-framebuffer"
        "xwayland-native-scaling"
      ];
    };
  };

  # services.emacs = {
  #   enable = true;
  #   startWithUserSession = "graphical";
  #   socketActivation.enable = true;
  #   defaultEditor = true;
  # };

  # systemd.user.services.kwalletpam = {
  #   description = "Start kwallet pam on auto login";
  #   serviceConfig.PassEnvironment = "DISPLAY";
  #   script = ''
  #     ${pkgs.kdePackages.kwallet-pam}/libexec/pam_kwallet_init
  #   '';
  #   wantedBy = [ "multi-user.target" ]; # starts after login
  # }

  fonts.fontconfig.enable = true;
}
