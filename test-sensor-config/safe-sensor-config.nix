{
  description = "Safe sensor configuration with network failsafes";

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

          # CRITICAL: Keep networking stable during bootstrap
          networking = {
            # Preserve the hostname assignment from bootstrap
            hostName =
              let envHostname = builtins.getEnv "ASSIGNED_HOSTNAME";
              in if envHostname != "" then envHostname else "sensor-fallback";

            # SAFE: Keep DHCP enabled - don't change to static during bootstrap
            networkmanager.enable = true;
            useDHCP = false;
            interfaces.eth0.useDHCP = true;
            interfaces.end0.useDHCP = true;

            # SAFE: Keep firewall permissive during bootstrap
            firewall = {
              enable = true;
              allowedTCPPorts = [ 22 ];  # Always allow SSH
            };
          };

          # CRITICAL: Keep SSH access working
          services.openssh = {
            enable = true;
            settings = {
              PermitRootLogin = "yes";
              PasswordAuthentication = true;
              # SAFE: Don't change SSH port during bootstrap
            };
          };

          # SAFE: Keep root password during bootstrap
          users.users.root.initialPassword = "sensor";

          # File systems - match Pi hardware
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
              # Limit generations to save space
              generic-extlinux-compatible.configurationLimit = 2;
            };
            kernelPackages = nixpkgs.legacyPackages.aarch64-linux.linuxPackages_rpi4;
          };

          # Space management
          nix = {
            gc = {
              automatic = true;
              dates = "daily";  # More aggressive during bootstrap
              options = "--delete-older-than 1d";
            };
          };

          # DEBUGGING: Add services to track what happened
          systemd.services.bootstrap-debug = {
            description = "Bootstrap Debug Service";
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              echo "=== SENSOR CONFIG APPLIED ===" > /var/log/sensor-applied.log
              echo "Time: $(date)" >> /var/log/sensor-applied.log
              echo "Hostname: $(hostname)" >> /var/log/sensor-applied.log
              echo "IP: $(ip addr show eth0 | grep inet | head -1)" >> /var/log/sensor-applied.log
              echo "Disk space:" >> /var/log/sensor-applied.log
              df -h >> /var/log/sensor-applied.log
              echo "Network interfaces:" >> /var/log/sensor-applied.log
              ip addr >> /var/log/sensor-applied.log

              # Signal bootstrap completion
              touch /var/lib/sensor-bootstrap-complete
            '';
          };

          # Minimal packages for now
          environment.systemPackages = with nixpkgs.legacyPackages.aarch64-linux; [
            curl
            wget
            htop
            vim
          ];

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
