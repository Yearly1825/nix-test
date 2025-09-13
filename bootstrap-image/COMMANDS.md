# Direct Build Commands Reference

This document provides transparent, copy-paste commands for building bootstrap images without using the build script.

## Quick Reference

### Environment Setup
```bash
# Required parameters
export DISCOVERY_PSK="your-64-char-hex-psk"
export DISCOVERY_SERVICE_IP="192.168.1.100" 
export CONFIG_REPO_URL="github:yourusername/nixos-pi-configs"

# Verify environment variables are set
echo "PSK: ${DISCOVERY_PSK:0:8}..."
echo "IP: $DISCOVERY_SERVICE_IP"
echo "Repo: $CONFIG_REPO_URL"
```

### Basic Build Commands

**Native build (on aarch64 host):**
```bash
nix build .#bootstrap-image --show-trace
```

**Cross-compilation (x86_64 → aarch64):**
```bash
nix build .#bootstrap-image \
  --system aarch64-linux \
  --extra-platforms aarch64-linux \
  --show-trace
```

**CachyOS/Arch with stability flags:**
```bash
nix build .#bootstrap-image \
  --system aarch64-linux \
  --extra-platforms aarch64-linux \
  --option sandbox false \
  --max-jobs 1 \
  --show-trace
```

## Platform-Specific Commands

### CachyOS
```bash
# Set parameters
export DISCOVERY_PSK="abc123def456..."
export DISCOVERY_SERVICE_IP="192.168.1.100"

# Build with CachyOS-optimized flags
nix build .#bootstrap-image \
  --system aarch64-linux \
  --extra-platforms aarch64-linux \
  --option sandbox false \
  --max-jobs 1 \
  --extra-substituters "https://cache.nixos.org/" \
  --show-trace
```

### Ubuntu/Debian
```bash
# Ensure nix experimental features are enabled
export NIX_CONFIG="experimental-features = nix-command flakes"

nix build .#bootstrap-image \
  --system aarch64-linux \
  --extra-platforms aarch64-linux \
  --show-trace
```

### macOS (Apple Silicon)
```bash
# Native build on M1/M2 (aarch64)
nix build .#bootstrap-image --show-trace

# Cross-compile on Intel Mac
nix build .#bootstrap-image \
  --system aarch64-linux \
  --extra-platforms aarch64-linux \
  --show-trace
```

## Alternative Methods

### Method 1: Using the Nix Build Helper
```bash
# Uses automatic platform detection
nix run .#packages.x86_64-linux.build-script
```

### Method 2: Inline Parameters (no environment variables)
```bash
nix build --expr '
let
  flake = builtins.getFlake (toString ./.);
in
(flake.lib.buildBootstrapImage {
  discoveryPsk = "your-psk-here";
  discoveryServiceIp = "192.168.1.100"; 
  configRepoUrl = "github:user/repo";
}).config.system.build.sdImage' \
--system aarch64-linux \
--extra-platforms aarch64-linux \
--show-trace
```

### Method 3: Using Development Shell
```bash
# Enter development environment
nix develop

# Build using shell helper
build-bootstrap
```

## Debugging Commands

### Verbose Build with Full Trace
```bash
nix build .#bootstrap-image \
  --system aarch64-linux \
  --extra-platforms aarch64-linux \
  --show-trace \
  --verbose \
  --log-format internal-json
```

### Check Available Outputs
```bash
nix flake show
```

### Verify Environment Variables
```bash
env | grep DISCOVERY
```

### Test Configuration Without Building
```bash
nix eval .#nixosConfigurations.custom-bootstrap.config.system.name
```

## Performance Optimization

### Use Binary Cache
```bash
nix build .#bootstrap-image \
  --system aarch64-linux \
  --extra-platforms aarch64-linux \
  --extra-substituters "https://cache.nixos.org/" \
  --trusted-public-keys "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" \
  --show-trace
```

### Parallel Building (if system can handle it)
```bash
nix build .#bootstrap-image \
  --system aarch64-linux \
  --extra-platforms aarch64-linux \
  --max-jobs 4 \
  --cores 2 \
  --show-trace
```

### Build with Remote Builder (if available)
```bash
nix build .#bootstrap-image \
  --builders "ssh://builder-host aarch64-linux" \
  --show-trace
```

## Common Error Solutions

### "system 'aarch64-linux' is not supported"
```bash
# Add extra platforms support
--extra-platforms aarch64-linux
```

### Sandbox errors on CachyOS
```bash
# Disable sandbox
--option sandbox false
```

### Out of memory errors
```bash
# Reduce parallelism
--max-jobs 1 --cores 1
```

### Network/substituter timeouts
```bash
# Increase timeout and add retries
--option connect-timeout 60 \
--option stalled-download-timeout 300 \
--option download-attempts 3
```

## Complete Working Examples

### Standard CachyOS Build
```bash
#!/bin/bash
export DISCOVERY_PSK="abc123def456789abcdef123456789abcdef123456789abcdef123456789abcdef"
export DISCOVERY_SERVICE_IP="192.168.1.100"
export CONFIG_REPO_URL="github:myuser/sensor-configs"

nix build .#bootstrap-image \
  --system aarch64-linux \
  --extra-platforms aarch64-linux \
  --option sandbox false \
  --max-jobs 1 \
  --show-trace
```

### CI/CD Build (GitHub Actions)
```bash
# In CI environment
export DISCOVERY_PSK="${{ secrets.DISCOVERY_PSK }}"
export DISCOVERY_SERVICE_IP="${{ vars.DISCOVERY_IP }}"

nix build .#bootstrap-image \
  --system aarch64-linux \
  --extra-platforms aarch64-linux \
  --option sandbox false \
  --max-jobs 2 \
  --show-trace
```

### Development/Testing Build
```bash
# Quick test build with minimal output
export DISCOVERY_PSK="test-psk-not-for-production"

nix build .#bootstrap-image \
  --system aarch64-linux \
  --extra-platforms aarch64-linux \
  --quiet
```

## Output Locations

After successful build:
```bash
# Image location
ls -la result/
./result/sd-image/*.img

# Or find the actual path
readlink -f result
```

## Integration Examples

### Makefile Integration
```makefile
DISCOVERY_PSK ?= $(error DISCOVERY_PSK not set)
ARCH := $(shell uname -m)
CROSS_ARGS := $(if $(filter-out aarch64,$(ARCH)),--system aarch64-linux --extra-platforms aarch64-linux)

.PHONY: build
build:
	export DISCOVERY_PSK=$(DISCOVERY_PSK) && \
	nix build .#bootstrap-image $(CROSS_ARGS) --show-trace
```

### Shell Script Wrapper
```bash
#!/bin/bash
set -euo pipefail

PSK=${1:?"Usage: $0 <PSK> [IP]"}
IP=${2:-"192.168.1.100"}

export DISCOVERY_PSK="$PSK"
export DISCOVERY_SERVICE_IP="$IP"

exec nix build .#bootstrap-image \
  --system aarch64-linux \
  --extra-platforms aarch64-linux \
  --show-trace
```