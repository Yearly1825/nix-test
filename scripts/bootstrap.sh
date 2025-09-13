#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script for initial Raspberry Pi configuration
# This script should be run after flashing NixOS to the SD card

REPO_URL="${1:-https://github.com/yearly1825/nix-test.git}"
SETUP_KEY="${2:-}"
SSH_KEY="${3:-ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM9FIqbH/3WrkR++YRAB5/o95uwBEhmNsyG+LmNObi+T}"

echo "=== NixOS Sensor Bootstrap ==="
echo "Repository: $REPO_URL"

# Update system
echo "Updating package database..."
nix-channel --update

# Install git if not present
if ! command -v git &> /dev/null; then
    echo "Installing git..."
    nix-env -iA nixos.git
fi

# Clone configuration repository
echo "Cloning configuration repository..."
cd /tmp
rm -rf sensor-config
git clone "$REPO_URL" sensor-config
cd sensor-config

# Add SSH key if provided
if [ -n "$SSH_KEY" ]; then
    echo "Adding SSH public key..."
    mkdir -p /tmp/ssh-keys
    echo "$SSH_KEY" > /tmp/ssh-keys/authorized_keys

    # Update configuration with SSH key
    sed -i "s|# \"ssh-ed25519.*|\"$SSH_KEY\"|" configuration.nix
fi

# Add Netbird setup key if provided
if [ -n "$SETUP_KEY" ]; then
    echo "Configuring Netbird setup key..."
    cat > secrets/netbird-setup.nix <<EOF
{ config, ... }:
{
  services.sensorNetbird.setupKey = "$SETUP_KEY";
}
EOF

    # Add to flake.nix modules
    sed -i '/\.\/modules\/kismet\.nix/a\        ./secrets/netbird-setup.nix' flake.nix
fi

# Copy hardware configuration from current system
echo "Copying hardware configuration..."
cp /etc/nixos/hardware-configuration.nix ./hardware-configuration.nix

# Build and switch to new configuration
echo "Building system configuration..."
nixos-rebuild switch --flake .#sensor

echo "=== Bootstrap Complete ==="
echo "System configured successfully!"
echo ""
echo "Next steps:"
echo "1. Reboot the system: sudo reboot"
echo "2. Connect via SSH: ssh sensor@<ip-address>"
echo "3. Access Kismet web UI: http://<ip-address>:2501"
echo "4. Check Netbird status: sudo systemctl status netbird"
