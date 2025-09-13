{ config, pkgs, lib, ... }:
{
  system.stateVersion = "24.05";
  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
    kernelModules = [ "bcm2835-v4l2" ];
    growPartition = true;
  };
  nix = {
    package = pkgs.nixVersions.stable;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };
  networking.hostName = "pi-bootstrap";
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };
  users.users.root.initialPassword = "bootstrap";
  environment.systemPackages = with pkgs; [
    git
    curl
    jq
    wget
    vim
    htop
    tmux
  ];
  environment.etc."bootstrap/bootstrap.sh" = {
    source = ./bootstrap.sh;
    mode = "0755";
  };
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
