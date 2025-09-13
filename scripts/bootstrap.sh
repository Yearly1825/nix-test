#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script for initial Raspberry Pi configuration
# This script should be run after flashing NixOS to the SD card

REPO_URL="${1:-https://github.com/yourusername/sensor-config.git}"
SETUP_KEY="${2:-}"
SSH_KEY="${3:-}"

echo "=== NixOS Sensor Bootstrap ==="
echo "Repository: $REPO_URL"

# Function to handle errors
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Update system
echo "Updating package database..."
nix-channel --update || error_exit "Failed to update nix channels"

# Install git if not present
if ! command -v git &> /dev/null; then
    echo "Installing git..."
    nix-env -iA nixos.git || error_exit "Failed to install git"
fi

# Clone configuration repository
echo "Cloning configuration repository..."
cd /tmp
rm -rf sensor-config
git clone "$REPO_URL" sensor-config || error_exit "Failed to clone repository"
cd sensor-config

# Use the minimal hardware configuration if it doesn't exist
if [ ! -f hardware-configuration.nix ]; then
    echo "Generating hardware configuration..."
    nixos-generate-config --show-hardware-config > hardware-configuration.nix 2>/dev/null || {
        echo "Using minimal hardware configuration..."
        cat > hardware-configuration.nix <<'EOF'
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
    initrd.availableKernelModules = [ "xhci_pci" "usbhid" "usb_storage" ];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
  };

  swapDevices = [ ];
  hardware.enableRedistributableFirmware = true;
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
EOF
    }
fi

# Add SSH key if provided
if [ -n "$SSH_KEY" ]; then
    echo "Adding SSH public key..."
    # Escape special characters in SSH key
    ESCAPED_KEY=$(printf '%s\n' "$SSH_KEY" | sed 's/[[\.*^$()+?{|]/\\&/g')
    sed -i "s|# \"ssh-ed25519.*|\"$ESCAPED_KEY\"|" configuration.nix
fi

# Add Netbird setup key if provided
if [ -n "$SETUP_KEY" ]; then
    echo "Configuring Netbird setup key..."
    mkdir -p secrets
    cat > secrets/netbird-setup.nix <<EOF
{ config, ... }:
{
  services.sensorNetbird.setupKey = "$SETUP_KEY";
}
EOF

    # Check if secrets module is already in flake.nix
    if ! grep -q "secrets/netbird-setup.nix" flake.nix; then
        # Add to flake.nix modules
        sed -i '/\.\/modules\/kismet\.nix/a\        ./secrets/netbird-setup.nix' flake.nix
    fi
fi

# Test build first
echo "Testing configuration build..."
nixos-rebuild dry-build --flake .#sensor 2>&1 | tee /tmp/build.log || {
    echo "Build test failed. Checking for common issues..."

    if grep -q "tpm2" /tmp/build.log; then
        echo "TPM2 error detected. Removing hardware module..."
        # Remove nixos-hardware from flake.nix
        sed -i '/nixos-hardware/d' flake.nix
        sed -i 's/nixos-hardware\.nixosModules\.raspberry-pi-4//' flake.nix
        sed -i '/^[[:space:]]*$/d' flake.nix
    fi

    if grep -q "raspberry-pi.*4.*enable" /tmp/build.log; then
        echo "Removing Raspberry Pi 4 specific options..."
        sed -i '/hardware\.raspberry-pi\."4"/,/};/d' hardware-configuration.nix
    fi

    echo "Retrying build..."
    nixos-rebuild dry-build --flake .#sensor || error_exit "Build failed after fixes"
}

# Build and switch to new configuration
echo "Building system configuration..."
nixos-rebuild switch --flake .#sensor || error_exit "Failed to switch configuration"

echo "=== Bootstrap Complete ==="
echo "System configured successfully!"
echo ""
echo "Next steps:"
echo "1. Reboot the system: sudo reboot"
echo "2. Connect via SSH: ssh sensor@<ip-address>"
echo "3. Access Kismet web UI: http://<ip-address>:2501"
echo "4. Check Netbird status: sudo systemctl status netbird"
