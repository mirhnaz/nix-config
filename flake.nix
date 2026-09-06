{
  description = "Naz Mir's NixOS + Home Manager config (NixOS, macOS, Pop!_OS, Omarchy)";

  inputs = {
    # Nixpkgspkgs.nixVersions.unstable
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";

    # lanzaboote = {
    #   url = "github:nix-community/lanzaboote/v0.4.1";
    #   # Optional but recommended to limit the size of your system closure.
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # nix-colors.url = "github:misterio77/nix-colors";
    # nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
    # vscode-server.url = "github:nix-community/nixos-vscode-server";

  };

  outputs =
    { nixpkgs, home-manager, ... }@inputs:

    {
      # `nix fmt` formats the whole tree (nixfmt via treefmt); CI runs
      # `nix fmt -- --ci`, which fails on any drift.
      formatter = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-darwin" ] (
        system: nixpkgs.legacyPackages.${system}.nixfmt-tree
      );

      nixosConfigurations = {

        mir-nixos-thinkpad = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; }; # Pass flake inputs to our config
          # > Our main nixos configuration file <
          modules = [ ./nixos/hosts/thinkpad/configuration-thinkpad.nix ];
        };

        mir-nixos-pc = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; }; # Pass flake inputs to our config
          # > Our main nixos configuration file <
          modules = [
            ./nixos/hosts/pc/configuration-pc.nix
          ];
        };

      };

      homeConfigurations = {
        "mir@mir-nixos-thinkpad" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."x86_64-linux"; # Home-manager requires 'pkgs' instance
          extraSpecialArgs = { inherit inputs; }; # Pass flake inputs to our config
          modules = [
            ./home-manager/hosts/home-nixos.nix
          ];
        };

        "mir@mir-nixos-pc" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."x86_64-linux"; # Home-manager requires 'pkgs' instance
          extraSpecialArgs = { inherit inputs; }; # Pass flake inputs to our config
          modules = [
            ./home-manager/hosts/home-nixos.nix
          ];
        };

        "mir@mir-popos-thinkpad" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."x86_64-linux"; # Home-manager requires 'pkgs' instance
          extraSpecialArgs = { inherit inputs; }; # Pass flake inputs to our config
          modules = [
            ./home-manager/hosts/home-popos.nix
          ];
        };

        "mir@mir-omarchy-pc" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."x86_64-linux"; # Home-manager requires 'pkgs' instance
          extraSpecialArgs = { inherit inputs; }; # Pass flake inputs to our config
          modules = [
            ./home-manager/hosts/home-omarchy.nix
          ];
        };

        "mir@mir-m4pro-mbp" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."aarch64-darwin"; # Home-manager requires 'pkgs' instance
          extraSpecialArgs = {
            inherit inputs; # Pass flake inputs to our config
            username = "mir";
            homeDirectory = "/Users/mir";
          };
          modules = [ ./home-manager/hosts/home-mac.nix ];
        };

        "nazishhussainmir@K-H-2005735-M" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."aarch64-darwin"; # Home-manager requires 'pkgs' instance
          extraSpecialArgs = {
            inherit inputs; # Pass flake inputs to our config
            username = "nazishhussainmir";
            homeDirectory = "/Users/nazishhussainmir";
          };
          modules = [ ./home-manager/hosts/home-mac.nix ];
        };

      };
    };
}
