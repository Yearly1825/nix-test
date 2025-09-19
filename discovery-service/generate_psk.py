#!/usr/bin/env python3
"""
DEPRECATED: Use unified configuration system instead
====================================================

This script is deprecated. Please use the new unified configuration system:

    cd .. && python3 setup_deployment.py

The new system configures both the discovery service AND bootstrap images
from a single configuration file, eliminating copy-paste errors.

Legacy function: Generate a secure PSK for the discovery service
"""

import sys

# Show deprecation warning
print("⚠️  DEPRECATION WARNING")
print("=" * 50)
print("This script is deprecated. Please use the new unified configuration system:")
print()
print("  cd .. && python3 setup_deployment.py")
print()
print("The new system:")
print("  ✅ Configures discovery service AND bootstrap images")
print("  ✅ Eliminates copy-paste errors")
print("  ✅ Includes NTFY configuration")
print("  ✅ Validates all settings")
print()
print("Continue with legacy generator? [y/N]: ", end="")

response = input().strip().lower()
if response != 'y':
    print("Aborted. Please use: python3 setup_deployment.py")
    sys.exit(0)

print()
print("Continuing with legacy PSK generator...")
print()

import secrets
import hashlib
import os
from pathlib import Path

def generate_psk(length: int = 64) -> str:
    """Generate a cryptographically secure PSK"""
    return secrets.token_hex(length // 2)

def generate_admin_token(length: int = 32) -> str:
    """Generate a secure admin token"""
    return secrets.token_urlsafe(length)

def create_config_from_template(psk: str, admin_token: str) -> bool:
    """Read config-template.yaml and create config.yaml with generated keys"""

    template_path = Path("config/config-template.yaml")
    config_path = Path("config/config.yaml")

    # Check if template exists
    if not template_path.exists():
        print(f"❌ Template not found: {template_path}")
        print(f"   Make sure you're running from the discovery-service directory")
        return False

    try:
        # Read template content
        with open(template_path, 'r') as f:
            template_content = f.read()

        # Replace placeholder values using simple string replacement
        config_content = template_content.replace(
            'psk: "CHANGE_ME_TO_RANDOM_64_CHAR_HEX_STRING"',
            f'psk: "{psk}"'
        ).replace(
            'admin_token: "CHANGE_ME_ADMIN_TOKEN"',
            f'admin_token: "{admin_token}"'
        )

        # Write working config
        with open(config_path, 'w') as f:
            f.write(config_content)

        return True

    except Exception as e:
        print(f"❌ Failed to create config: {e}")
        return False

def main():
    print("🔐 Discovery Service Security Keys Generator")
    print("=" * 50)

    # Generate keys
    psk = generate_psk(64)
    admin_token = generate_admin_token(32)
    psk_hash = hashlib.sha256(psk.encode()).hexdigest()[:16]

    # Create working config from template
    if create_config_from_template(psk, admin_token):
        print("✅ Generated working configuration: config/config.yaml")
        print()
    else:
        print("❌ Failed to create working configuration")
        print("   You'll need to manually update config/config-template.yaml")
        print()

    print("🔑 Generated Keys (RECORD THESE):")
    print(f"  PSK: {psk}")
    print(f"  Admin Token: {admin_token}")
    print(f"  PSK Hash: {psk_hash}")
    print()

    print("💿 Next Steps:")
    print("  1. Deploy discovery service:")
    print("     docker-compose up -d")
    print()
    print("  2. Build bootstrap image:")
    print(f"     ./bootstrap-image/build-image.sh -p {psk}")
    print()
    print("  3. Monitor registrations:")
    print("     docker-compose logs -f discovery-service")
    print()

    print("⚠️  SECURITY NOTES:")
    print("  - Store these keys securely for rebuilding images")
    print("  - Use different keys for different deployments")
    print("  - Never commit PSK to version control")
    print("  - Regenerate keys if compromised")
    print()

    print("📋 Template vs Working Files:")
    print("  • config-template.yaml - Example template (safe to commit)")
    print("  • config.yaml - Working config with real keys (DO NOT COMMIT)")

if __name__ == "__main__":
    main()
