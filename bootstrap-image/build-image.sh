#!/usr/bin/env bash
set -euo pipefail

# Build script for bootstrap images with discovery service integration

# Default values
DISCOVERY_PSK=""
DISCOVERY_SERVICE_IP="10.42.0.1"
CONFIG_REPO_URL="github:yearly1825/nixos-pi-configs"
OUTPUT_DIR="./result"

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_usage() {
    echo "Usage: $0 -p <PSK> [-i <IP>] [-r <REPO>] [-o <OUTPUT>]"
    echo ""
    echo "Options:"
    echo "  -p, --psk <PSK>           Discovery service PSK (required)"
    echo "  -i, --ip <IP>            Discovery service IP (default: 192.168.1.100)"
    echo "  -r, --repo <REPO>        Config repository URL (default: github:yourusername/nixos-pi-configs)"
    echo "  -o, --output <DIR>       Output directory (default: ./result)"
    echo "  -h, --help               Show this help"
    echo ""
    echo "Examples:"
    echo "  # Generate PSK first"
    echo "  python3 ../discovery-service/generate_psk.py"
    echo ""
    echo "  # Build with generated PSK"
    echo "  $0 -p abc123def456789abcdef123456789abcdef123456789abcdef123456789abcdef"
    echo ""
    echo "  # Build with custom settings"
    echo "  $0 -p <PSK> -i 10.0.1.100 -r github:myuser/sensor-configs"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--psk)
            DISCOVERY_PSK="$2"
            shift 2
            ;;
        -i|--ip)
            DISCOVERY_SERVICE_IP="$2"
            shift 2
            ;;
        -r|--repo)
            CONFIG_REPO_URL="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$DISCOVERY_PSK" ]; then
    log_error "PSK is required! Use -p or --psk to specify."
    echo ""
    show_usage
    exit 1
fi

# Validate PSK length (should be 64 hex characters)
if [[ ! "$DISCOVERY_PSK" =~ ^[a-fA-F0-9]{64}$ ]]; then
    log_warn "PSK should be 64 hex characters. Current length: ${#DISCOVERY_PSK}"
    echo "Are you sure this is correct? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Aborted. Please generate a proper PSK using:"
        log_info "  python3 ../discovery-service/generate_psk.py"
        exit 1
    fi
fi

# Show build configuration
log_info "Building bootstrap image with configuration:"
log_info "  PSK:            ${DISCOVERY_PSK:0:16}... (truncated)"
log_info "  Service IP:     $DISCOVERY_SERVICE_IP"
log_info "  Config Repo:    $CONFIG_REPO_URL"
log_info "  Output Dir:     $OUTPUT_DIR"

# Set environment variables for the flake
export DISCOVERY_PSK="$DISCOVERY_PSK"
export DISCOVERY_SERVICE_IP="$DISCOVERY_SERVICE_IP"
export CONFIG_REPO_URL="$CONFIG_REPO_URL"

# Platform detection for cross-compilation
HOST_ARCH=$(uname -m)
CROSS_ARGS=""

case "$HOST_ARCH" in
    x86_64)
        log_info "🔄 Cross-compiling from x86_64 to aarch64"
        CROSS_ARGS="--system aarch64-linux --extra-platforms aarch64-linux"
        ;;
    aarch64|arm64)
        log_info "🏠 Native build on aarch64"
        ;;
    *)
        log_warn "Unknown architecture: $HOST_ARCH, attempting cross-compilation"
        CROSS_ARGS="--system aarch64-linux --extra-platforms aarch64-linux"
        ;;
esac

# Detect CachyOS and add stability flags
if [ -f /etc/os-release ] && grep -q -i "cachy" /etc/os-release; then
    log_info "🐧 CachyOS detected, adding stability flags"
    CROSS_ARGS="$CROSS_ARGS --option sandbox false --max-jobs 1"
elif [ -f /etc/os-release ] && grep -q -i "arch" /etc/os-release; then
    log_info "🏛️  Arch-based system detected"
    # Add any arch-specific optimizations if needed
fi

# Build the image
log_info "Starting build process with args: $CROSS_ARGS"
if nix build .#bootstrap-image --out-link "$OUTPUT_DIR" $CROSS_ARGS --show-trace; then
    log_info "✅ Build completed successfully!"

    # Get the actual image path
    IMAGE_PATH=$(readlink -f "$OUTPUT_DIR")

    # Look for image file (compressed or uncompressed) in sd-image subdirectory first, then fallback to root
    IMAGE_FILE=$(find "$IMAGE_PATH/sd-image" -name "*.img.zst" -o -name "*.img" 2>/dev/null | head -1)
    if [ -z "$IMAGE_FILE" ]; then
        IMAGE_FILE=$(find "$IMAGE_PATH" -name "*.img.zst" -o -name "*.img" | head -1)
    fi

    if [ -n "$IMAGE_FILE" ]; then
        IMAGE_SIZE=$(du -h "$IMAGE_FILE" | cut -f1)
        log_info "📀 Image file: $IMAGE_FILE"
        log_info "📏 Image size: $IMAGE_SIZE"
        log_info ""
        log_info "🎯 Next steps:"
        if [[ "$IMAGE_FILE" == *.zst ]]; then
            log_info "  1. Flash compressed image to SD card:"
            log_info "     zstd -d '$IMAGE_FILE' --stdout | sudo dd of=/dev/sdX bs=4M status=progress"
            log_info "     OR decompress first: zstd -d '$IMAGE_FILE'"
        else
            log_info "  1. Flash to SD card: sudo dd if='$IMAGE_FILE' of=/dev/sdX bs=4M status=progress"
        fi
        log_info "  2. Boot Raspberry Pi with ethernet connected"
        log_info "  3. Monitor discovery service logs for registration"
        log_info ""
        log_info "💡 Security reminder: This image contains your PSK!"
    else
        log_warn "Build completed but could not find image file in $IMAGE_PATH"
    fi
else
    log_error "❌ Build failed!"
    exit 1
fi

log_info "🎉 Bootstrap image build complete!"
