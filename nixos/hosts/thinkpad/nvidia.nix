{ config, pkgs, ... }: {
  #nvidia Enable opengl

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
    nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.stable;

      modesetting.enable = true;

      powerManagement.enable = true;
      powerManagement.finegrained = false;

      nvidiaSettings = true;
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        # sync.enable = true;
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };

  # specialisation = {
  #   nvidiaBeta.configuration = {
  #     hardware.nvidia = {
  #       package = config.boot.kernelPackages.nvidiaPackages.beta;
  #       modesetting.enable = true;
  #       powerManagement.enable = true;
  #       powerManagement.finegrained = false;
  #       open = false;
  #       nvidiaSettings = true;
  #       prime = {
  #         offload = {
  #           enable = true;
  #           enableOffloadCmd = true;
  #         };
  #         # sync.enable = true;
  #         intelBusId = "PCI:0:2:0";
  #         nvidiaBusId = "PCI:1:0:0";
  #       };
  #     };
  #     environment.etc."specialisation".text = "nvidiaBeta";
  #   };

  #   nvidiaStable.configuration = {
  #     hardware.nvidia = {
  #       package = config.boot.kernelPackages.nvidiaPackages.stable;
  #       modesetting.enable = true;
  #       powerManagement.enable = true;
  #       powerManagement.finegrained = false;
  #       open = false;
  #       nvidiaSettings = true;
  #       prime = {
  #         offload = {
  #           enable = true;
  #           enableOffloadCmd = true;
  #         };
  #         # sync.enable = true;
  #         intelBusId = "PCI:0:2:0";
  #         nvidiaBusId = "PCI:1:0:0";
  #       };
  #     };
  #     environment.etc."specialisation".text = "nvidiaStable";
  #   };
  # };
}
