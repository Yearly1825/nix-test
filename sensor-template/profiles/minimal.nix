{ config, pkgs, lib, ... }:

{
  imports = [
    ../base/configuration.nix
    ../modules/netbird.nix
    ../modules/ssh.nix
  ];

  # Minimal configuration for basic connectivity
  environment.systemPackages = with pkgs; [
    # Essential system tools
    git
    curl
    wget
    vim
    htop

    # Basic network utilities
    netcat-gnu

    # JSON processing for API interactions
    jq
  ];

  # Minimal firewall configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];    # SSH only
    allowedUDPPorts = [ 51820 ]; # Netbird/WireGuard
  };

  # System description for identification
  environment.etc."sensor-info" = {
    text = ''
      SENSOR_TYPE=minimal
      CAPABILITIES=vpn,ssh
      CREATED=${toString builtins.currentTime}
    '';
  };
}
