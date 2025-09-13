#!/usr/bin/env python3
"""
Generate a secure PSK for the discovery service
"""

import secrets
import hashlib

def generate_psk(length: int = 64) -> str:
    """Generate a cryptographically secure PSK"""
    return secrets.token_hex(length // 2)

def generate_admin_token(length: int = 32) -> str:
    """Generate a secure admin token"""
    return secrets.token_urlsafe(length)

def main():
    print("🔐 Discovery Service Security Keys Generator")
    print("=" * 50)

    # Generate PSK
    psk = generate_psk(64)
    print(f"Pre-Shared Key (PSK):")
    print(f"  {psk}")
    print()

    # Generate admin token
    admin_token = generate_admin_token(32)
    print(f"Admin Token:")
    print(f"  {admin_token}")
    print()

    # Show PSK hash for verification
    psk_hash = hashlib.sha256(psk.encode()).hexdigest()[:16]
    print(f"PSK Hash (for verification): {psk_hash}")
    print()

    print("💾 Update your configuration files:")
    print(f"  config/config.yaml:")
    print(f"    deployment.psk: \"{psk}\"")
    print(f"    security.admin_token: \"{admin_token}\"")
    print()
    print(f"  bootstrap-image/bootstrap-new.sh:")
    print(f"    DISCOVERY_PSK=\"{psk}\"")
    print()

    print("⚠️  SECURITY NOTES:")
    print("  - Store these keys securely")
    print("  - Use different keys for different deployments")
    print("  - Never commit PSK to version control")
    print("  - Regenerate keys if compromised")

if __name__ == "__main__":
    main()
