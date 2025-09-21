#!/usr/bin/env python3
"""
Simplified Discovery Service - Core Components
==============================================

Core business logic components without web framework dependencies.
Can be imported independently for testing and validation.
"""

import os
import sys
import time
import json
import hmac
import hashlib
import sqlite3
import logging
import secrets
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, Optional, List
from contextlib import contextmanager

import yaml
from pydantic import BaseModel, Field
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt
from cryptography.hazmat.primitives import hashes
import base64


# =============================================================================
# Configuration Models and Loading
# =============================================================================

class DeploymentConfig(BaseModel):
    name: str = Field(..., description="Hostname prefix")
    environment: str = Field("production", description="Environment identifier")
    description: str = Field("", description="Deployment description")

class DiscoveryServiceConfig(BaseModel):
    ip: str = Field("10.42.0.1", description="Discovery service IP")
    port: int = Field(8080, description="Discovery service port")
    psk: str = Field(..., description="Pre-shared key for authentication")

class NetbirdConfig(BaseModel):
    setup_key: str = Field(..., description="Netbird VPN setup key")

class APIConfig(BaseModel):
    host: str = Field("0.0.0.0", description="API host")
    port: int = Field(8080, description="API port")

class DatabaseConfig(BaseModel):
    file: str = Field("data/registrations.db", description="SQLite database file")

class NTFYConfig(BaseModel):
    enabled: bool = Field(False, description="Enable NTFY notifications")
    url: str = Field("", description="NTFY topic URL")
    priority: str = Field("default", description="Message priority")
    tags: List[str] = Field(default_factory=lambda: ["raspberry-pi", "bootstrap"])

class Config(BaseModel):
    deployment: DeploymentConfig
    discovery_service: DiscoveryServiceConfig
    netbird: NetbirdConfig
    ssh_keys: List[str] = Field(default_factory=list, description="SSH public keys")
    api: APIConfig
    database: DatabaseConfig
    ntfy: NTFYConfig

def load_config(config_path: str = None) -> Config:
    """Load configuration from unified deployment YAML file"""
    if config_path is None:
        # Auto-detect configuration file location
        possible_paths = [
            "/app/parent/.deployment.yaml",  # Docker environment
            "../.deployment.yaml",           # Local development
            ".deployment.yaml"               # Same directory
        ]

        config_file = None
        for path in possible_paths:
            if Path(path).exists():
                config_file = Path(path)
                break

        if config_file is None:
            raise FileNotFoundError(
                "Configuration file not found. Please create configuration: cd .. && python3 setup_deployment.py"
            )
    else:
        config_file = Path(config_path)
        if not config_file.exists():
            raise FileNotFoundError(f"Configuration file not found: {config_path}")

    with open(config_file, 'r') as f:
        config_data = yaml.safe_load(f)

    # Transform unified config format to discovery service format
    if 'discovery_service' in config_data:
        # This is the new unified format
        transformed_config = {
            'deployment': config_data.get('deployment', {}),
            'discovery_service': config_data.get('discovery_service', {}),
            'netbird': config_data.get('netbird', {}),
            'ssh_keys': config_data.get('ssh_keys', []),
            'api': {
                'host': '0.0.0.0',  # Always bind to all interfaces in container
                'port': config_data.get('discovery_service', {}).get('port', 8080)
            },
            'database': config_data.get('database', {}),
            'ntfy': config_data.get('ntfy', {})
        }
        config_data = transformed_config

    return Config(**config_data)


# =============================================================================
# Request/Response Models
# =============================================================================

class RegistrationRequest(BaseModel):
    """Device registration request (simplified - no timestamp)"""
    serial: str = Field(..., description="Device serial number")
    mac: str = Field(..., description="Device MAC address")
    signature: str = Field(..., description="HMAC signature")

class RegistrationResponse(BaseModel):
    """Device registration response"""
    hostname: str = Field(..., description="Assigned hostname")
    encrypted_config: str = Field(..., description="Encrypted configuration bundle")
    success: bool = Field(True, description="Registration success status")
    message: str = Field("Registration successful", description="Status message")

class ConfirmationRequest(BaseModel):
    """Device confirmation request (simplified - no timestamp)"""
    serial: str = Field(..., description="Device serial number")
    hostname: str = Field(..., description="Assigned hostname")
    signature: str = Field(..., description="HMAC signature")
    status: str = Field(..., description="Bootstrap status (success/failure)")
    error_message: Optional[str] = Field(None, description="Error message if bootstrap failed")

class ConfirmationResponse(BaseModel):
    """Device confirmation response"""
    success: bool = Field(True, description="Confirmation received")
    message: str = Field("Confirmation received", description="Status message")

class HealthResponse(BaseModel):
    """Health check response"""
    status: str = Field("healthy", description="Service status")
    version: str = Field("1.0.0", description="Service version")
    uptime_seconds: float = Field(..., description="Service uptime in seconds")
    total_registrations: int = Field(..., description="Total successful registrations")

class StatsResponse(BaseModel):
    """Statistics response"""
    total_registrations: int = Field(..., description="Total registrations")
    confirmed_devices: int = Field(..., description="Confirmed device bootstraps")
    last_registration: Optional[datetime] = Field(None, description="Last registration time")


# =============================================================================
# Simplified Security Manager
# =============================================================================

class SecurityManager:
    """Simplified security operations for the discovery service"""

    def __init__(self, psk: str):
        self.psk = psk.encode() if isinstance(psk, str) else psk

    def verify_signature(self, data: str, signature: str) -> bool:
        """Verify HMAC signature (simplified - no timestamp validation)"""
        expected_signature = hmac.new(
            self.psk,
            data.encode(),
            hashlib.sha256
        ).hexdigest()

        # Constant-time comparison
        return hmac.compare_digest(signature, expected_signature)

    def derive_device_key(self, device_serial: str, salt_size: int = 32) -> bytes:
        """Derive device-specific encryption key using Scrypt KDF"""
        salt = device_serial.encode().ljust(salt_size, b'\x00')[:salt_size]

        kdf = Scrypt(
            length=32,  # AES-256 key size
            salt=salt,
            n=2**14,    # CPU/memory cost
            r=8,        # Block size
            p=1,        # Parallelization
        )

        return kdf.derive(self.psk)

    def encrypt_payload(self, data: Dict[str, Any], device_serial: str) -> str:
        """Encrypt payload for specific device using AES-256-GCM"""
        key = self.derive_device_key(device_serial)

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

    def verify_registration_request(self, serial: str, mac: str, signature: str) -> bool:
        """Verify device registration request (simplified)"""
        data = f"{serial}:{mac}"
        return self.verify_signature(data, signature)

    def verify_confirmation_request(self, serial: str, hostname: str, signature: str) -> bool:
        """Verify device confirmation request (simplified)"""
        data = f"{serial}:{hostname}"
        return self.verify_signature(data, signature)


# =============================================================================
# Simplified Database Manager
# =============================================================================

class DatabaseManager:
    """Simplified SQLite database operations for device registrations"""

    def __init__(self, db_path: str):
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_database()

    def _init_database(self):
        """Initialize simplified database schema (single table)"""
        with self._get_connection() as conn:
            # Create table
            conn.execute("""
                CREATE TABLE IF NOT EXISTS registrations (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    serial TEXT UNIQUE NOT NULL,
                    mac TEXT NOT NULL,
                    hostname TEXT UNIQUE NOT NULL,
                    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    confirmed_at TIMESTAMP NULL,
                    status TEXT DEFAULT 'pending'
                )
            """)

            # Create indexes separately
            conn.execute("CREATE INDEX IF NOT EXISTS idx_registrations_serial ON registrations(serial)")
            conn.execute("CREATE INDEX IF NOT EXISTS idx_registrations_hostname ON registrations(hostname)")

    @contextmanager
    def _get_connection(self):
        """Context manager for database connections"""
        conn = sqlite3.connect(self.db_path, timeout=30.0)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def get_next_hostname(self, prefix: str) -> str:
        """Get next available hostname with given prefix (simplified logic)"""
        with self._get_connection() as conn:
            # Find highest existing counter for this prefix
            result = conn.execute(
                "SELECT hostname FROM registrations WHERE hostname LIKE ? ORDER BY hostname DESC LIMIT 1",
                (f"{prefix}-%",)
            ).fetchone()

            if result:
                # Extract counter from last hostname
                try:
                    last_hostname = result['hostname']
                    counter_part = last_hostname.split('-')[-1]
                    counter = int(counter_part) + 1
                except (ValueError, IndexError):
                    counter = 1
            else:
                counter = 1

            return f"{prefix}-{counter:02d}"

    def register_device(self, serial: str, mac: str, hostname: str) -> bool:
        """Register a new device (simplified)"""
        try:
            with self._get_connection() as conn:
                conn.execute("""
                    INSERT INTO registrations (serial, mac, hostname)
                    VALUES (?, ?, ?)
                """, (serial, mac, hostname))
                return True
        except sqlite3.IntegrityError:
            # Device already registered
            return False

    def confirm_device(self, serial: str, status: str) -> bool:
        """Confirm device bootstrap completion"""
        with self._get_connection() as conn:
            cursor = conn.execute("""
                UPDATE registrations
                SET confirmed_at = CURRENT_TIMESTAMP, status = ?
                WHERE serial = ?
            """, (status, serial))
            return cursor.rowcount > 0

    def get_device_by_serial(self, serial: str) -> Optional[Dict[str, Any]]:
        """Get device registration by serial number"""
        with self._get_connection() as conn:
            result = conn.execute(
                "SELECT * FROM registrations WHERE serial = ?", (serial,)
            ).fetchone()
            return dict(result) if result else None

    def get_statistics(self) -> Dict[str, Any]:
        """Get registration statistics"""
        with self._get_connection() as conn:
            # Total registrations
            total = conn.execute("SELECT COUNT(*) as count FROM registrations").fetchone()['count']

            # Confirmed devices
            confirmed = conn.execute("""
                SELECT COUNT(*) as count FROM registrations WHERE confirmed_at IS NOT NULL
            """).fetchone()['count']

            # Last registration
            last_reg = conn.execute("""
                SELECT registered_at FROM registrations ORDER BY registered_at DESC LIMIT 1
            """).fetchone()

            return {
                'total_registrations': total,
                'confirmed_devices': confirmed,
                'last_registration': datetime.fromisoformat(last_reg['registered_at']) if last_reg else None
            }


# =============================================================================
# Simplified NTFY Notifier
# =============================================================================

class NTFYNotifier:
    """Simplified NTFY notification service"""

    def __init__(self, config):
        self.config = config.ntfy
        self.enabled = self.config.enabled and self.config.url

        # Try to import httpx, disable notifications if not available
        try:
            import httpx
            self.httpx = httpx
        except ImportError:
            self.enabled = False
            self.httpx = None
            if self.config.enabled:
                logging.warning("httpx not available, NTFY notifications disabled")

    async def send_notification(self, title: str, message: str):
        """Send notification to NTFY service (simplified)"""
        if not self.enabled or not self.httpx:
            return

        headers = {
            "Title": title,
            "Priority": self.config.priority,
            "Tags": ",".join(self.config.tags) if self.config.tags else ""
        }

        try:
            async with self.httpx.AsyncClient(timeout=10) as client:
                response = await client.post(
                    self.config.url,
                    content=message,
                    headers=headers
                )
                response.raise_for_status()
        except Exception as e:
            # Don't let notification failures break the main flow
            logging.warning(f"NTFY notification failed: {e}")

    async def notify_registration(self, hostname: str, serial: str):
        """Notify successful device registration"""
        title = "New Device Registered"
        message = f"Device: {hostname}\nSerial: {serial}\nStatus: Bootstrapping..."
        await self.send_notification(title, message)

    async def notify_confirmation(self, hostname: str, serial: str, status: str):
        """Notify device bootstrap confirmation"""
        if status == "success":
            title = "Device Bootstrap Complete"
            message = f"Device: {hostname}\nSerial: {serial}\nStatus: Bootstrap successful!"
        else:
            title = "Device Bootstrap Failed"
            message = f"Device: {hostname}\nSerial: {serial}\nStatus: Bootstrap failed"
        await self.send_notification(title, message)
