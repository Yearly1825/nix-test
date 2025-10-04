#!/usr/bin/env bash
# Simplified build script that reads from unified deployment configuration
# Uses .deployment.yaml from the root directory

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { echo -e "${BLUE}[DEBUG]${NC} $1"; }

# Check for required dependencies
check_dependencies() {
    if ! command -v python3 &> /dev/null; then
        log_error "python3 is required to parse configuration"
        exit 1
    fi
    if ! python3 -c "import yaml" 2>/dev/null; then
        log_info "Installing PyYAML for configuration parsing..."
        python3 -m pip install --user PyYAML
    fi
}

# Parse configuration from .deployment.yaml
parse_config() {
    local config_file="../.deployment.yaml"
    if [ ! -f "$config_file" ]; then
        log_error "Deployment configuration not found: $config_file"
        log_error ""
        log_error "Please run the setup first:"
        log_error "  cd .. && python3 setup_deployment.py"
        log_error ""
        log_error "Or copy and edit the template:"
        log_error "  cd .. && cp .deployment.template.yaml .deployment.yaml"
        log_error "  # Edit .deployment.yaml with your settings"
        exit 1
    fi

    log_info "📋 Reading configuration from $config_file"

    # Extract configuration using Python
    local extract_script="
import yaml
import sys

try:
    with open('$config_file', 'r') as f:
        config = yaml.safe_load(f)

    # Extract required values
    discovery = config.get('discovery_service', {})
    bootstrap = config.get('bootstrap', {})
    ntfy = config.get('ntfy', {})

    psk = discovery.get('psk', '')
    ip = discovery.get('ip', '10.42.0.1')
    port = discovery.get('port', 8080)
    repo = bootstrap.get('config_repo_url', 'github:yearly1825/nixos-pi-configs')

    # Validate required fields
    if not psk or psk.startswith('CHANGE_ME'):
        print('ERROR: PSK not configured in .deployment.yaml', file=sys.stderr)
        sys.exit(1)
    if not repo or repo.startswith('CHANGE_ME'):
        print('ERROR: Config repository not configured in .deployment.yaml', file=sys.stderr)
        sys.exit(1)

    # Output configuration (will be sourced by bash)
    print(f'DISCOVERY_PSK=\"{psk}\"')
    print(f'DISCOVERY_SERVICE_IP=\"{ip}\"')
    print(f'DISCOVERY_SERVICE_PORT=\"{port}\"')
    print(f'CONFIG_REPO_URL=\"{repo}\"')

    # NTFY configuration for potential testing
    ntfy_enabled = ntfy.get('enabled', False)
    ntfy_url = ntfy.get('url', '')
    print(f'NTFY_ENABLED=\"{str(ntfy_enabled).lower()}\"')
    print(f'NTFY_URL=\"{ntfy_url}\"')

    # Deployment info
    deployment = config.get('deployment', {})
    deployment_name = deployment.get('name', 'SENSOR')
    print(f'DEPLOYMENT_NAME=\"{deployment_name}\"')

except Exception as e:
    print(f'ERROR: Failed to parse configuration: {e}', file=sys.stderr)
    sys.exit(1)
"

    # Execute Python script and source the output
    local config_vars
    config_vars=$(python3 -c "$extract_script")
    if [ $? -ne 0 ]; then
        log_error "Failed to parse deployment configuration"
        exit 1
    fi
    eval "$config_vars"

    # Validate PSK format
    if [[ ! "$DISCOVERY_PSK" =~ ^[a-fA-F0-9]{64}$ ]]; then
        log_warn "PSK should be 64 hex characters. Current length: ${#DISCOVERY_PSK}"
        log_warn "Generated PSKs should be 64 characters. Continuing anyway..."
    fi

    log_info "✅ Configuration loaded successfully"
}

# Test NTFY if enabled and requested
test_ntfy() {
    if [ "$NTFY_ENABLED" = "true" ] && [ -n "$NTFY_URL" ]; then
        local test_ntfy_flag="--ntfy-test"
        if [[ "$*" =~ $test_ntfy_flag ]]; then
            log_info "🧪 Testing NTFY notifications..."
            if cd .. && python3 setup_deployment.py --ntfy-test; then
                log_info "✅ NTFY test successful"
            else
                log_warn "⚠️  NTFY test failed, but continuing with build"
            fi
            cd - > /dev/null
        fi
    fi
}

# Show configuration summary in a table
show_config_summary() {
    echo ""
    echo "Build Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "%-25s %s\n" "Deployment Name:" "$DEPLOYMENT_NAME"
    printf "%-25s %s\n" "Discovery Service:" "$DISCOVERY_SERVICE_IP:$DISCOVERY_SERVICE_PORT"
    printf "%-25s %s\n" "Config Repository:" "$CONFIG_REPO_URL"
    printf "%-25s %s\n" "PSK (truncated):" "${DISCOVERY_PSK:0:16}...${DISCOVERY_PSK: -8}"
    if [ "$NTFY_ENABLED" = "true" ]; then
        printf "%-25s %s\n" "NTFY Notifications:" "✅ Enabled ($NTFY_URL)"
    else
        printf "%-25s %s\n" "NTFY Notifications:" "❌ Disabled"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# List removable block devices (potential SD cards)
list_removable_devices() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "💾 AVAILABLE REMOVABLE DEVICES (Removable drives only)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Check if lsblk is available (Linux only)
    if command -v lsblk &> /dev/null; then
        local found_devices=false
        printf "  %-15s %-12s %s\n" "Device" "Size" "Model"
        echo "  ──────────────────────────────────────────────────────────────────────────────"
        while IFS= read -r line; do
            found_devices=true
            # Parse lsblk output: NAME SIZE MODEL
            local device=$(echo "$line" | awk '{print $1}')
            local size=$(echo "$line" | awk '{print $2}')
            local model=$(echo "$line" | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ *$//')

            printf "  %-15s %-12s %s\n" "/dev/$device" "$size" "$model"
        done < <(lsblk -ndo NAME,SIZE,RM,MODEL | awk '$3=="1" {$3=""; print $0}')

        if [ "$found_devices" = false ]; then
            echo "  No removable devices detected"
        fi
    else
        echo "  lsblk not available (non-Linux system)"
    fi

    echo ""
    echo ""
}

# Show usage information
show_usage() {
    echo "Simplified Bootstrap Image Builder"
    echo "================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script automatically reads configuration from ../.deployment.yaml"
    echo ""
    echo "Options:"
    echo "  --ntfy-test          Test NTFY notifications before building"
    echo "  -o, --output <DIR>   Output directory (default: ./result)"
    echo "  -h, --help           Show this help"
    echo ""
    echo "Setup:"
    echo "  If you haven't configured your deployment yet:"
    echo "    cd .. && python3 setup_deployment.py"
    echo ""
    echo "  Or manually edit configuration:"
    echo "    cd .. && cp .deployment.template.yaml .deployment.yaml"
    echo "    # Edit .deployment.yaml with your settings"
    echo ""
    echo "Legacy Usage:"
    echo "  For the old parameter-based build, use:"
    echo "    ./build-image.sh -p <PSK> [options]"
}

# Parse command line arguments
OUTPUT_DIR="./result"
NTFY_TEST=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --ntfy-test)
            NTFY_TEST=true
            shift
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

# Main build process
main() {
    log_info "🚀 Bootstrap Image Builder (Unified Configuration)"
    log_info "================================================="

    # Check dependencies
    check_dependencies

    # Parse configuration
    parse_config

    # Test NTFY if requested
    if [ "$NTFY_TEST" = true ]; then
        test_ntfy "$@"
        echo ""
    fi

    # Show build configuration
    show_config_summary

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
    fi

    # Build the image
    log_info "🔨 Starting build process..."
    echo ""

    if nix build --expr "
      let
        flake = builtins.getFlake (toString ./.);
      in
        (flake.lib.buildBootstrapImage {
          discoveryPsk = \"$DISCOVERY_PSK\";
          discoveryServiceIp = \"$DISCOVERY_SERVICE_IP\";
          configRepoUrl = \"$CONFIG_REPO_URL\";
        }).config.system.build.sdImage
    " --out-link "$OUTPUT_DIR" $CROSS_ARGS --show-trace --impure; then
        echo ""
        log_info "✅ Build completed successfully!"
        echo ""

        # Get the actual image path
        IMAGE_PATH=$(readlink -f "$OUTPUT_DIR")

        # Look for image file (always .zst compressed)
        IMAGE_FILE=$(find "$IMAGE_PATH/sd-image" -name "*.img.zst" 2>/dev/null | head -1)
        if [ -z "$IMAGE_FILE" ]; then
            IMAGE_FILE=$(find "$IMAGE_PATH" -name "*.img.zst" | head -1)
        fi

        if [ -n "$IMAGE_FILE" ]; then
            IMAGE_SIZE=$(du -h "$IMAGE_FILE" | cut -f1)

            # Show image details
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "📀 IMAGE DETAILS"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            printf "  %-18s %s\n" "File:" "$(basename "$IMAGE_FILE")"
            printf "  %-18s %s\n" "Path:" "$IMAGE_FILE"
            printf "  %-18s %s\n" "Size:" "$IMAGE_SIZE (compressed)"
            printf "  %-18s %s\n" "Format:" "Zstandard compressed (.zst)"
            echo ""
            echo ""

            # List removable devices
            list_removable_devices

            # Show flashing instructions
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "⚡ FLASH INSTRUCTIONS"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "  Replace /dev/sdX with your actual device path from the table above"
            echo ""
            echo "  # Verify device:"
            echo "  lsblk /dev/sdX"
            echo ""
            echo "  # Unmount partitions:"
            echo "  sudo umount /dev/sdX*"
            echo ""
            echo "  # Flash:"
            echo "  zstd -d '$IMAGE_FILE' --stdout | \\"
            echo "    sudo dd of=/dev/sdX bs=4M status=progress conv=fsync"
            echo ""
            echo ""

            # Show next steps
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "🚀 NEXT STEPS"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "  1. Flash SD card using the command above"
            echo "  2. Insert SD card into Raspberry Pi"
            echo "  3. Connect Raspberry Pi to ethernet"
            echo "  4. Power on the Raspberry Pi"
            echo "  5. Monitor logs: cd ../discovery-service && docker-compose logs -f"
            echo ""
            echo "  Expected: Pi will auto-configure within 5-10 minutes"
            echo ""
            echo ""
            log_info "🎉 Bootstrap image build complete!"
        else
            log_warn "Build completed but could not find image file in $IMAGE_PATH"
        fi
    else
        echo ""
        log_error "❌ Build failed!"
        exit 1
    fi
}

# Run main function
main "$@"
