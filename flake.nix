{
  description = "Raspberry Pi 4 Sensor System";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { self, nixpkgs, nixos-hardware }: {
    nixosConfigurations.sensor = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        nixos-hardware.nixosModules.raspberry-pi-4
        ./hardware-configuration.nix
        ./configuration.nix
        ./modules/ssh.nix
        ./modules/netbird.nix
        ./modules/kismet.nix
      ];
    };
  };
}