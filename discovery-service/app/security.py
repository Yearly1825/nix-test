import hmac
import hashlib
import time
from typing import Dict, Any
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt
from cryptography.hazmat.primitives import hashes
import secrets
import json
import base64

class SecurityManager:
    """Handles all security operations for the discovery service"""

    def __init__(self, psk: str):
        self.psk = psk.encode() if isinstance(psk, str) else psk

    def verify_signature(self, data: str, signature: str, timestamp: int, window_seconds: int = 300) -> bool:
        """Verify HMAC signature with timestamp validation"""

        # Check timestamp window
        current_time = int(time.time())
        if abs(current_time - timestamp) > window_seconds:
            return False

        # Calculate expected signature
        message = f"{data}:{timestamp}".encode()
        expected_signature = hmac.new(
            self.psk,
            message,
            hashlib.sha256
        ).hexdigest()

        # Constant-time comparison
        return hmac.compare_digest(signature, expected_signature)

    def create_signature(self, data: str, timestamp: int = None) -> tuple[str, int]:
        """Create HMAC signature for data with timestamp"""
        if timestamp is None:
            timestamp = int(time.time())

        message = f"{data}:{timestamp}".encode()
        signature = hmac.new(
            self.psk,
            message,
            hashlib.sha256
        ).hexdigest()

        return signature, timestamp

    def derive_device_key(self, device_serial: str, salt_size: int = 32) -> tuple[bytes, bytes]:
        """Derive device-specific encryption key using Scrypt KDF"""
        salt = device_serial.encode().ljust(salt_size, b'\x00')[:salt_size]

        kdf = Scrypt(
            algorithm=hashes.SHA256(),
            length=32,  # AES-256 key size
            salt=salt,
            n=2**14,    # CPU/memory cost
            r=8,        # Block size
            p=1,        # Parallelization
        )

        key = kdf.derive(self.psk)
        return key, salt

    def encrypt_payload(self, data: Dict[str, Any], device_serial: str) -> str:
        """Encrypt payload for specific device using AES-256-GCM"""
        key, salt = self.derive_device_key(device_serial)

        # Generate random nonce
        nonce = secrets.token_bytes(12)  # 96-bit nonce for GCM

        # Encrypt data
        plaintext = json.dumps(data).encode()
        cipher = Cipher(algorithms.AES(key), modes.GCM(nonce))
        encryptor = cipher.encryptor()
        ciphertext = encryptor.update(plaintext) + encryptor.finalize()

        # Combine nonce + ciphertext + tag
        encrypted_payload = nonce + ciphertext + encryptor.tag

        # Base64 encode for transport
        return base64.b64encode(encrypted_payload).decode()

    def decrypt_payload(self, encrypted_data: str, device_serial: str) -> Dict[str, Any]:
        """Decrypt payload for specific device"""
        key, salt = self.derive_device_key(device_serial)

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

    def verify_registration_request(self, serial: str, mac: str, signature: str,
                                   timestamp: int, window_seconds: int = 300) -> bool:
        """Verify device registration request"""
        data = f"{serial}:{mac}"
        return self.verify_signature(data, signature, timestamp, window_seconds)

    def verify_confirmation_request(self, serial: str, hostname: str, signature: str,
                                   timestamp: int, window_seconds: int = 300) -> bool:
        """Verify device confirmation request"""
        data = f"{serial}:{hostname}"
        return self.verify_signature(data, signature, timestamp, window_seconds)
