#!/bin/bash

# Test script to verify environment variable injection
export DISCOVERY_PSK="test-psk-123"
export DISCOVERY_SERVICE_IP="192.168.1.100"
export CONFIG_REPO_URL="github:test/repo"

echo "Environment variables set:"
echo "DISCOVERY_PSK: $DISCOVERY_PSK"
echo "DISCOVERY_SERVICE_IP: $DISCOVERY_SERVICE_IP"
echo "CONFIG_REPO_URL: $CONFIG_REPO_URL"

echo ""
echo "Testing Nix evaluation:"
nix eval --expr 'builtins.getEnv "DISCOVERY_PSK"'
nix eval --expr 'builtins.getEnv "DISCOVERY_SERVICE_IP"'
nix eval --expr 'builtins.getEnv "CONFIG_REPO_URL"'
