{config, pkgs, inputs, ... }:

{

  imports = [
      ../common.nix
      ../common-linux.nix
      ../services.nix
  ];

  home.username = "mir";
  home.homeDirectory = "/home/mir";
  home.stateVersion = "23.05"; # Please read the comment before changing.

  home.packages = with pkgs; [
   #inputs.nixgl.packages.x86_64-linux.nixGLIntel
  ];

  # Ghostty config comes from ../ghostty.nix, but on a foreign distro the
  # nix-built GUI app would need nixGL — install ghostty via the distro
  # instead; HM only writes the config.
  programs.ghostty.package = null;
  programs.ghostty.systemd.enable = false;

}
