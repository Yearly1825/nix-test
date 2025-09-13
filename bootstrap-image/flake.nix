{
  description = "Bootstrap image for Raspberry Pi fleet";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = { self, nixpkgs }: let
    system = "aarch64-linux";
    piConfig = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        {
          nixpkgs.pkgs = nixpkgs.legacyPackages.${system};
        }
        ./configuration.nix
        ./hardware-configuration.nix
        ./network-config.nix
      ];
    };
  in {
    nixosConfigurations.pi-bootstrap = piConfig;
    images.pi-bootstrap = piConfig.config.system.build.sdImage;
  };
}
