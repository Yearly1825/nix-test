#!/usr/bin/env python3
"""
Discovery service client for Raspberry Pi bootstrap process.
This script handles secure registration and configuration retrieval.
"""

import os
import sys
import json
import time
import hmac
import hashlib
import base64
import subprocess
from pathlib import Path
from typing import Optional, Dict, Any

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt
from cryptography.hazmat.primitives import hashes

try:
    import requests
except ImportError:
    print("Installing required packages...")
    subprocess.run([sys.executable, "-m", "pip", "install", "requests", "cryptography"], check=True)
    import requests

class BootstrapClient:
    """Client for discovery service integration"""

    def __init__(self, server_url: str, psk: str):
        self.server_url = server_url.rstrip('/')
        self.psk = psk.encode() if isinstance(psk, str) else psk

    def _create_signature(self, data: str, timestamp: int = None) -> tuple[str, int]:
        """Create HMAC signature for data"""
        if timestamp is None:
            timestamp = int(time.time())

        message = f"{data}:{timestamp}".encode()
        signature = hmac.new(self.psk, message, hashlib.sha256).hexdigest()
        return signature, timestamp

    def _derive_device_key(self, device_serial: str) -> bytes:
        """Derive device-specific encryption key"""
        salt = device_serial.encode().ljust(32, b'\x00')[:32]

        kdf = Scrypt(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            n=2**14,
            r=8,
            p=1,
        )

        return kdf.derive(self.psk)

    def _decrypt_payload(self, encrypted_data: str, device_serial: str) -> dict:
        """Decrypt configuration payload"""
        key = self._derive_device_key(device_serial)

        try:
            # Decode base64
            encrypted_payload = base64.b64decode(encrypted_data.encode())

            # Extract components
            nonce = encrypted_payload[:12]
            tag = encrypted_payload[-16:]
            ciphertext = encrypted_payload[12:-16]

            # Decrypt
            cipher = Cipher(algorithms.AES(key), modes.GCM(nonce, tag))
            decryptor = cipher.decryptor()
            plaintext = decryptor.update(ciphertext) + decryptor.finalize()

            return json.loads(plaintext.decode())
        except Exception as e:
            raise ValueError(f"Failed to decrypt payload: {e}")

    def register_device(self, serial: str, mac: str) -> Dict[str, Any]:
        """Register device with discovery service"""
        # Create signature
        data = f"{serial}:{mac}"
        signature, timestamp = self._create_signature(data)

        # Prepare request
        payload = {
            "serial": serial,
            "mac": mac,
            "signature": signature,
            "timestamp": timestamp
        }

        # Make request
        response = requests.post(
            f"{self.server_url}/register",
            json=payload,
            timeout=30
        )
        response.raise_for_status()

        result = response.json()

        # Decrypt configuration
        config = self._decrypt_payload(result['encrypted_config'], serial)

        return {
            'hostname': result['hostname'],
            'netbird_setup_key': config['netbird_setup_key'],
            'ssh_keys': config['ssh_keys'],
            'config_timestamp': config['timestamp']
        }

    def confirm_bootstrap(self, serial: str, hostname: str, status: str, error_message: str = None):
        """Confirm bootstrap completion"""
        # Create signature
        data = f"{serial}:{hostname}"
        signature, timestamp = self._create_signature(data)

        # Prepare request
        payload = {
            "serial": serial,
            "hostname": hostname,
            "signature": signature,
            "timestamp": timestamp,
            "status": status,
            "error_message": error_message
        }

        # Make request
        try:
            response = requests.post(
                f"{self.server_url}/confirm",
                json=payload,
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Warning: Failed to confirm bootstrap status: {e}")
            return None

def get_device_info() -> Dict[str, str]:
    """Get device serial number and MAC address"""

    def get_serial() -> str:
        """Get device serial number"""
        serial_paths = [
            "/sys/firmware/devicetree/base/serial-number",
            "/proc/device-tree/serial-number"
        ]

        for path in serial_paths:
            if os.path.exists(path):
                try:
                    with open(path, 'r') as f:
                        return f.read().strip('\x00\n')
                except:
                    continue

        # Fallback to CPU serial
        try:
            with open("/proc/cpuinfo", 'r') as f:
                for line in f:
                    if line.startswith("Serial"):
                        return line.split(":")[-1].strip()
        except:
            pass

        raise RuntimeError("Could not determine device serial number")

    def get_mac() -> str:
        """Get primary ethernet MAC address"""
        try:
            result = subprocess.run(['ip', 'link', 'show', 'eth0'],
                                  capture_output=True, text=True, check=True)
            for line in result.stdout.split('\n'):
                if 'ether' in line:
                    return line.strip().split()[1]
        except:
            pass

        # Fallback to any available interface
        try:
            result = subprocess.run(['ip', 'link', 'show'],
                                  capture_output=True, text=True, check=True)
            for line in result.stdout.split('\n'):
                if 'ether' in line and 'LOOPBACK' not in line:
                    return line.strip().split()[1]
        except:
            pass

        raise RuntimeError("Could not determine device MAC address")

    return {
        'serial': get_serial(),
        'mac': get_mac()
    }

def main():
    """Main bootstrap client function"""
    if len(sys.argv) != 3:
        print("Usage: bootstrap_client.py <discovery_server_url> <psk>")
        print("Example: bootstrap_client.py http://192.168.1.100:8080 your-psk-here")
        sys.exit(1)

    server_url = sys.argv[1]
    psk = sys.argv[2]

    try:
        # Get device information
        print("🔍 Gathering device information...")
        device_info = get_device_info()
        serial = device_info['serial']
        mac = device_info['mac']

        print(f"📱 Device Serial: {serial}")
        print(f"🌐 MAC Address: {mac}")

        # Initialize client
        client = BootstrapClient(server_url, psk)

        # Register with discovery service
        print(f"🚀 Registering with discovery service...")
        config = client.register_device(serial, mac)

        hostname = config['hostname']
        netbird_key = config['netbird_setup_key']
        ssh_keys = config['ssh_keys']

        print(f"✅ Registration successful!")
        print(f"🏠 Assigned hostname: {hostname}")
        print(f"🔐 Netbird setup key: {netbird_key[:20]}...")
        print(f"🗝️  SSH keys: {len(ssh_keys)} key(s) received")

        # Save configuration
        config_dir = Path("/var/lib/nixos-bootstrap")
        config_dir.mkdir(parents=True, exist_ok=True)

        config_file = config_dir / "discovery_config.json"
        with open(config_file, 'w') as f:
            json.dump(config, f, indent=2)

        print(f"💾 Configuration saved to {config_file}")

        # Output for shell script consumption
        print("---BOOTSTRAP_CONFIG_START---")
        print(f"HOSTNAME={hostname}")
        print(f"NETBIRD_SETUP_KEY={netbird_key}")
        print(f"SSH_KEYS_COUNT={len(ssh_keys)}")
        print(f"CONFIG_FILE={config_file}")
        print("---BOOTSTRAP_CONFIG_END---")

        return {
            'success': True,
            'hostname': hostname,
            'config_file': str(config_file),
            'serial': serial
        }

    except Exception as e:
        print(f"❌ Bootstrap client error: {e}")
        return {
            'success': False,
            'error': str(e),
            'serial': device_info.get('serial', 'unknown') if 'device_info' in locals() else 'unknown'
        }

if __name__ == "__main__":
    result = main()
    sys.exit(0 if result['success'] else 1)
