# Bootstrap Image Builder

Builds NixOS SD card images for Raspberry Pi with integrated discovery service support.

## Quick Start

### 🎯 **Unified Configuration (Recommended)**

Use the simplified build process with shared configuration:

```bash
# 1. Configure deployment (if not done already)
cd .. && python3 setup_deployment.py

# 2. Build image (reads config automatically)
cd bootstrap-image && ./build.sh
```

**✅ Benefits:** No parameters needed, NTFY testing, shared configuration

### 📋 **Legacy Methods (Alternative)**

#### Method 1: Parameter-based Build Script

```bash
# Generate PSK
python3 ../discovery-service/generate_psk.py

# Build image
./build-image.sh -p <your-64-char-psk>
```

#### Method 2: Direct Nix Commands

```bash
# Set your parameters
export DISCOVERY_PSK="your-64-char-hex-psk"
export DISCOVERY_SERVICE_IP="192.168.1.100" 
export CONFIG_REPO_URL="github:yourusername/nixos-pi-configs"

# Build directly with nix
nix build .#bootstrap-image --show-trace
```

## Build Methods Comparison

| Method | Pros | Cons | Best For |
|--------|------|------|----------|
| **Build Script** | Parameter validation, cross-platform detection, user-friendly | Less transparent, script dependency | First-time users, development |
| **Direct Nix** | Full transparency, easy CI/CD integration, no hidden logic | Manual parameter handling, platform detection | CI/CD, advanced users |
| **Flake Helpers** | Automatic platform detection, transparent, consistent | Requires understanding of flake structure | Power users, automation |

📖 **For complete transparency, see [Bootstrap Commands](../docs/bootstrap-commands.md) for all direct build commands.**

## Cross-Platform Building

### From x86_64 (CachyOS, most desktops) → aarch64 (Raspberry Pi)

**Using Build Script:**
```bash
./build-image.sh -p <psk>  # Automatically detects cross-compilation
```

**Using Direct Nix Commands:**
```bash
# Set environment variables first
export DISCOVERY_PSK="your-psk"
export DISCOVERY_SERVICE_IP="192.168.1.100"

# Required arguments for cross-compilation
nix build .#bootstrap-image \
  --system aarch64-linux \
  --extra-platforms aarch64-linux \
  --show-trace
```

### CachyOS Specific Issues

If you encounter sandbox or build issues on CachyOS:

```bash
nix build .#bootstrap-image \
  --system aarch64-linux \
  --extra-platforms aarch64-linux \
  --option sandbox false \
  --max-jobs 1 \
  --show-trace
```

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
./build-image.sh [OPTIONS]

Options:
  -p, --psk <PSK>      Discovery service PSK (required)
  -i, --ip <IP>        Discovery service IP (default: 192.168.1.100)
  -r, --repo <REPO>    Config repository URL
  -o, --output <DIR>   Output directory (default: ./result)
  -h, --help           Show help
```

## Direct Nix Commands Reference

### Environment Variable Method

```bash
# Set parameters
export DISCOVERY_PSK="your-psk"
export DISCOVERY_SERVICE_IP="192.168.1.100"
export CONFIG_REPO_URL="github:user/repo"

# Native build (aarch64 host)
nix build .#bootstrap-image

# Cross-compilation (x86_64 → aarch64)  
nix build .#bootstrap-image \
  --system aarch64-linux \
  --extra-platforms aarch64-linux
```

### Inline Parameter Method

```bash
# Build with inline parameters
nix build --expr '
let
  flake = builtins.getFlake (toString ./.);
in
(flake.lib.buildBootstrapImage {
  discoveryPsk = "your-psk";
  discoveryServiceIp = "192.168.1.100"; 
  configRepoUrl = "github:user/repo";
}).config.system.build.sdImage' \
--system aarch64-linux \
--extra-platforms aarch64-linux
```

### Using Nix with Arguments

```bash
nix build .#packages.aarch64-linux.default \
  --override-input discoveryPsk "your-psk" \
  --override-input discoveryServiceIp "192.168.1.100"
```

## Development Workflow

### 1. Generate PSK
```bash
cd ../discovery-service
python3 generate_psk.py
# Copy the generated PSK
```

### 2. Test Build (choose one method)

**Script method:**
```bash
./build-image.sh -p <psk> -i <ip> -r <repo>
```

**Direct method:**
```bash
DISCOVERY_PSK=<psk> DISCOVERY_SERVICE_IP=<ip> \
nix build .#custom-bootstrap.config.system.build.sdImage --show-trace
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

For comprehensive troubleshooting guides, see:
- **[Bootstrap Troubleshooting](../docs/bootstrap-troubleshooting.md)** - CachyOS-specific build issues
- **[Bootstrap Walkthrough](../docs/bootstrap-walkthrough.md)** - Step-by-step resolution guide
- **[CachyOS Setup](../docs/cachyos-setup.md)** - Prerequisites and initial setup

### Quick Fixes

**Build fails on CachyOS:** The build script automatically adds stability flags (`--option sandbox false --max-jobs 1`)

**PSK validation fails:** Generate a proper 64-character hex PSK:
```bash
python3 ../discovery-service/generate_psk.py
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
nix build .#custom-bootstrap.config.system.build.sdImage -o custom-image
```

### Debug Build
```bash
nix build .#custom-bootstrap.config.system.build.sdImage --show-trace --verbose
```

### Build for Different Architectures
```bash
# For x86_64 testing (won't work on real Pi)
nix build .#custom-bootstrap.config.system.build.sdImage --system x86_64-linux
```

### Integration with CI/CD

**GitHub Actions example:**
```yaml
- name: Build Bootstrap Image
  run: |
    export DISCOVERY_PSK="${{ secrets.DISCOVERY_PSK }}"
    nix build .#custom-bootstrap.config.system.build.sdImage \
      --system aarch64-linux --extra-platforms aarch64-linux
```

**Makefile integration:**
```makefile
ARCH := $(shell uname -m)
CROSS_ARGS := $(if $(filter-out aarch64,$(ARCH)),--system aarch64-linux --extra-platforms aarch64-linux)

build:
	nix build .#custom-bootstrap.config.system.build.sdImage $(CROSS_ARGS)
```

## Files Overview

| File | Purpose |
|------|---------|
| `flake-updated.nix` | Enhanced flake with parameter injection |
| `configuration-updated.nix` | Bootstrap system configuration |
| `build-image.sh` | User-friendly build script |
| `README.md` | This documentation |

## Next Steps

After building your image:

1. **Flash to SD card** using `dd` or similar tool
2. **Boot Pi** with ethernet connection  
3. **Monitor discovery service** for device registration
4. **Verify bootstrap** completion via logs or NTFY

For the main sensor configuration, see the [main README](../README.md) for flake target setup requirements.