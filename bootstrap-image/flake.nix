{
  description = "Bootstrap image for Raspberry Pi fleet with discovery service";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";  # Use 25.11 like working config
  };

  outputs = { self, nixpkgs }: let
    # Default values
    defaultPsk = builtins.getEnv "DISCOVERY_PSK";
    defaultIp = if builtins.getEnv "DISCOVERY_SERVICE_IP" != "" then builtins.getEnv "DISCOVERY_SERVICE_IP" else "10.42.0.1";
    defaultRepo = if builtins.getEnv "CONFIG_REPO_URL" != "" then builtins.getEnv "CONFIG_REPO_URL" else "github:yearly1825/nixos-pi-configs";
    # Support multiple host architectures for cross-compilation
    supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
    targetSystem = "aarch64-linux";  # Always build for Raspberry Pi

    # Helper function to generate packages for each supported system
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    # Function to create bootstrap image with custom parameters
    makeBootstrapImage = { discoveryPsk, discoveryServiceIp ? "192.168.1.100", configRepoUrl ? "github:yourusername/nixos-pi-configs" }:
      nixpkgs.lib.nixosSystem {
        system = targetSystem;
        specialArgs = {
          inherit discoveryPsk discoveryServiceIp configRepoUrl;
        };
        modules = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          {
            nixpkgs.pkgs = nixpkgs.legacyPackages.${targetSystem};
          }
          ./configuration.nix
          ./hardware-configuration.nix
          ./network-config.nix
        ];
      };

  in {
    # Default configuration (requires PSK to be passed)
    nixosConfigurations.pi-bootstrap = makeBootstrapImage {
      discoveryPsk = "CHANGE_ME_TO_YOUR_PSK";
    };

    # Environment variable-based configuration for transparent builds
    nixosConfigurations.custom-bootstrap = makeBootstrapImage {
      discoveryPsk = defaultPsk;
      discoveryServiceIp = defaultIp;
      configRepoUrl = defaultRepo;
    };

    # Function to build with custom PSK (programmatic access)
    lib.buildBootstrapImage = makeBootstrapImage;

    # Packages for all supported host systems (enables cross-compilation)
    packages = forAllSystems (hostSystem: {
      # Default image (uses custom-bootstrap with env vars)
      default = self.nixosConfigurations.custom-bootstrap.config.system.build.sdImage;

      # Direct access to image
      bootstrap-image = self.nixosConfigurations.custom-bootstrap.config.system.build.sdImage;

      # Build helper script (available on all host systems)
      build-script = nixpkgs.legacyPackages.${hostSystem}.writeShellScriptBin "build-bootstrap" ''
        set -euo pipefail

        # Platform detection for cross-compilation
        HOST_ARCH=$(uname -m)
        CROSS_ARGS=""

        case "$HOST_ARCH" in
          x86_64)
            echo "🔄 Cross-compiling from x86_64 to aarch64"
            CROSS_ARGS="--system aarch64-linux --extra-platforms aarch64-linux"
            ;;
          aarch64|arm64)
            echo "🏠 Native build on aarch64"
            ;;
          *)
            echo "⚠️  Unknown architecture: $HOST_ARCH, attempting cross-compilation"
            CROSS_ARGS="--system aarch64-linux --extra-platforms aarch64-linux"
            ;;
        esac

        # Detect CachyOS and add stability flags
        if [ -f /etc/os-release ] && grep -q "CachyOS" /etc/os-release; then
          echo "🐧 CachyOS detected, adding stability flags"
          CROSS_ARGS="$CROSS_ARGS --option sandbox false --max-jobs 1"
        fi

        echo "📦 Building with args: $CROSS_ARGS"
        nix build .#bootstrap-image $CROSS_ARGS --show-trace "$@"
      '';
    });

    # Development shells for all supported systems
    devShells = forAllSystems (hostSystem: nixpkgs.legacyPackages.${hostSystem}.mkShell {
      buildInputs = with nixpkgs.legacyPackages.${hostSystem}; [
        nixFlakes
        python3
        python3Packages.requests
        python3Packages.cryptography
      ];

      shellHook = ''
        echo "🚀 Bootstrap Image Development Environment"
        echo "========================================"
        echo "Host System: ${hostSystem}"
        echo "Target System: ${targetSystem}"
        echo ""
        echo "📋 Available build methods:"
        echo ""
        echo "1️⃣  Build Script (recommended):"
        echo "   ./build-image.sh -p <psk>"
        echo ""
        echo "2️⃣  Direct Nix (full transparency):"
        echo "   export DISCOVERY_PSK=<psk>"
        echo "   nix run .#packages.${hostSystem}.build-script"
        echo ""
        echo "3️⃣  Manual Nix (complete control):"
        echo "   nix build .#bootstrap-image --system aarch64-linux --extra-platforms aarch64-linux"
        echo ""
        echo "🔧 Cross-compilation will be handled automatically based on your platform."
        echo ""
      '';
    });
  };
}
