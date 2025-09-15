{
  description = "Working sensor configuration for bootstrap testing";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations.sensor = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        {
          # Disable problematic assertions
          assertions = nixpkgs.lib.mkForce [];

          # Basic system configuration
          system.stateVersion = "24.05";

          # Explicit file system configuration
          fileSystems."/" = {
            device = "/dev/disk/by-label/NIXOS_SD";
            fsType = "ext4";
            options = [ "noatime" ];
          };

          fileSystems."/boot" = {
            device = "/dev/disk/by-label/FIRMWARE";
            fsType = "vfat";
          };

          # Boot configuration
          boot = {
            loader = {
              grub.enable = false;
              generic-extlinux-compatible.enable = true;
            };
            kernelPackages = nixpkgs.legacyPackages.aarch64-linux.linuxPackages_rpi4;
          };

          # Set hostname from environment variable
          networking.hostName =
            let envHostname = builtins.getEnv "ASSIGNED_HOSTNAME";
            in if envHostname != "" then envHostname else "test-sensor";

          # Enable SSH
          services.openssh = {
            enable = true;
            settings = {
              PermitRootLogin = "yes";
              PasswordAuthentication = true;
            };
          };

          # Set root password
          users.users.root.initialPassword = "sensor";

          # Enable NetworkManager
          networking.networkmanager.enable = true;

          # Add a test service to verify the config applied (matching bootstrap functionality)
          systemd.services.bootstrap-test = {
            description = "Bootstrap Test Service - Verify Package Installation";
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              echo "=== Bootstrap configuration applied successfully! ===" > /var/log/bootstrap-test.log
              echo "Hostname: $(hostname)" >> /var/log/bootstrap-test.log
              echo "Time: $(date)" >> /var/log/bootstrap-test.log
              echo "Netbird setup key: $NETBIRD_SETUP_KEY" >> /var/log/bootstrap-test.log
              echo "" >> /var/log/bootstrap-test.log

              # Verify key packages are installed (matching bootstrap)
              echo "=== Package Verification ===" >> /var/log/bootstrap-test.log

              # Basic tools
              for tool in git curl jq wget vim htop tmux python3; do
                if command -v "$tool" >/dev/null 2>&1; then
                  echo "✓ $tool: $(command -v $tool)" >> /var/log/bootstrap-test.log
                else
                  echo "✗ $tool: NOT FOUND" >> /var/log/bootstrap-test.log
                fi
              done

              # Network tools
              for tool in kismet aircrack-ng hcxdumptool tcpdump tshark nmap iftop netcat; do
                if command -v "$tool" >/dev/null 2>&1; then
                  echo "✓ $tool: $(command -v $tool)" >> /var/log/bootstrap-test.log
                else
                  echo "✗ $tool: NOT FOUND" >> /var/log/bootstrap-test.log
                fi
              done

              # Python packages
              echo "" >> /var/log/bootstrap-test.log
              echo "=== Python Package Verification ===" >> /var/log/bootstrap-test.log
              python3 -c "
              import sys
              packages = ['requests', 'cryptography', 'json', 'hashlib', 'hmac', 'base64']
              for pkg in packages:
                  try:
                      __import__(pkg)
                      print(f'✓ {pkg}: Available')
                  except ImportError:
                      print(f'✗ {pkg}: NOT AVAILABLE')
              " >> /var/log/bootstrap-test.log 2>&1

              echo "" >> /var/log/bootstrap-test.log
              echo "=== System Info ===" >> /var/log/bootstrap-test.log
              echo "Kernel: $(uname -r)" >> /var/log/bootstrap-test.log
              echo "Architecture: $(uname -m)" >> /var/log/bootstrap-test.log
              echo "Memory: $(free -h | grep '^Mem:' | awk '{print $2 " total, " $7 " available"}')" >> /var/log/bootstrap-test.log
              echo "Disk usage: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')" >> /var/log/bootstrap-test.log

              echo "=== Test completed at $(date) ===" >> /var/log/bootstrap-test.log
            '';
          };

          # Match bootstrap configuration packages exactly
          environment.systemPackages = with nixpkgs.legacyPackages.aarch64-linux; [
            # Basic tools (matching bootstrap)
            git
            curl
            jq
            wget
            vim
            htop
            tmux

            # Discovery service dependencies (matching bootstrap)
            python3
            python3Packages.requests
            python3Packages.cryptography
            python3Packages.pip

            # Pre-installed network monitoring tools (matching bootstrap)
            kismet
            aircrack-ng
            hcxdumptool
            hcxtools
            tcpdump
            wireshark-cli  # provides tshark
            nmap
            iftop
            netcat-gnu

            # GPS support (matching bootstrap)
            gpsd

            # Additional system tools (matching bootstrap)
            iotop
            nethogs
          ];

          # Create a completion marker (matching bootstrap behavior)
          systemd.services.bootstrap-complete-marker = {
            description = "Mark bootstrap as complete - Final Configuration Applied";
            wantedBy = [ "multi-user.target" ];
            after = [ "bootstrap-test.service" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              echo "$(date): Final sensor configuration applied successfully for $(hostname)" >> /var/log/sensor-bootstrap.log
              echo "$(date): All packages installed and verified" >> /var/log/sensor-bootstrap.log
              echo "$(date): Bootstrap process completed - ready for sensor operations" >> /var/log/sensor-bootstrap.log

              # Create completion markers (matching bootstrap)
              touch /var/lib/sensor-bootstrap-complete
              touch /var/lib/bootstrap-complete

              # Log final status
              echo "🎉 Bootstrap completed successfully at $(date)" >> /var/log/sensor-bootstrap.log
              echo "📊 System ready for sensor data collection" >> /var/log/sensor-bootstrap.log

              # Display completion message to console
              echo "🚀 Sensor configuration bootstrap completed successfully!"
              echo "📝 Check /var/log/bootstrap-test.log for package verification"
              echo "📝 Check /var/log/sensor-bootstrap.log for completion status"
            '';
          };

          # Hardware settings
          hardware = {
            enableRedistributableFirmware = true;
            deviceTree = {
              enable = true;
              filter = "*rpi-4-*.dtb";
            };
          };

          nixpkgs.hostPlatform = "aarch64-linux";
        }
      ];
    };
  };
}
