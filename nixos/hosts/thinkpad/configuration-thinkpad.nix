{ config, pkgs, ... }:
{

  imports = [
    ./hardware-configuration.nix
    ../../default.nix
    #./nvidia.nix
    ./blacklist_nvidia.nix
    ../../services/sunshine.nix
  ];
  #Hostname
  networking.hostName = "mir-nixos-thinkpad"; # Define your hostname.

  #Mount Windows file system
  boot.supportedFilesystems = [ "ntfs" ];
  fileSystems."/mnt/2TB" = {
    device = "/dev/disk/by-label/windows";
    fsType = "ntfs-3g";
    options = [
      "rw"
      "uid=1000"
    ];
  };

  #Mount Data file system
  fileSystems."/data" = {
    device = "/dev/disk/by-label/data";
    fsType = "ext4";
    options = [
      "rw"
      "users"
      "nofail"
      "auto"
    ];
  };

}
