{ config, pkgs, lib, ... }:

{
  imports = [
    ../base/configuration.nix
    ../modules/kismet.nix
    ../modules/netbird.nix
    ../modules/ssh.nix
  ];

  # Lightweight wireless monitoring configuration
  environment.systemPackages = with pkgs; [
    # Core wireless monitoring
    kismet

    # Basic network tools
    tcpdump
    nmap
    netcat-gnu

    # System monitoring
    htop
    iftop

    # Essential tools
    git
    curl
    wget
    vim
    jq
  ];

  # Firewall configuration for wireless monitoring
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22     # SSH
      2501   # Kismet web interface
    ];
    allowedUDPPorts = [
      51820  # Netbird/WireGuard
    ];
  };

  # Basic network optimizations
  boot.kernel.sysctl = {
    "net.core.rmem_max" = 67108864;
    "net.core.rmem_default" = 32768;
    "net.core.netdev_max_backlog" = 1000;
  };

  # Enable monitor mode on wireless interfaces
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom=US
  '';

  # System description for identification
  environment.etc."sensor-info" = {
    text = ''
      SENSOR_TYPE=wireless-monitor
      CAPABILITIES=kismet,basic-network,vpn
      CREATED=${toString builtins.currentTime}
    '';
  };
}
