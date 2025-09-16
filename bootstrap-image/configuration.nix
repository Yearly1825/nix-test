{ config, pkgs, lib, discoveryPsk ? "CHANGE_ME_TO_YOUR_PSK", discoveryServiceIp ? "192.168.1.100", configRepoUrl ? "github:yourusername/nixos-pi-configs", ... }:
{
  # Add this at the top level (not inside boot = {})
  nixpkgs.overlays = [(final: prev: {
    makeModulesClosure = x: prev.makeModulesClosure (x // {
      allowMissing = true;
    });
  })];

  system.stateVersion = "24.05";
  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
    kernelModules = [ "bcm2835-v4l2" ];
    growPartition = true;
    # Add these lines:
    initrd.includeDefaultModules = false;
    initrd.availableKernelModules = [
      "mmc_block" "usbhid" "usb_storage" "uas"
      "ext4" "crc32c"
    ];
  };
  sdImage.firmwareSize = 512;  # 512MB boot partition - plenty of space for kernels
  nix = {
    package = pkgs.nixVersions.stable;
    settings.experimental-features = [ "nix-command" "flakes" ];
    # Automatic garbage collection to prevent boot partition filling up
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # Limit number of generations to keep boot partition clean
  boot.loader.generic-extlinux-compatible.configurationLimit = 3;
#
  networking.hostName = "pi-bootstrap";

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  users.users.root.initialPassword = "bootstrap";

  # UPDATED: Add Python dependencies for discovery service and pre-install sensor tools
  environment.systemPackages = with pkgs; [
    git
    curl
    jq
    wget
    vim
    htop
    tmux
    # Discovery service dependencies
    python3
    python3Packages.requests
    python3Packages.cryptography
    python3Packages.pip

    # Pre-installed network monitoring tools (speeds up bootstrap)
    kismet
    aircrack-ng
    hcxdumptool
    hcxtools
    tcpdump
    wireshark-cli  # provides tshark
    nmap
    iftop
    netcat-gnu

    # GPS support
    gpsd

    # Additional system tools
    iotop
    nethogs
  ];

  # UPDATED: Create bootstrap script with injected PSK
  environment.etc."bootstrap/bootstrap.sh" = {
    text = ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      # ========================================
      # Configuration - INJECTED AT BUILD TIME
      # ========================================

      # Discovery service configuration
      DISCOVERY_SERVICE_IP="${discoveryServiceIp}"
      DISCOVERY_SERVICE_PORT="8080"
      DISCOVERY_PSK="${discoveryPsk}"

      # NixOS configuration
      CONFIG_REPO_URL="${configRepoUrl}"
      CONFIG_FLAKE_TARGET="sensor"

      # Retry configuration
      MAX_RETRIES=10
      RETRY_DELAY=10
      NETWORK_TIMEOUT=300

      # ========================================
      # Logging and utilities
      # ========================================

      # Color output for visibility
      RED='\033[0;31m'
      GREEN='\033[0;32m'
      YELLOW='\033[1;33m'
      BLUE='\033[0;34m'
      NC='\033[0m' # No Color

      log_info() { echo -e "''${GREEN}[INFO]''${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
      log_warn() { echo -e "''${YELLOW}[WARN]''${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
      log_error() { echo -e "''${RED}[ERROR]''${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
      log_debug() { echo -e "''${BLUE}[DEBUG]''${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }

      # ========================================
      # Network and connectivity functions
      # ========================================

      wait_for_network() {
          log_info "Waiting for network connectivity..."

          local start_time=$(date +%s)
          local attempts=0

          while true; do
              attempts=$((attempts + 1))
              local current_time=$(date +%s)
              local elapsed=$((current_time - start_time))

              if [ $elapsed -gt $NETWORK_TIMEOUT ]; then
                  log_error "Network timeout after ''${NETWORK_TIMEOUT} seconds"
                  return 1
              fi

              # Check multiple connectivity methods
              if ping -c1 -W5 8.8.8.8 &>/dev/null || \
                 ping -c1 -W5 1.1.1.1 &>/dev/null || \
                 ping -c1 -W5 $DISCOVERY_SERVICE_IP &>/dev/null; then
                  log_info "Network connectivity established (attempt $attempts)"
                  return 0
              fi

              log_warn "Waiting for network... (attempt $attempts, elapsed ''${elapsed}s)"
              sleep 5
          done
      }

      sync_time() {
          log_info "Synchronizing system time..."

          # Try NTP sync first if available
          if systemctl is-active --quiet systemd-timesyncd; then
              log_info "Attempting NTP synchronization..."
              # Give NTP a chance to sync (up to 30 seconds)
              local ntp_attempts=0
              while [ $ntp_attempts -lt 6 ]; do
                  if timedatectl status | grep -q "System clock synchronized: yes"; then
                      log_info "NTP synchronization successful"
                      return 0
                  fi
                  sleep 5
                  ntp_attempts=$((ntp_attempts + 1))
              done
              log_warn "NTP synchronization timed out"
          fi

          # Fallback: Get time from discovery service
          log_info "Attempting time sync from discovery service..."
          if curl -s --max-time 10 "http://''${DISCOVERY_SERVICE_IP}:''${DISCOVERY_SERVICE_PORT}/health" >/dev/null 2>&1; then
              # Get current time from HTTP Date header
              local server_date=$(curl -s -I --max-time 5 "http://''${DISCOVERY_SERVICE_IP}:''${DISCOVERY_SERVICE_PORT}/health" | grep -i '^date:' | cut -d' ' -f2-)
              if [ -n "$server_date" ]; then
                  if date -s "$server_date" >/dev/null 2>&1; then
                      log_info "Time synchronized from discovery service: $(date)"
                      return 0
                  fi
              fi
          fi

          # Last resort: Set a reasonable time if we're way off
          local current_timestamp=$(date +%s)
          local year_2024_timestamp=1704067200  # Jan 1, 2024

          if [ $current_timestamp -lt $year_2024_timestamp ]; then
              log_warn "System time appears to be before 2024, setting to reasonable default"
              date -s "2025-09-14 12:00:00" >/dev/null 2>&1
              log_info "Time set to: $(date)"
          else
              log_info "System time appears reasonable: $(date)"
          fi
      }

      # ========================================
      # Discovery service integration
      # ========================================

      call_discovery_service() {
          local server_url="http://''${DISCOVERY_SERVICE_IP}:''${DISCOVERY_SERVICE_PORT}"
          local python_script="/tmp/bootstrap_client.py"

          # Create inline Python client
          create_inline_bootstrap_client "$python_script"
          chmod +x "$python_script"

          # Call the Python client
          log_info "Calling discovery service client..."
          if python3 "$python_script" "$server_url" "$DISCOVERY_PSK" > /tmp/bootstrap_output.txt 2>&1; then
              return 0
          else
              log_error "Discovery service client failed:"
              cat /tmp/bootstrap_output.txt
              return 1
          fi
      }

      create_inline_bootstrap_client() {
          local script_path="$1"

          # Create the bootstrap client script inline
          cat > "$script_path" << 'EOF'
      #!/usr/bin/env python3
      """
      Embedded bootstrap client for discovery service
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
      from typing import Dict, Any

      import requests
      from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
      from cryptography.hazmat.primitives.kdf.scrypt import Scrypt
      from cryptography.hazmat.primitives import hashes

      class BootstrapClient:
          def __init__(self, server_url: str, psk: str):
              self.server_url = server_url.rstrip('/')
              self.psk = psk.encode() if isinstance(psk, str) else psk

          def _create_signature(self, data: str, timestamp: int = None):
              if timestamp is None:
                  timestamp = int(time.time())
              message = f"{data}:{timestamp}".encode()
              signature = hmac.new(self.psk, message, hashlib.sha256).hexdigest()
              return signature, timestamp

          def _derive_device_key(self, device_serial: str):
              salt = device_serial.encode().ljust(32, b'\x00')[:32]
              kdf = Scrypt(length=32, salt=salt, n=2**14, r=8, p=1)
              return kdf.derive(self.psk)

          def _decrypt_payload(self, encrypted_data: str, device_serial: str):
              key = self._derive_device_key(device_serial)
              encrypted_payload = base64.b64decode(encrypted_data.encode())
              nonce = encrypted_payload[:12]
              tag = encrypted_payload[-16:]
              ciphertext = encrypted_payload[12:-16]
              cipher = Cipher(algorithms.AES(key), modes.GCM(nonce, tag))
              decryptor = cipher.decryptor()
              plaintext = decryptor.update(ciphertext) + decryptor.finalize()
              return json.loads(plaintext.decode())

          def register_device(self, serial: str, mac: str):
              data = f"{serial}:{mac}"
              signature, timestamp = self._create_signature(data)
              payload = {"serial": serial, "mac": mac, "signature": signature, "timestamp": timestamp}
              response = requests.post(f"{self.server_url}/register", json=payload, timeout=30)
              response.raise_for_status()
              result = response.json()
              config = self._decrypt_payload(result['encrypted_config'], serial)
              return {'hostname': result['hostname'], 'netbird_setup_key': config['netbird_setup_key'], 'ssh_keys': config['ssh_keys']}

          def confirm_bootstrap(self, serial: str, hostname: str, status: str, error_message: str = None):
              data = f"{serial}:{hostname}"
              signature, timestamp = self._create_signature(data)
              payload = {"serial": serial, "hostname": hostname, "signature": signature, "timestamp": timestamp, "status": status, "error_message": error_message}
              try:
                  response = requests.post(f"{self.server_url}/confirm", json=payload, timeout=30)
                  response.raise_for_status()
                  return response.json()
              except Exception as e:
                  print(f"Warning: Failed to confirm bootstrap: {e}")
                  return None

      def get_device_info():
          def get_serial():
              paths = ["/sys/firmware/devicetree/base/serial-number", "/proc/device-tree/serial-number"]
              for path in paths:
                  if os.path.exists(path):
                      try:
                          with open(path, 'r') as f:
                              return f.read().strip('\x00\n')
                      except: continue
              with open("/proc/cpuinfo", 'r') as f:
                  for line in f:
                      if line.startswith("Serial"):
                          return line.split(":")[-1].strip()
              raise RuntimeError("Could not determine serial number")

          def get_mac():
              result = subprocess.run(['ip', 'link', 'show'], capture_output=True, text=True, check=True)
              for line in result.stdout.split('\n'):
                  if 'ether' in line and 'LOOPBACK' not in line:
                      return line.strip().split()[1]
              raise RuntimeError("Could not determine MAC address")

          return {'serial': get_serial(), 'mac': get_mac()}

      def main():
          if len(sys.argv) != 3:
              print("Usage: bootstrap_client.py <server_url> <psk>")
              sys.exit(1)

          server_url, psk = sys.argv[1], sys.argv[2]

          try:
              device_info = get_device_info()
              client = BootstrapClient(server_url, psk)
              config = client.register_device(device_info['serial'], device_info['mac'])

              config_dir = Path("/var/lib/nixos-bootstrap")
              config_dir.mkdir(parents=True, exist_ok=True)
              config_file = config_dir / "discovery_config.json"

              with open(config_file, 'w') as f:
                  json.dump({**config, 'serial': device_info['serial']}, f, indent=2)

              print("---BOOTSTRAP_CONFIG_START---")
              print(f"HOSTNAME={config['hostname']}")
              print(f"NETBIRD_SETUP_KEY={config['netbird_setup_key']}")
              print(f"SSH_KEYS_COUNT={len(config['ssh_keys'])}")
              print(f"CONFIG_FILE={config_file}")
              print(f"DEVICE_SERIAL={device_info['serial']}")
              print("---BOOTSTRAP_CONFIG_END---")

          except Exception as e:
              print(f"Error: {e}")
              sys.exit(1)

      if __name__ == "__main__":
          main()
      EOF

          chmod +x "$script_path"
      }

      parse_bootstrap_config() {
          local output_file="/tmp/bootstrap_output.txt"
          local config_started=false

          while IFS= read -r line; do
              if [[ "$line" == "---BOOTSTRAP_CONFIG_START---" ]]; then
                  config_started=true
                  continue
              elif [[ "$line" == "---BOOTSTRAP_CONFIG_END---" ]]; then
                  config_started=false
                  break
              elif [ "$config_started" = true ]; then
                  # Export the configuration variables
                  export "$line"
                  log_debug "Exported: $line"
              fi
          done < "$output_file"

          # Validate required variables
          if [ -z "''${HOSTNAME:-}" ] || [ -z "''${NETBIRD_SETUP_KEY:-}" ] || [ -z "''${CONFIG_FILE:-}" ]; then
              log_error "Missing required configuration from discovery service"
              return 1
          fi
      }

      confirm_bootstrap_status() {
          local status="$1"
          local error_message="''${2:-}"

          log_info "Confirming bootstrap status: $status"

          if [ -f "''${CONFIG_FILE:-}" ]; then
              local server_url="http://''${DISCOVERY_SERVICE_IP}:''${DISCOVERY_SERVICE_PORT}"

              # Create a simple confirmation script
              cat > /tmp/confirm_bootstrap.py << 'EOFPYTHON'
      import json
      import sys
      import subprocess

      # Re-use the embedded client
      sys.path.append('/tmp')
      try:
          from bootstrap_client import BootstrapClient

          with open("''${CONFIG_FILE}", 'r') as f:
              config = json.load(f)

          client = BootstrapClient("''${server_url}", "''${DISCOVERY_PSK}")
          result = client.confirm_bootstrap(
              config['serial'],
              config['hostname'],
              "''${status}",
              """''${error_message}"""
          )
          print(f"Confirmation result: {result}")
      except Exception as e:
          print(f"Confirmation failed: {e}")
      EOFPYTHON

              python3 /tmp/confirm_bootstrap.py || log_warn "Failed to confirm bootstrap status"
          fi
      }

      # ========================================
      # SSH key management
      # ========================================

      setup_ssh_keys() {
          local config_file="''${CONFIG_FILE:-}"

          if [ -z "$config_file" ] || [ ! -f "$config_file" ]; then
              log_warn "No configuration file found, skipping SSH key setup"
              return 0
          fi

          log_info "Setting up SSH keys..."

          # Extract SSH keys from config file
          local ssh_keys=$(python3 -c "
      import json
      with open('$config_file', 'r') as f:
          config = json.load(f)
      for key in config.get('ssh_keys', []):
          print(key)
          ")

          if [ -n "$ssh_keys" ]; then
              # Create .ssh directory for root (bootstrap user)
              mkdir -p /root/.ssh
              chmod 700 /root/.ssh

              # Add keys to authorized_keys
              echo "$ssh_keys" > /root/.ssh/authorized_keys
              chmod 600 /root/.ssh/authorized_keys

              local key_count=$(echo "$ssh_keys" | wc -l)
              log_info "Configured $key_count SSH key(s)"
          else
              log_warn "No SSH keys found in configuration"
          fi
      }

      # ========================================
      # Main bootstrap process
      # ========================================

      cleanup() {
          log_info "Cleaning up temporary files..."
          rm -f /tmp/bootstrap_*.py /tmp/bootstrap_output.txt /tmp/confirm_bootstrap.py
      }

      # Set trap for cleanup
      trap cleanup EXIT

      main() {
          log_info "🚀 Starting Raspberry Pi Discovery Bootstrap Process"
          log_info "================================================="

          # Validate configuration
          if [ "$DISCOVERY_PSK" == "CHANGE_ME_TO_YOUR_PSK" ]; then
              log_error "PSK not configured! Please update the DISCOVERY_PSK variable."
              exit 1
          fi

          # Wait for network connectivity
          if ! wait_for_network; then
              log_error "Failed to establish network connectivity"
              exit 1
          fi

          # Synchronize system time
          sync_time

          # Call discovery service
          log_info "📡 Registering with discovery service..."
          for attempt in $(seq 1 $MAX_RETRIES); do
              if call_discovery_service; then
                  log_info "✅ Discovery service registration successful"
                  break
              else
                  if [ $attempt -eq $MAX_RETRIES ]; then
                      log_error "❌ Failed to register with discovery service after $MAX_RETRIES attempts"
                      confirm_bootstrap_status "failure" "Discovery service registration failed"
                      exit 1
                  fi
                  log_warn "⚠️  Registration attempt $attempt failed, retrying in ''${RETRY_DELAY}s..."
                  sleep $RETRY_DELAY
              fi
          done

          # Parse configuration from discovery service
          if ! parse_bootstrap_config; then
              confirm_bootstrap_status "failure" "Failed to parse discovery service configuration"
              exit 1
          fi

          log_info "🏠 Assigned hostname: $HOSTNAME"
          log_info "🔐 Netbird setup key received"
          log_info "🗝️  SSH keys: $SSH_KEYS_COUNT key(s)"

          # Note: Hostname will be set by NixOS configuration, not hostnamectl
          log_info "⚙️  Hostname will be set to: $HOSTNAME (via NixOS config)"

          # Setup SSH keys
          setup_ssh_keys

          # Apply NixOS configuration
          log_info "📦 Applying NixOS configuration..."

          # Set environment variables for NixOS configuration
          export NETBIRD_SETUP_KEY="$NETBIRD_SETUP_KEY"
          export ASSIGNED_HOSTNAME="$HOSTNAME"

          # Check disk space before nixos-rebuild
          df -h > /var/log/bootstrap-disk-before.log 2>&1

          log_info "💾 Disk space before rebuild: $(df -h / | tail -1 | awk '{print $4 " available"}')"
          log_info "💾 Boot space before rebuild: $(df -h /boot | tail -1 | awk '{print $4 " available"}')"

          if nixos-rebuild switch \
              --install-bootloader \
              --flake "''${CONFIG_REPO_URL}#''${CONFIG_FLAKE_TARGET}" \
              --option substituters "https://cache.nixos.org" \
              --option trusted-public-keys "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" \
              --no-write-lock-file \
              --show-trace 2>&1 | tee /var/log/bootstrap-nixos-rebuild.log; then

              log_info "✅ NixOS configuration applied successfully"
              confirm_bootstrap_status "success"
              log_info "🎉 Bootstrap process completed successfully!"
              log_info "🔄 System will reboot in 10 seconds..."

              # Save completion marker
              touch /var/lib/bootstrap-complete
              echo "$(date): Bootstrap completed successfully for $HOSTNAME" >> /var/lib/bootstrap.log

              # Reboot after short delay
              sleep 10
              systemctl reboot

          else
              log_error "❌ NixOS configuration failed"
              confirm_bootstrap_status "failure" "NixOS configuration application failed"
              exit 1
          fi
      }

      # ========================================
      # Script execution
      # ========================================

      # Check if running as root
      if [ "$EUID" -ne 0 ]; then
          log_error "This script must be run as root"
          exit 1
      fi

      # Check for required commands
      for cmd in curl python3 jq ip hostnamectl nixos-rebuild; do
          if ! command -v "$cmd" >/dev/null 2>&1; then
              log_error "Required command not found: $cmd"
              exit 1
          fi
      done

      # Run main function with error handling
      if ! main "$@"; then
          log_error "Bootstrap process failed"
          confirm_bootstrap_status "failure" "Bootstrap process encountered an error"
          exit 1
      fi
    '';
    mode = "0755";
  };

  # UPDATED: Improved systemd service with better error handling
  systemd.services.pi-bootstrap = {
    description = "Raspberry Pi Discovery Bootstrap Process";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    unitConfig = {
      ConditionPathExists = "!/var/lib/bootstrap-complete";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "journal+console";
      StandardError = "journal+console";
      TimeoutStartSec = "600";  # 10 minute timeout
      Environment = [
        "PATH=/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin"
        "PYTHONPATH=/run/current-system/sw/lib/python3.11/site-packages:${pkgs.python3Packages.requests}/lib/python3.11/site-packages:${pkgs.python3Packages.urllib3}/lib/python3.11/site-packages:${pkgs.python3Packages.charset-normalizer}/lib/python3.11/site-packages:${pkgs.python3Packages.certifi}/lib/python3.11/site-packages:${pkgs.python3Packages.idna}/lib/python3.11/site-packages:${pkgs.python3Packages.cryptography}/lib/python3.11/site-packages:${pkgs.python3Packages.cffi}/lib/python3.11/site-packages"
      ];
    };
    script = ''
      echo "Starting enhanced discovery bootstrap process..."
      /etc/bootstrap/bootstrap.sh
    '';
  };
}
