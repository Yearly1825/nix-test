{ config, pkgs, lib, ... }:
{
  # System version - keep for compatibility
  system.stateVersion = "24.05";

  # Basic boot configuration
  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
    # Kernel modules for Raspberry Pi
    kernelModules = [ "bcm2835-v4l2" ];
    # Ensure compatibility with sd-image-aarch64.nix
    growPartition = true;
  };

  # Enable flakes support
  nix = {
    package = pkgs.nixVersions.stable; # Updated from nixFlakes
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  # Temporary hostname
  networking.hostName = "pi-bootstrap";

  # Enable SSH for debugging
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true; # Only for bootstrap phase
    };
  };

  # Temporary root password - CHANGE THIS!
  users.users.root.initialPassword = "bootstrap";

  # Essential packages
  environment.systemPackages = with pkgs; [
    git
    curl
    jq
    wget
    vim
    htop
    tmux
  ];

  # Copy bootstrap script
  environment.etc."bootstrap/bootstrap.sh" = {
    source = ./bootstrap.sh;
    mode = "0755";
  };

  # Bootstrap service
  systemd.services.pi-bootstrap = {
    description = "Raspberry Pi Bootstrap Process";
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
      Restart = "on-failure";
      RestartSec = "30s";
    };
    script = ''
      echo "Starting bootstrap process..."
      /etc/bootstrap/bootstrap.sh
      touch /var/lib/bootstrap-complete
      echo "Bootstrap complete, rebooting..."
      sleep 5
      systemctl reboot
    '';
  };
}
