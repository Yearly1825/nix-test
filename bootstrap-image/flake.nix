{
  description = "Bootstrap image for Raspberry Pi fleet";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = { self, nixpkgs }: let
    system = "aarch64-linux";
    # Explicitly pass nixpkgs to avoid <nixpkgs> lookups
    piConfig = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        {
          nixpkgs.pkgs = nixpkgs.legacyPackages.${system};
          # Optional: Set Raspberry Pi-specific kernel (adjust for your model)
          boot.kernelPackages = nixpkgs.legacyPackages.${system}.linuxPackages_rpi4;
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
