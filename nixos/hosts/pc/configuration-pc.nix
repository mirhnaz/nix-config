{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../default.nix
    ../../services/sunshine.nix
  ];

  networking.hostName = "mir-nixos-pc";
  networking.interfaces = {
    enp7s0.wakeOnLan.enable = true;
    tailscale0.wakeOnLan.enable = true;
  };

  # services.vscode-server.enable = true;

}
