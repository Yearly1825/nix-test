# Bootstrap Image Builder

Builds NixOS SD card images for Raspberry Pi with integrated discovery service support.

## Quick Start

Use the unified configuration system for streamlined builds:

```bash
# 1. Configure deployment (if not done already)
cd .. && python3 setup_deployment.py

# 2. Build image (reads config automatically)
cd bootstrap-image && ./build.sh
```

**✅ Benefits:** No parameters needed, NTFY testing, shared configuration



## Cross-Platform Building

The build script automatically detects your platform and handles cross-compilation from x86_64 to aarch64 (Raspberry Pi). No manual configuration needed.

### CachyOS Prerequisites and Setup

**First-time CachyOS users:** You need to install Nix before building:

```bash
# Install Nix (required for building NixOS images)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Configure Nix for cross-compilation
mkdir -p ~/.config/nix
cat >> ~/.config/nix/nix.conf << 'EOF'
experimental-features = nix-command flakes
extra-platforms = aarch64-linux
max-jobs = auto
cores = 0
EOF

# Add yourself as trusted user (CRITICAL)
echo "trusted-users = root $USER" | sudo tee -a /etc/nix/nix.conf

# Restart daemon and reload shell
sudo systemctl restart nix-daemon
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

**See: [Complete CachyOS Setup Guide](../docs/cachyos-setup.md)**

The build script automatically detects CachyOS and adds stability flags (`--option sandbox false --max-jobs 1`).

## Requirements

### Hardware Requirements
- **Ethernet connection** - Required for bootstrap process
- WiFi is disabled during bootstrap for security and reliability
- SD card (16GB+ recommended)
- Raspberry Pi 4 (2GB+ RAM recommended)

### Network Requirements
- DHCP-enabled ethernet network
- Internet access for downloading packages
- Access to discovery service IP

## Configuration

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `DISCOVERY_PSK` | 64-character hex PSK | `abc123def456...` |
| `DISCOVERY_SERVICE_IP` | Discovery service IP | `192.168.1.100` |
| `CONFIG_REPO_URL` | Your NixOS config repo | `github:user/configs` |

### Build Script Options

```bash
./build.sh [OPTIONS]

Options:
  --ntfy-test          Test NTFY notifications before building
  -o, --output <DIR>   Output directory (default: ./result)
  -h, --help           Show help
```



## Development Workflow

### 1. Configure Deployment
```bash
cd .. && python3 setup_deployment.py
```

### 2. Build Image
```bash
./build.sh
```

### 3. Flash Image
```bash
# Find your SD card device
lsblk

# Flash (replace sdX with your device)
sudo dd if=result/nixos-sd-image-*.img of=/dev/sdX bs=4M status=progress sync
```

### 4. Boot and Monitor
```bash
# Start discovery service
cd ../discovery-service
docker-compose up -d

# Boot Raspberry Pi with ETHERNET CONNECTED
# WiFi is disabled during bootstrap - ethernet is required

# Monitor logs
docker-compose logs -f discovery-service
```

## Troubleshooting

### Quick Diagnosis

**Error: "nix: command not found"**
- Install Nix: See [CachyOS Setup Guide](../docs/cachyos-setup.md)

**Error: "system aarch64-linux not supported"**  
- Add trusted user: `echo "trusted-users = root $USER" | sudo tee -a /etc/nix/nix.conf`
- Restart daemon: `sudo systemctl restart nix-daemon`

**Error: Configuration not found**
- Run unified setup: `cd .. && python3 setup_deployment.py`

### Comprehensive Guides

For detailed troubleshooting, see:
- **[CachyOS Setup Guide](../docs/cachyos-setup.md)** - Prerequisites and initial setup
- **[Bootstrap Troubleshooting](../docs/bootstrap-troubleshooting.md)** - CachyOS-specific build issues  
- **[Bootstrap Walkthrough](../docs/bootstrap-walkthrough.md)** - Step-by-step resolution guide

### Quick Fixes

**Build fails on CachyOS:** The build script automatically adds stability flags (`--option sandbox false --max-jobs 1`)

**Configuration issues:** Use unified configuration:
```bash
cd .. && python3 setup_deployment.py
```

**Cross-compilation issues:** Build script automatically detects and adds required flags

## Security Considerations

⚠️ **Important:** The built image contains your PSK embedded in the filesystem.

**Best Practices:**
- Generate unique PSK per deployment  
- Limit physical access to SD cards
- Rotate PSKs periodically
- Don't share built images

## Advanced Usage

### Custom Output Location
```bash
./build.sh -o custom-image
```

### Debug Build
```bash
# Add --show-trace to build.sh for detailed output
nix build .#bootstrap-image --show-trace --verbose
```

## Files Overview

| File | Purpose |
|------|---------|
| `flake.nix` | NixOS image definition with parameter injection |
| `configuration.nix` | Bootstrap system configuration |
| `build.sh` | Unified build script |
| `README.md` | This documentation |

## Next Steps

After building your image:

1. **Flash to SD card** using `dd` or similar tool
2. **Boot Pi** with ethernet connection  
3. **Monitor discovery service** for device registration
4. **Verify bootstrap** completion via logs or NTFY

For the main sensor configuration, see the [main README](../README.md) for flake target setup requirements.