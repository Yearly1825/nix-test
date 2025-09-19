# Prerequisites for Building Bootstrap Images

This guide walks through setting up a fresh CachyOS system to build NixOS bootstrap images for Raspberry Pi sensors.

## Overview

You encountered this error because Nix is not installed:
```bash
./build.sh: line 252: nix: command not found
```

This document provides step-by-step instructions to get your CachyOS system ready for building.

## Quick Setup (TL;DR)

### For Bash/Zsh:
```bash
# 1. Install Nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2. Restart shell or source profile
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# 3. Configure cross-compilation
mkdir -p ~/.config/nix
cat > ~/.config/nix/nix.conf << 'EOF'
experimental-features = nix-command flakes
extra-platforms = aarch64-linux
max-jobs = auto
cores = 0
EOF

# 4. Add trusted user (CRITICAL STEP)
echo "trusted-users = root $USER" | sudo tee -a /etc/nix/nix.conf

# 5. Restart nix daemon
sudo systemctl restart nix-daemon

# 6. Install dependencies
paru -S --needed python-yaml  # or: sudo pacman -S python-yaml

# 7. Test installation
nix --version

# 8. Build your image
cd nix-sensor/bootstrap-image
./build.sh
```

### For Fish Shell:
```fish
# 1. Install Nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2. Restart shell or source profile
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# 3. Configure cross-compilation
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' > ~/.config/nix/nix.conf
echo 'extra-platforms = aarch64-linux' >> ~/.config/nix/nix.conf
echo 'max-jobs = auto' >> ~/.config/nix/nix.conf
echo 'cores = 0' >> ~/.config/nix/nix.conf

# 4. Add trusted user (CRITICAL STEP)
echo "trusted-users = root $USER" | sudo tee -a /etc/nix/nix.conf

# 5. Restart nix daemon
sudo systemctl restart nix-daemon

# 6. Install dependencies
paru -S --needed python-yaml

# 7. Test installation
nix --version; and python3 -c "import yaml; print('Ready to build!')"

# 8. Build your image
cd nix-sensor/bootstrap-image
./build.sh
```

## Detailed Setup Instructions

### Step 1: Install Nix Package Manager

CachyOS doesn't include Nix by default. Install the **Determinate Nix Installer** (recommended for Arch-based systems):

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

**Why this installer?**
- Better support for systemd-based distros like CachyOS
- Handles SELinux/AppArmor automatically
- Configures multi-user setup properly
- Includes flakes support by default

**Alternative: Official installer** (if you prefer):
```bash
curl -L https://nixos.org/nix/install | sh -s -- --daemon
```

### Step 2: Restart Shell or Source Profile

After installation, either:

**Option A: Restart your terminal/shell**
```bash
# Close and reopen your terminal
```

**Option B: Source the Nix profile**
```bash
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### Step 3: Configure Nix for Cross-Compilation

Create Nix configuration directory and enable required features:

```bash
# Create config directory
mkdir -p ~/.config/nix

# Enable flakes and cross-compilation
cat >> ~/.config/nix/nix.conf << EOF
experimental-features = nix-command flakes
extra-platforms = aarch64-linux
extra-sandbox-paths = /usr/bin/env /bin/sh
max-jobs = auto
EOF
```

**What these settings do:**
- `experimental-features`: Enables modern Nix commands and flakes
- `extra-platforms`: Allows building for Raspberry Pi (aarch64)
- `extra-sandbox-paths`: CachyOS compatibility
- `max-jobs`: Use all CPU cores for faster builds

### Step 4: CachyOS-Specific Configurations

CachyOS may need additional tweaks for optimal Nix performance:

```bash
# Add Nix to your PATH permanently
echo 'export PATH=/nix/var/nix/profiles/default/bin:$PATH' >> ~/.bashrc

# If using zsh:
echo 'export PATH=/nix/var/nix/profiles/default/bin:$PATH' >> ~/.zshrc

# Create systemd user service for nix-daemon (if not created automatically)
sudo systemctl enable nix-daemon.service
sudo systemctl start nix-daemon.service
```

### Step 5: Install Additional Dependencies

While Nix will handle most dependencies, ensure you have these system packages:

```bash
# Using paru (as you mentioned)
paru -S --needed \
    curl \
    git \
    python \
    python-pip \
    python-yaml

# Or using pacman
sudo pacman -S --needed \
    curl \
    git \
    python \
    python-pip \
    python-yaml
```

### Step 6: Verify Installation

Test that everything is working:

```bash
# Check Nix version
nix --version

# Test flakes support
nix flake --help

# Test cross-compilation support
nix eval --expr 'builtins.currentSystem'

# Test that aarch64 platform is available
nix eval --expr 'builtins.hasAttr "aarch64-linux" (import <nixpkgs> {}).lib.systems.examples'
```

**Expected output:**
```bash
$ nix --version
nix (Nix) 2.18.1

$ nix eval --expr 'builtins.currentSystem'
"x86_64-linux"
```

### Step 7: Test Build Process

Now test the bootstrap image build:

```bash
# Navigate to bootstrap directory
cd nix-sensor/bootstrap-image

# Check if deployment config exists
ls -la ../.deployment.yaml

# If it doesn't exist, set it up
if [ ! -f "../.deployment.yaml" ]; then
    echo "Setting up deployment configuration..."
    cd .. && python3 setup_deployment.py
    cd bootstrap-image
fi

# Run the build script
./build.sh
```

## Troubleshooting Common Issues

### Issue: "nix: command not found" after installation

**Solution:**
```bash
# Make sure nix-daemon is running
sudo systemctl status nix-daemon

# Restart the daemon if needed
sudo systemctl restart nix-daemon

# Source the profile again
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### Issue: "system 'aarch64-linux' is not supported"

**Solution:**
```bash
# Check your nix.conf
cat ~/.config/nix/nix.conf

# Should contain:
# extra-platforms = aarch64-linux

# If missing, add it:
echo "extra-platforms = aarch64-linux" >> ~/.config/nix/nix.conf
```

### Issue: Build fails with sandbox errors

**Solution:**
```bash
# CachyOS may need sandbox disabled for some builds
# This is automatically handled by build.sh, but if you're using direct nix commands:
nix build --option sandbox false .#bootstrap-image
```

### Issue: Out of disk space during build

**Solution:**
```bash
# Check available space
df -h

# Nix store can get large. Clean old generations:
nix-collect-garbage -d

# Check nix store size
du -sh /nix/store
```

### Issue: Network timeouts during build

**Solution:**
```bash
# Add more timeout and retry options
nix build .#bootstrap-image \
  --option connect-timeout 60 \
  --option stalled-download-timeout 300 \
  --option download-attempts 3
```

## Performance Optimization for CachyOS

### Use CachyOS's Performance Features

```bash
# CachyOS has optimized kernels - make sure you're using one
uname -r  # Should show cachyos kernel

# Enable performance governor (if not already)
sudo cpupower frequency-set -g performance

# Check CPU governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

### Optimize Nix for CachyOS

```bash
# Add CachyOS-optimized settings to nix.conf
cat >> ~/.config/nix/nix.conf << EOF
# CachyOS optimizations
cores = 0  # Use all cores
max-jobs = auto  # Auto-detect job count
keep-outputs = true  # Keep build outputs
keep-derivations = true  # Keep derivations for faster rebuilds

# Binary cache settings
substituters = https://cache.nixos.org/ https://nix-community.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
EOF
```

### Monitor Build Progress

```bash
# Monitor CPU usage during build
htop

# Monitor disk I/O
iotop

# Monitor network usage (when downloading packages)
nethogs
```

## Next Steps

After completing setup:

1. **Test the build process**:
   ```bash
   cd nix-sensor/bootstrap-image
   ./build.sh
   ```

2. **Expected build time**: 15-30 minutes for first build (depending on CPU and network)

3. **Expected output**: SD card image in `./result/sd-image/`

4. **Verify output**:
   ```bash
   ls -la result/sd-image/
   # Should show: nixos-sd-image-*.img or *.img.zst
   ```

## Build Environment Summary

After setup, your CachyOS system will have:

- ✅ Nix package manager with flakes support
- ✅ Cross-compilation support (x86_64 → aarch64)
- ✅ CachyOS-specific optimizations
- ✅ Binary cache access for faster builds
- ✅ All required Python dependencies

## References

- [Determinate Nix Installer](https://github.com/DeterminateSystems/nix-installer)
- [Nix Manual - Cross-compilation](https://nixos.org/manual/nixpkgs/stable/#chap-cross)
- [CachyOS Documentation](https://wiki.cachyos.org/)
- [NixOS on Non-NixOS](https://nixos.org/manual/nix/stable/installation/installing-binary.html)

## Quick Reference Card

```bash
# Check installation
nix --version
nix flake --help

# Build bootstrap image
cd nix-sensor/bootstrap-image
./build.sh

# Clean up space
nix-collect-garbage -d

# Update nix
sudo nix upgrade-nix
```