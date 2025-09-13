#!/usr/bin/env bash
set -euo pipefail

# Update script for pulling latest configuration from Git

REPO_DIR="${1:-/etc/nixos}"

echo "=== Updating Sensor Configuration ==="

cd "$REPO_DIR"

# Stash any local changes
git stash

# Pull latest changes
echo "Pulling latest configuration..."
git pull origin main

# Apply stashed changes if any
if git stash list | grep -q "stash@{0}"; then
    echo "Applying local changes..."
    git stash pop || true
fi

# Rebuild system
echo "Rebuilding NixOS configuration..."
nixos-rebuild switch --flake .#sensor

echo "=== Update Complete ==="
echo "System updated successfully!"

# Show service status
echo ""
echo "Service Status:"
systemctl status sshd --no-pager | head -n 3
systemctl status netbird --no-pager | head -n 3
systemctl status kismet --no-pager | head -n 3 || echo "Kismet not running"