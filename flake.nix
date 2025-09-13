{
  description = "Raspberry Pi 4 Sensor System";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations.sensor = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./hardware-configuration.nix
        ./configuration.nix
        ./modules/ssh.nix
        ./modules/netbird.nix
        ./modules/kismet.nix
      ];
    };
  };
}
