{
  description = "Bootstrap image for Raspberry Pi fleet";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      pi-bootstrap = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          # Use the explicit nixpkgs input path for SD image
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          # Ensure pure evaluation by setting nixpkgs.pkgs
          {
            nixpkgs.pkgs = nixpkgs.legacyPackages.aarch64-linux;
          }
          ./configuration.nix
          ./hardware-configuration.nix
          ./network-config.nix
        ];
      };
    };
    images.pi-bootstrap =
      self.nixosConfigurations.pi-bootstrap.config.system.build.sdImage;
  };
}
