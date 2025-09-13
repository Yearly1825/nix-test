{
  description = "Bootstrap image for Raspberry Pi fleet";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      pi-bootstrap = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          # Import the SD image builder for ARM64
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          
          # Your custom configuration
          ./configuration.nix
          ./hardware-configuration.nix
          ./network-config.nix
        ];
      };
    };
    
    # Convenience attribute for building
    images.pi-bootstrap = 
      self.nixosConfigurations.pi-bootstrap.config.system.build.sdImage;
  };
}