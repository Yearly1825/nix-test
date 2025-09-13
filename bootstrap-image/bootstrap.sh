#!/usr/bin/env bash
set -euo pipefail

# Configuration - EDIT THESE
DISCOVERY_SERVICE_IP="192.168.1.100"  # Your discovery service IP
DISCOVERY_SERVICE_PORT="8080"
CONFIG_REPO_URL="github:yourusername/nixos-pi-configs"
MAX_RETRIES=10
RETRY_DELAY=10

# Color output for visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get hardware serial number
get_serial() {
    if [ -f /sys/firmware/devicetree/base/serial-number ]; then
        cat /sys/firmware/devicetree/base/serial-number | tr -d '\0'
    else
        # Fallback to CPU serial
        grep Serial /proc/cpuinfo | cut -d' ' -f2
    fi
}

# Main bootstrap process
main() {
    log_info "Starting Raspberry Pi bootstrap process"
    
    # Get serial number
    SERIAL=$(get_serial)
    log_info "Device serial number: ${SERIAL}"
    
    # Get MAC address for logging
    MAC=$(ip link show eth0 2>/dev/null | grep ether | awk '{print $2}' || echo "unknown")
    log_info "Ethernet MAC address: ${MAC}"
    
    # Wait for network connectivity
    log_info "Checking network connectivity..."
    for i in $(seq 1 $MAX_RETRIES); do
        if ping -c1 $DISCOVERY_SERVICE_IP &>/dev/null; then
            log_info "Network is ready"
            break
        fi
        log_warn "Waiting for network... (attempt $i/$MAX_RETRIES)"
        sleep $RETRY_DELAY
    done
    
    # Register with discovery service
    log_info "Registering with discovery service at ${DISCOVERY_SERVICE_IP}:${DISCOVERY_SERVICE_PORT}"
    
    for i in $(seq 1 $MAX_RETRIES); do
        RESPONSE=$(curl -s -f -X POST \
            "http://${DISCOVERY_SERVICE_IP}:${DISCOVERY_SERVICE_PORT}/register" \
            -H "Content-Type: application/json" \
            -d "{\"serial\": \"${SERIAL}\", \"mac\": \"${MAC}\"}" \
            2>/dev/null) && break
        
        log_warn "Registration attempt $i failed, retrying..."
        sleep $RETRY_DELAY
    done
    
    if [ -z "${RESPONSE:-}" ]; then
        log_error "Failed to register with discovery service after $MAX_RETRIES attempts"
        exit 1
    fi
    
    # Parse response
    HOSTNAME=$(echo "$RESPONSE" | jq -r '.hostname')
    NETBIRD_KEY=$(echo "$RESPONSE" | jq -r '.netbird_setup_key // empty')
    
    log_info "Assigned hostname: ${HOSTNAME}"
    
    # Set hostname
    hostnamectl set-hostname "${HOSTNAME}"
    
    # Store configuration for next stage
    mkdir -p /var/lib/nixos-bootstrap
    echo "$RESPONSE" > /var/lib/nixos-bootstrap/config.json
    
    # Apply NixOS configuration
    log_info "Applying NixOS configuration from ${CONFIG_REPO_URL}"
    nixos-rebuild switch \
        --flake "${CONFIG_REPO_URL}#worker" \
        --option substituters "https://cache.nixos.org" \
        --option trusted-public-keys "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    
    log_info "Bootstrap complete!"
}

# Run main function
main "$@"