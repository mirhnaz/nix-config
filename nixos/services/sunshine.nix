{ ... }:

{
  # Sunshine game-stream host (pair with Moonlight). The nixpkgs module
  # handles the uinput kernel module + udev rules, the cap_sys_admin
  # wrapper (needed for KMS capture) and the firewall ports.
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };
}
