{
  description = "NixOS Pi-hole";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    {
      nixosConfigurations.pihole1 = nixpkgs.lib.nixosSystem {
        modules = [
          ./host/configuration.nix
          self.nixosModules.nix-hole
          inputs.nixos-hardware.nixosModules.raspberry-pi-4
          inputs.sops-nix.nixosModules.sops
        ];
        specialArgs = {
          inherit inputs;
        };
      };

      nixosModules = {
        default = self.nixosModules.nix-hole;
        nix-hole = ./services;
      };
    };
}
