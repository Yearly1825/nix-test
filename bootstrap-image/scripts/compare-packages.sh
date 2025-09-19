#!/usr/bin/env bash
set -euo pipefail

# Script to compare packages between bootstrap-image and nixos-pi-configs
# This helps ensure the bootstrap image pre-installs everything needed

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Package Comparison: Bootstrap vs Sensor Config ===${NC}"
echo ""

# Function to extract packages from a nix file
extract_packages() {
    local file=$1
    local label=$2

    echo -e "${YELLOW}Packages in $label:${NC}"

    # Extract package names between environment.systemPackages and the closing bracket
    # This is a simplified extraction - for complete accuracy use nix eval
    grep -A 100 "environment.systemPackages" "$file" 2>/dev/null | \
        sed -n '/with pkgs/,/\];/p' | \
        grep -E '^\s*([\w-]+)$|^\s*#.*[\w-]+' | \
        sed 's/^\s*//' | \
        sed 's/#.*//' | \
        grep -v '^$' | \
        grep -v 'with pkgs' | \
        grep -v '\];' | \
        sort -u || true
}

# Paths to configuration files
BOOTSTRAP_CONFIG="../configuration.nix"
SENSOR_CONFIG="../../nixos-pi-configs/configuration.nix"
KISMET_MODULE="../../nixos-pi-configs/modules/kismet.nix"
NETBIRD_MODULE="../../nixos-pi-configs/modules/netbird.nix"

# Check if files exist
if [ ! -f "$BOOTSTRAP_CONFIG" ]; then
    echo -e "${RED}Error: Bootstrap configuration not found at $BOOTSTRAP_CONFIG${NC}"
    exit 1
fi

if [ ! -f "$SENSOR_CONFIG" ]; then
    echo -e "${RED}Error: Sensor configuration not found at $SENSOR_CONFIG${NC}"
    exit 1
fi

# Create temporary files for package lists
BOOTSTRAP_PKGS=$(mktemp)
SENSOR_PKGS=$(mktemp)
ALL_SENSOR_PKGS=$(mktemp)

# Cleanup on exit
trap "rm -f $BOOTSTRAP_PKGS $SENSOR_PKGS $ALL_SENSOR_PKGS" EXIT

echo -e "${GREEN}1. Extracting bootstrap packages...${NC}"
# Extract bootstrap packages
grep -A 200 "environment.systemPackages" "$BOOTSTRAP_CONFIG" | \
    sed -n '/with pkgs/,/\];/p' | \
    grep -v '(pkgs.writeScriptBin' | \
    grep -v '(python3.withPackages' | \
    sed 's/^\s*//' | \
    sed 's/#.*//' | \
    sed 's/\s*$//' | \
    grep -E '^[a-zA-Z]' | \
    grep -v '^with' | \
    grep -v '^\];' | \
    sort -u > "$BOOTSTRAP_PKGS"

# Add Python packages from bootstrap
echo "python3" >> "$BOOTSTRAP_PKGS"
echo "python3Packages.requests" >> "$BOOTSTRAP_PKGS"
echo "python3Packages.cryptography" >> "$BOOTSTRAP_PKGS"
echo "python3Packages.pip" >> "$BOOTSTRAP_PKGS"
echo "python3Packages.gps3" >> "$BOOTSTRAP_PKGS"
echo "python3Packages.setuptools" >> "$BOOTSTRAP_PKGS"
echo "python3Packages.protobuf" >> "$BOOTSTRAP_PKGS"
echo "python3Packages.numpy" >> "$BOOTSTRAP_PKGS"
sort -u -o "$BOOTSTRAP_PKGS" "$BOOTSTRAP_PKGS"

echo -e "${GREEN}2. Extracting sensor config packages...${NC}"
# Extract sensor main config packages
grep -A 200 "environment.systemPackages" "$SENSOR_CONFIG" | \
    sed -n '/with pkgs/,/\];/p' | \
    grep -v '(pkgs.writeScriptBin' | \
    grep -v '(python3.withPackages' | \
    sed 's/^\s*//' | \
    sed 's/#.*//' | \
    sed 's/\s*$//' | \
    grep -E '^[a-zA-Z]' | \
    grep -v '^with' | \
    grep -v '^\];' | \
    sort -u > "$ALL_SENSOR_PKGS"

# Add Python packages from sensor config
echo "python3" >> "$ALL_SENSOR_PKGS"
echo "python3Packages.requests" >> "$ALL_SENSOR_PKGS"
echo "python3Packages.cryptography" >> "$ALL_SENSOR_PKGS"
echo "python3Packages.pip" >> "$ALL_SENSOR_PKGS"
echo "python3Packages.gps3" >> "$ALL_SENSOR_PKGS"

# Extract kismet module packages
if [ -f "$KISMET_MODULE" ]; then
    echo -e "${GREEN}3. Extracting kismet module packages...${NC}"
    grep -A 20 "environment.systemPackages" "$KISMET_MODULE" | \
        sed -n '/with pkgs/,/\];/p' | \
        grep -v '(python3.withPackages' | \
        sed 's/^\s*//' | \
        sed 's/#.*//' | \
        sed 's/\s*$//' | \
        grep -E '^[a-zA-Z]' | \
        grep -v '^with' | \
        grep -v '^\];' >> "$ALL_SENSOR_PKGS"

    # Add Python packages from kismet
    echo "python3Packages.gps3" >> "$ALL_SENSOR_PKGS"
    echo "python3Packages.setuptools" >> "$ALL_SENSOR_PKGS"
    echo "python3Packages.protobuf" >> "$ALL_SENSOR_PKGS"
    echo "python3Packages.numpy" >> "$ALL_SENSOR_PKGS"
fi

# Extract netbird module packages
if [ -f "$NETBIRD_MODULE" ]; then
    echo -e "${GREEN}4. Extracting netbird module packages...${NC}"
    echo "netbird" >> "$ALL_SENSOR_PKGS"
fi

# Sort and deduplicate
sort -u -o "$ALL_SENSOR_PKGS" "$ALL_SENSOR_PKGS"

echo ""
echo -e "${BLUE}=== Package Lists ===${NC}"
echo ""
echo -e "${YELLOW}Bootstrap packages (${GREEN}$(wc -l < $BOOTSTRAP_PKGS)${YELLOW} packages):${NC}"
cat "$BOOTSTRAP_PKGS" | column

echo ""
echo -e "${YELLOW}Sensor config packages (${GREEN}$(wc -l < $ALL_SENSOR_PKGS)${YELLOW} packages):${NC}"
cat "$ALL_SENSOR_PKGS" | column

echo ""
echo -e "${BLUE}=== Comparison Results ===${NC}"
echo ""

# Find packages in sensor but not in bootstrap
MISSING=$(comm -13 "$BOOTSTRAP_PKGS" "$ALL_SENSOR_PKGS")
if [ -n "$MISSING" ]; then
    echo -e "${RED}❌ Packages in sensor config but NOT in bootstrap:${NC}"
    echo "$MISSING" | while read pkg; do
        echo "  - $pkg"
    done
    echo ""
    echo -e "${YELLOW}These packages will need to be downloaded during nixos-rebuild switch!${NC}"
else
    echo -e "${GREEN}✅ All sensor packages are pre-installed in bootstrap image!${NC}"
fi

echo ""

# Find packages in bootstrap but not in sensor (informational)
EXTRA=$(comm -23 "$BOOTSTRAP_PKGS" "$ALL_SENSOR_PKGS")
if [ -n "$EXTRA" ]; then
    echo -e "${BLUE}ℹ️  Extra packages in bootstrap (not in sensor config):${NC}"
    echo "$EXTRA" | while read pkg; do
        echo "  - $pkg"
    done
    echo ""
    echo -e "${YELLOW}These are OK - they help with bootstrap process${NC}"
fi

echo ""
echo -e "${BLUE}=== Recommendations ===${NC}"

if [ -n "$MISSING" ]; then
    echo -e "${YELLOW}To speed up nixos-rebuild switch, add these to bootstrap configuration.nix:${NC}"
    echo ""
    echo "environment.systemPackages = with pkgs; ["
    echo "$MISSING" | while read pkg; do
        echo "  $pkg"
    done
    echo "];"
else
    echo -e "${GREEN}✅ Bootstrap image is optimized for fast rebuilds!${NC}"
    echo "All required packages are pre-installed."
fi

echo ""
echo -e "${BLUE}Note: Helper scripts (writeScriptBin) are excluded as they're generated at runtime.${NC}"
