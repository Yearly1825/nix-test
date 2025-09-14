{
  description = "Test sensor configuration for bootstrap testing";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations.sensor = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        {
          # Basic system configuration
          system.stateVersion = "24.05";

          # Set hostname from environment variable if available
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

          # Add a test service to verify the config applied
          systemd.services.bootstrap-test = {
            description = "Bootstrap Test Service";
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              echo "Bootstrap configuration applied successfully!" > /var/log/bootstrap-test.log
              echo "Hostname: $(hostname)" >> /var/log/bootstrap-test.log
              echo "Time: $(date)" >> /var/log/bootstrap-test.log
              echo "Netbird setup key: $NETBIRD_SETUP_KEY" >> /var/log/bootstrap-test.log
            '';
          };

          # Basic packages
          environment.systemPackages = with nixpkgs.legacyPackages.aarch64-linux; [
            curl
            wget
            git
            htop
            vim
          ];

          # Create a completion marker
          systemd.services.bootstrap-complete-marker = {
            description = "Mark bootstrap as complete";
            wantedBy = [ "multi-user.target" ];
            after = [ "bootstrap-test.service" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              echo "$(date): Sensor configuration applied successfully" >> /var/log/sensor-bootstrap.log
              touch /var/lib/sensor-bootstrap-complete
            '';
          };
        }
      ];
    };
  };
}
