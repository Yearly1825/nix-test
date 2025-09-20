#!/usr/bin/env python3
"""
Test suite for simplified discovery service
"""

import os
import json
import hmac
import hashlib
import tempfile
from pathlib import Path
from fastapi.testclient import TestClient

# Test with a minimal configuration
TEST_CONFIG = {
    "deployment": {
        "name": "test-sensor",
        "environment": "test"
    },
    "discovery_service": {
        "ip": "10.42.0.1",
        "port": 8080,
        "psk": "test-psk-for-testing-only"
    },
    "netbird": {
        "setup_key": "test-netbird-key"
    },
    "ssh_keys": [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..."
    ],
    "api": {
        "host": "0.0.0.0",
        "port": 8080
    },
    "database": {
        "file": ":memory:"  # Use in-memory database for testing
    },
    "ntfy": {
        "enabled": False
    }
}

def create_test_signature(psk: str, data: str) -> str:
    """Create HMAC signature for testing"""
    return hmac.new(psk.encode(), data.encode(), hashlib.sha256).hexdigest()

def test_simplified_discovery():
    """Test the simplified discovery service"""

    # Create temporary config file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
        import yaml
        yaml.dump(TEST_CONFIG, f)
        config_path = f.name

    try:
        # Import the app with test config
        import sys
        sys.path.insert(0, '/Users/j/Documents/homelab/nix-sensor/discovery-service')

        from app.simple_main import create_app
        app = create_app(config_path)

        client = TestClient(app)

        # Test health endpoint
        print("Testing /health endpoint...")
        response = client.get("/health")
        assert response.status_code == 200
        health_data = response.json()
        assert health_data["status"] == "healthy"
        print("✅ Health check passed")

        # Test device registration
        print("Testing /register endpoint...")
        test_serial = "test-serial-123"
        test_mac = "aa:bb:cc:dd:ee:ff"
        signature = create_test_signature("test-psk-for-testing-only", f"{test_serial}:{test_mac}")

        register_data = {
            "serial": test_serial,
            "mac": test_mac,
            "signature": signature
        }

        response = client.post("/register", json=register_data)
        assert response.status_code == 200
        register_response = response.json()
        assert register_response["success"] == True
        assert "hostname" in register_response
        assert "encrypted_config" in register_response
        hostname = register_response["hostname"]
        print(f"✅ Registration passed, assigned hostname: {hostname}")

        # Test device confirmation
        print("Testing /confirm endpoint...")
        confirm_signature = create_test_signature("test-psk-for-testing-only", f"{test_serial}:{hostname}")

        confirm_data = {
            "serial": test_serial,
            "hostname": hostname,
            "signature": confirm_signature,
            "status": "success"
        }

        response = client.post("/confirm", json=confirm_data)
        assert response.status_code == 200
        confirm_response = response.json()
        assert confirm_response["success"] == True
        print("✅ Confirmation passed")

        # Test stats endpoint
        print("Testing /stats endpoint...")
        response = client.get("/stats")
        assert response.status_code == 200
        stats_data = response.json()
        assert stats_data["total_registrations"] >= 1
        print("✅ Stats endpoint passed")

        print("\n🎉 All tests passed! Simplified discovery service is working correctly.")

    finally:
        # Clean up
        os.unlink(config_path)

if __name__ == "__main__":
    test_simplified_discovery()
