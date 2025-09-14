{
  description = "NixOS Raspberry Pi Sensor Configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }: let
    system = "aarch64-linux";

    # Base configuration shared by all profiles
    baseModules = [
      ./hardware-configuration.nix
    ];

    # Function to create a sensor configuration with a specific profile
    mkSensorConfig = profile: nixpkgs.lib.nixosSystem {
      inherit system;
      modules = baseModules ++ [ profile ];
    };

  in {
    # Available sensor configurations
    nixosConfigurations = {
      # Full sensor stack (recommended for most deployments)
      full-sensor = mkSensorConfig ./profiles/full-sensor.nix;

      # Lightweight wireless monitoring
      wireless-monitor = mkSensorConfig ./profiles/wireless-monitor.nix;

      # Minimal configuration for basic connectivity
      minimal = mkSensorConfig ./profiles/minimal.nix;

      # Default configuration (points to full-sensor)
      default = self.nixosConfigurations.full-sensor;
    };

    # Convenience attributes for direct building
    packages.${system} = {
      full-sensor = self.nixosConfigurations.full-sensor.config.system.build.toplevel;
      wireless-monitor = self.nixosConfigurations.wireless-monitor.config.system.build.toplevel;
      minimal = self.nixosConfigurations.minimal.config.system.build.toplevel;
      default = self.packages.${system}.full-sensor;
    };

    # Development shell for testing configurations
    devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
      buildInputs = with nixpkgs.legacyPackages.${system}; [
        nixFlakes
        git
        curl
      ];

      shellHook = ''
        echo "🚀 Sensor Configuration Development Environment"
        echo "=============================================="
        echo ""
        echo "Available configurations:"
        echo "  • full-sensor      - Complete monitoring stack"
        echo "  • wireless-monitor - Wireless monitoring only"
        echo "  • minimal          - Basic connectivity"
        echo ""
        echo "Commands:"
        echo "  nix build .#full-sensor      - Build full sensor config"
        echo "  nixos-rebuild test --flake .#wireless-monitor"
        echo ""
      '';
    };
  };
}
