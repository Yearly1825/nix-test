#!/usr/bin/env python3
"""
Example client for the discovery service API.
This shows how the Raspberry Pi bootstrap process should interact with the discovery service.
"""

import requests
import hmac
import hashlib
import time
import json
import base64
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt
from cryptography.hazmat.primitives import hashes

class DiscoveryClient:
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

    def register_device(self, serial: str, mac: str) -> dict:
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
        result['decrypted_config'] = config

        return result

    def confirm_bootstrap(self, serial: str, hostname: str, status: str, error_message: str = None) -> dict:
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
        response = requests.post(
            f"{self.server_url}/confirm",
            json=payload,
            timeout=30
        )
        response.raise_for_status()

        return response.json()

def example_usage():
    """Example of how to use the discovery client"""

    # Configuration (these would come from your bootstrap environment)
    DISCOVERY_SERVER = "http://192.168.1.100:8080"
    PSK = "your-64-char-hex-psk-here"  # This would be burned into the bootstrap image

    # Device information (these would be detected on the Pi)
    DEVICE_SERIAL = "10000000a1b2c3d4"  # From /sys/firmware/devicetree/base/serial-number
    DEVICE_MAC = "b8:27:eb:12:34:56"   # From ip link show eth0

    try:
        # Initialize client
        client = DiscoveryClient(DISCOVERY_SERVER, PSK)

        # Register device
        print(f"Registering device {DEVICE_SERIAL}...")
        result = client.register_device(DEVICE_SERIAL, DEVICE_MAC)

        hostname = result['hostname']
        config = result['decrypted_config']

        print(f"Registration successful!")
        print(f"Assigned hostname: {hostname}")
        print(f"Netbird setup key: {config['netbird_setup_key'][:20]}...")
        print(f"SSH keys: {len(config['ssh_keys'])} key(s)")

        # Simulate bootstrap process
        print("\\nSimulating bootstrap process...")
        time.sleep(2)

        # Confirm successful bootstrap
        print("Confirming bootstrap completion...")
        confirm_result = client.confirm_bootstrap(
            DEVICE_SERIAL,
            hostname,
            "success"
        )

        print(f"Confirmation successful: {confirm_result['message']}")

    except Exception as e:
        print(f"Error: {e}")

        # Confirm failed bootstrap
        try:
            client.confirm_bootstrap(
                DEVICE_SERIAL,
                hostname if 'hostname' in locals() else "unknown",
                "failure",
                str(e)
            )
        except:
            pass

if __name__ == "__main__":
    example_usage()
