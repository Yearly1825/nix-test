{
  description = "SD Image with sensor applications for Raspberry Pi";

  # Configure additional binary cache for faster builds
  nixConfig = {
    extra-substituters = [ "https://raspberry-pi-nix.cachix.org" ];
    extra-trusted-public-keys = [
      "raspberry-pi-nix.cachix.org-1:WmV2rdSangxW0rZjY/tBvBDSaNFQ3DyEQsVw8EvHn9o="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    raspberry-pi-nix.url = "github:tstat/raspberry-pi-nix";
  };

  outputs = { self, nixpkgs, raspberry-pi-nix }: {
    nixosConfigurations.sensor = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        raspberry-pi-nix.nixosModules.raspberry-pi
        raspberry-pi-nix.nixosModules.sd-image
        {
          system.stateVersion = "24.05";

          # Specify the board type (bcm2711 for RPi 4)
          raspberry-pi-nix.board = "bcm2711";

          # Hardcode the hostname you want
          networking.hostName = "sensor-test-01";

          # Filesystem configuration
          fileSystems = {
            "/" = {
              device = "/dev/disk/by-label/NIXOS_SD";
              fsType = "ext4";
              options = [ "noatime" ];
            };
            "/boot" = {
              device = "/dev/disk/by-label/BOOT";
              fsType = "vfat";
              options = [ "nofail" "noauto" ];
            };
          };

          # Boot configuration - let raspberry-pi-nix module handle this
          boot.loader.grub.enable = false;

          # Your existing config
          services.openssh.enable = true;
          users.users.root.initialPassword = "bootstrap";

          # Add sensor applications
          environment.systemPackages = with nixpkgs.legacyPackages.aarch64-linux; [
            # Basic tools
            git curl jq vim htop

            # Network monitoring applications
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
        }
      ];
    };

    # SD Image output
    images.sensor = self.nixosConfigurations.sensor.config.system.build.sdImage;
  };
}
