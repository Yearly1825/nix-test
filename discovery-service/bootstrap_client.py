#!/usr/bin/env python3
"""
Discovery service client for Raspberry Pi bootstrap process.
This script handles secure registration and configuration retrieval.

Production features:
- Robust device information detection with multiple fallbacks
- Network retry logic with exponential backoff
- Verbose logging for debugging
- Configuration file output for NixOS integration
- Graceful error handling and recovery
"""

import os
import sys
import json
import time
import hmac
import hashlib
import base64
import subprocess
import argparse
import logging
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
    """Client for discovery service integration with production features"""

    def __init__(self, server_url: str, psk: str, max_retries: int = 3, timeout: int = 30):
        self.server_url = server_url.rstrip('/')
        self.psk = psk.encode() if isinstance(psk, str) else psk
        self.max_retries = max_retries
        self.timeout = timeout
        self.logger = logging.getLogger(__name__)

    def _create_signature(self, data: str) -> str:
        """Create HMAC signature for data (simplified - no timestamp)"""
        signature = hmac.new(self.psk, data.encode(), hashlib.sha256).hexdigest()
        return signature

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

    def _make_request_with_retry(self, method: str, url: str, **kwargs) -> requests.Response:
        """Make HTTP request with exponential backoff retry logic"""
        for attempt in range(self.max_retries):
            try:
                self.logger.debug(f"Attempt {attempt + 1}/{self.max_retries}: {method} {url}")
                response = requests.request(method, url, timeout=self.timeout, **kwargs)
                response.raise_for_status()
                return response
            except (requests.exceptions.RequestException, requests.exceptions.Timeout) as e:
                if attempt == self.max_retries - 1:
                    self.logger.error(f"All {self.max_retries} attempts failed: {e}")
                    raise

                wait_time = 2 ** attempt  # Exponential backoff: 1s, 2s, 4s
                self.logger.warning(f"Attempt {attempt + 1} failed: {e}. Retrying in {wait_time}s...")
                time.sleep(wait_time)

    def register_device(self, serial: str, mac: str) -> Dict[str, Any]:
        """Register device with discovery service with retry logic"""
        self.logger.info(f"Registering device {serial} with MAC {mac}")

        # Create signature
        data = f"{serial}:{mac}"
        signature = self._create_signature(data)

        # Prepare request
        payload = {
            "serial": serial,
            "mac": mac,
            "signature": signature
        }

        # Make request with retry
        response = self._make_request_with_retry(
            "POST",
            f"{self.server_url}/register",
            json=payload
        )

        result = response.json()
        self.logger.debug(f"Registration response: {result}")

        # Decrypt configuration
        config = self._decrypt_payload(result['encrypted_config'], serial)
        self.logger.info(f"Successfully registered as hostname: {result['hostname']}")

        return {
            'hostname': result['hostname'],
            'netbird_setup_key': config['netbird_setup_key'],
            'ssh_keys': config['ssh_keys'],
            'ntfy_config': config.get('ntfy_config'),
            'config_timestamp': config['timestamp']
        }

    def confirm_bootstrap(self, serial: str, hostname: str, status: str, error_message: str = None):
        """Confirm bootstrap completion with retry logic"""
        self.logger.info(f"Confirming bootstrap for {hostname} ({serial}): {status}")

        # Create signature
        data = f"{serial}:{hostname}"
        signature = self._create_signature(data)

        # Prepare request
        payload = {
            "serial": serial,
            "hostname": hostname,
            "signature": signature,
            "status": status,
            "error_message": error_message
        }

        # Make request with retry
        try:
            response = self._make_request_with_retry(
                "POST",
                f"{self.server_url}/confirm",
                json=payload
            )
            result = response.json()
            self.logger.info(f"Bootstrap confirmation successful for {hostname}")
            return result
        except Exception as e:
            self.logger.warning(f"Failed to confirm bootstrap status: {e}")
            return None

def get_device_info() -> Dict[str, str]:
    """Get device serial number and MAC address with multiple fallback methods"""
    logger = logging.getLogger(__name__)

    def get_serial() -> str:
        """Get device serial number with multiple fallback methods"""
        logger.debug("Attempting to detect device serial number")

        # Method 1: Device tree serial number (Raspberry Pi)
        serial_paths = [
            "/sys/firmware/devicetree/base/serial-number",
            "/proc/device-tree/serial-number"
        ]

        for path in serial_paths:
            if os.path.exists(path):
                try:
                    with open(path, 'r') as f:
                        serial = f.read().strip('\x00\n')
                        if serial:
                            logger.debug(f"Found serial from {path}: {serial}")
                            return serial
                except Exception as e:
                    logger.debug(f"Failed to read {path}: {e}")
                    continue

        # Method 2: CPU serial from /proc/cpuinfo
        try:
            with open("/proc/cpuinfo", 'r') as f:
                for line in f:
                    if line.startswith("Serial"):
                        serial = line.split(":")[-1].strip()
                        if serial and serial != "0000000000000000":
                            logger.debug(f"Found CPU serial: {serial}")
                            return serial
        except Exception as e:
            logger.debug(f"Failed to read /proc/cpuinfo: {e}")

        # Method 3: DMI product serial (x86/virtual machines)
        dmi_paths = [
            "/sys/class/dmi/id/product_serial",
            "/sys/class/dmi/id/board_serial"
        ]

        for path in dmi_paths:
            if os.path.exists(path):
                try:
                    with open(path, 'r') as f:
                        serial = f.read().strip()
                        if serial and serial not in ["", "Not Specified", "To Be Filled By O.E.M."]:
                            logger.debug(f"Found DMI serial from {path}: {serial}")
                            return serial
                except Exception as e:
                    logger.debug(f"Failed to read {path}: {e}")

        # Method 4: Machine ID as fallback
        machine_id_paths = ["/etc/machine-id", "/var/lib/dbus/machine-id"]
        for path in machine_id_paths:
            if os.path.exists(path):
                try:
                    with open(path, 'r') as f:
                        machine_id = f.read().strip()
                        if machine_id:
                            logger.warning(f"Using machine ID as serial fallback: {machine_id[:16]}...")
                            return machine_id
                except Exception as e:
                    logger.debug(f"Failed to read {path}: {e}")

        raise RuntimeError("Could not determine device serial number")

    def get_mac() -> str:
        """Get primary ethernet MAC address with fallback methods"""
        logger.debug("Attempting to detect primary MAC address")

        # Method 1: Try specific ethernet interfaces
        primary_interfaces = ['eth0', 'enp0s3', 'ens160', 'ens33']
        for interface in primary_interfaces:
            try:
                result = subprocess.run(['ip', 'link', 'show', interface],
                                      capture_output=True, text=True, check=True)
                for line in result.stdout.split('\n'):
                    if 'ether' in line:
                        mac = line.strip().split()[1]
                        logger.debug(f"Found MAC for {interface}: {mac}")
                        return mac
            except subprocess.CalledProcessError:
                logger.debug(f"Interface {interface} not found")
                continue

        # Method 2: Get first non-loopback ethernet interface
        try:
            result = subprocess.run(['ip', 'link', 'show'],
                                  capture_output=True, text=True, check=True)
            current_interface = None
            for line in result.stdout.split('\n'):
                # Look for interface name line
                if ': ' in line and 'state' in line.lower():
                    current_interface = line.split(':')[1].strip().split('@')[0]
                    if 'lo' in current_interface:  # Skip loopback
                        current_interface = None
                        continue
                # Look for MAC address line
                elif 'ether' in line and current_interface and 'LOOPBACK' not in line:
                    mac = line.strip().split()[1]
                    logger.debug(f"Found MAC for {current_interface}: {mac}")
                    return mac
        except Exception as e:
            logger.debug(f"Failed to parse ip link output: {e}")

        # Method 3: Read from /sys/class/net
        try:
            net_dir = Path("/sys/class/net")
            if net_dir.exists():
                for interface_dir in net_dir.iterdir():
                    if interface_dir.name.startswith(('eth', 'en')) and interface_dir.name != 'lo':
                        address_file = interface_dir / "address"
                        if address_file.exists():
                            mac = address_file.read_text().strip()
                            if mac and mac != "00:00:00:00:00:00":
                                logger.debug(f"Found MAC for {interface_dir.name}: {mac}")
                                return mac
        except Exception as e:
            logger.debug(f"Failed to read from /sys/class/net: {e}")

        raise RuntimeError("Could not determine device MAC address")

    try:
        device_info = {
            'serial': get_serial(),
            'mac': get_mac()
        }
        logger.info(f"Device detection successful - Serial: {device_info['serial']}, MAC: {device_info['mac']}")
        return device_info
    except Exception as e:
        logger.error(f"Device detection failed: {e}")
        raise

def setup_logging(verbose: bool = False):
    """Setup logging configuration"""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )

def write_nixos_config(config: Dict[str, Any], output_file: str = None):
    """Write configuration in format suitable for NixOS integration"""
    if output_file is None:
        output_file = "/var/lib/nixos-bootstrap/nixos_config.nix"

    output_path = Path(output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Format SSH keys for Nix
    ssh_keys_nix = '[\n    ' + '\n    '.join(f'"{key}"' for key in config['ssh_keys']) + '\n  ]'

    nix_config = f'''# Auto-generated NixOS configuration from discovery service
# Generated at: {time.strftime('%Y-%m-%d %H:%M:%S')}

{{
  # Hostname assigned by discovery service
  networking.hostName = "{config['hostname']}";

  # SSH keys from discovery service
  users.users.root.openssh.authorizedKeys.keys = {ssh_keys_nix};

  # Netbird VPN configuration
  services.netbird.enable = true;
  services.netbird.package = pkgs.netbird;

  # Environment variables for bootstrap scripts
  environment.variables = {{
    NETBIRD_SETUP_KEY = "{config['netbird_setup_key']}";
    DISCOVERY_HOSTNAME = "{config['hostname']}";
  }};
}}
'''

    with open(output_path, 'w') as f:
        f.write(nix_config)

    logging.getLogger(__name__).info(f"NixOS configuration written to {output_path}")
    return str(output_path)

def main():
    """Main bootstrap client function with argument parsing"""
    parser = argparse.ArgumentParser(
        description="Bootstrap client for discovery service registration",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s http://192.168.1.100:8080 your-psk-here
  %(prog)s --verbose --output /tmp/config.json http://discovery.local:8080 secret-key
  %(prog)s --nixos-config /etc/nixos/discovery.nix http://10.42.0.1:8080 psk123
        """
    )

    parser.add_argument('server_url', help='Discovery service URL')
    parser.add_argument('psk', help='Pre-shared key for authentication')
    parser.add_argument('-v', '--verbose', action='store_true', help='Enable verbose logging')
    parser.add_argument('-o', '--output', help='Output file for JSON configuration')
    parser.add_argument('--nixos-config', help='Output file for NixOS configuration')
    parser.add_argument('--retries', type=int, default=3, help='Number of retry attempts')
    parser.add_argument('--timeout', type=int, default=30, help='Request timeout in seconds')

    args = parser.parse_args()

    # Setup logging
    setup_logging(args.verbose)
    logger = logging.getLogger(__name__)

    try:
        # Get device information
        logger.info("🔍 Gathering device information...")
        device_info = get_device_info()
        serial = device_info['serial']
        mac = device_info['mac']

        print(f"📱 Device Serial: {serial}")
        print(f"🌐 MAC Address: {mac}")

        # Initialize client
        client = BootstrapClient(args.server_url, args.psk, args.retries, args.timeout)

        # Register with discovery service
        logger.info("🚀 Registering with discovery service...")
        config = client.register_device(serial, mac)

        hostname = config['hostname']
        netbird_key = config['netbird_setup_key']
        ssh_keys = config['ssh_keys']

        print(f"✅ Registration successful!")
        print(f"🏠 Assigned hostname: {hostname}")
        print(f"🔐 Netbird setup key: {netbird_key[:20]}...")
        print(f"🗝️  SSH keys: {len(ssh_keys)} key(s) received")

        # Save JSON configuration
        config_dir = Path("/var/lib/nixos-bootstrap")
        config_dir.mkdir(parents=True, exist_ok=True)

        json_config_file = args.output or str(config_dir / "discovery_config.json")
        with open(json_config_file, 'w') as f:
            json.dump(config, f, indent=2)

        logger.info(f"💾 JSON configuration saved to {json_config_file}")

        # Save NixOS configuration if requested
        nixos_config_file = None
        if args.nixos_config:
            nixos_config_file = write_nixos_config(config, args.nixos_config)

        # Output for shell script consumption
        print("---BOOTSTRAP_CONFIG_START---")
        print(f"HOSTNAME={hostname}")
        print(f"NETBIRD_SETUP_KEY={netbird_key}")
        print(f"SSH_KEYS_COUNT={len(ssh_keys)}")
        print(f"CONFIG_FILE={json_config_file}")
        if nixos_config_file:
            print(f"NIXOS_CONFIG_FILE={nixos_config_file}")
        print("---BOOTSTRAP_CONFIG_END---")

        return {
            'success': True,
            'hostname': hostname,
            'config_file': json_config_file,
            'nixos_config_file': nixos_config_file,
            'serial': serial
        }

    except Exception as e:
        logger.error(f"❌ Bootstrap client error: {e}")
        return {
            'success': False,
            'error': str(e),
            'serial': device_info.get('serial', 'unknown') if 'device_info' in locals() else 'unknown'
        }

if __name__ == "__main__":
    result = main()
    sys.exit(0 if result['success'] else 1)
