{ config, pkgs, lib, ... }:

{
  # System version - important for compatibility
  system.stateVersion = "24.05";
  
  # Basic boot configuration
  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
    # Kernel modules needed for Raspberry Pi
    kernelModules = [ "bcm2835-v4l2" ];
  };

  # Enable flakes support (required for nixos-rebuild with flakes)
  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # Temporary hostname (will be replaced after registration)
  networking.hostName = "pi-bootstrap";

  # Enable SSH for debugging
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;  # Only for bootstrap phase
    };
  };

  # Temporary root password - CHANGE THIS!
  users.users.root.initialPassword = "bootstrap";

  # Essential packages for bootstrap process
  environment.systemPackages = with pkgs; [
    git
    curl
    jq
    wget
    vim
    htop
    tmux
  ];

  # Copy bootstrap script to system
  environment.etc."bootstrap/bootstrap.sh" = {
    source = ./bootstrap.sh;
    mode = "0755";
  };

  # Bootstrap service definition
  systemd.services.pi-bootstrap = {
    description = "Raspberry Pi Bootstrap Process";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    
    # Only run once - checks for marker file
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

  # Ensure system can expand filesystem on first boot
  boot.growPartition = true;
}