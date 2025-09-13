{
  description = "Bootstrap image for Raspberry Pi fleet with discovery service";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }: let
    system = "aarch64-linux";

    # Function to create bootstrap image with custom parameters
    makeBootstrapImage = { discoveryPsk, discoveryServiceIp ? "192.168.1.100", configRepoUrl ? "github:yourusername/nixos-pi-configs" }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit discoveryPsk discoveryServiceIp configRepoUrl;
        };
        modules = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          {
            nixpkgs.pkgs = nixpkgs.legacyPackages.${system};
          }
          ./configuration-updated.nix
          ./hardware-configuration.nix
          ./network-config.nix
        ];
      };

  in {
    # Default configuration (requires PSK to be passed)
    nixosConfigurations.pi-bootstrap = makeBootstrapImage {
      discoveryPsk = "CHANGE_ME_TO_YOUR_PSK";
    };

    # Function to build with custom PSK
    lib.buildBootstrapImage = makeBootstrapImage;

    # Helper for building images
    packages.${system} = {
      default = self.nixosConfigurations.pi-bootstrap.config.system.build.sdImage;

      # Function to build with custom args - usage in shell
      buildWithPsk = nixpkgs.legacyPackages.${system}.writeShellScriptBin "build-bootstrap-image" ''
        set -euo pipefail

        PSK="''${1:-}"
        IP="''${2:-192.168.1.100}"
        REPO="''${3:-github:yourusername/nixos-pi-configs}"

        if [ -z "$PSK" ]; then
          echo "Usage: $0 <PSK> [IP] [REPO_URL]"
          echo "Example: $0 abc123def456 192.168.1.100 github:myuser/my-configs"
          exit 1
        fi

        echo "Building bootstrap image with:"
        echo "  PSK: ''${PSK:0:8}..."
        echo "  Discovery IP: $IP"
        echo "  Config Repo: $REPO"

        nix build .#nixosConfigurations.custom-bootstrap.config.system.build.sdImage \
          --override-input nixpkgs nixpkgs \
          --extra-experimental-features "nix-command flakes" \
          --arg discoveryPsk "\"$PSK\"" \
          --arg discoveryServiceIp "\"$IP\"" \
          --arg configRepoUrl "\"$REPO\""
      '';
    };

    # Custom bootstrap configuration with args
    nixosConfigurations.custom-bootstrap = makeBootstrapImage {
      discoveryPsk = builtins.getEnv "DISCOVERY_PSK";
      discoveryServiceIp = builtins.getEnv "DISCOVERY_SERVICE_IP";
      configRepoUrl = builtins.getEnv "CONFIG_REPO_URL";
    };

    # Development shell with helpers
    devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
      buildInputs = with nixpkgs.legacyPackages.${system}; [
        nixFlakes
        python3
        python3Packages.requests
        python3Packages.cryptography
      ];

      shellHook = ''
        echo "🚀 Bootstrap Image Development Environment"
        echo "========================================"
        echo ""
        echo "Available commands:"
        echo "  build-with-psk <PSK> [IP] [REPO] - Build image with custom parameters"
        echo "  nix run ../discovery-service#generate-psk - Generate new PSK"
        echo ""
        echo "Example usage:"
        echo "  # Generate PSK"
        echo "  python3 ../discovery-service/generate_psk.py"
        echo ""
        echo "  # Build with PSK"
        echo "  build-with-psk abc123def456789 192.168.1.100 github:myuser/my-configs"
        echo ""

        # Make build helper available
        export PATH="${self.packages.${system}.buildWithPsk}/bin:$PATH"
      '';
    };
  };
}
