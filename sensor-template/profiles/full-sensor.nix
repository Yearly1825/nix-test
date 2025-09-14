{ config, pkgs, lib, ... }:

{
  imports = [
    ../base/configuration.nix
    ../modules/kismet.nix
    ../modules/netbird.nix
    ../modules/ssh.nix
  ];

  # Full sensor stack with all network monitoring tools
  environment.systemPackages = with pkgs; [
    # Wireless monitoring and analysis
    kismet
    aircrack-ng
    hcxdumptool
    hcxtools

    # Network analysis tools
    tcpdump
    wireshark-cli  # tshark
    nmap
    iftop
    netcat-gnu

    # GPS support
    gpsd

    # System monitoring
    htop
    iotop
    nethogs

    # Development and debugging
    git
    curl
    wget
    vim
    tmux
    jq
  ];

  # Enable GPS daemon
  services.gpsd = {
    enable = true;
    devices = [ "/dev/ttyUSB0" "/dev/ttyAMA0" ];
    readonly = true;
    useDegrees = true;
  };

  # Firewall configuration for full sensor
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

  # Performance optimizations for monitoring
  boot.kernel.sysctl = {
    # Increase network buffer sizes for packet capture
    "net.core.rmem_max" = 134217728;
    "net.core.rmem_default" = 65536;
    "net.core.wmem_max" = 134217728;
    "net.core.wmem_default" = 65536;

    # Increase monitoring capabilities
    "net.core.netdev_max_backlog" = 5000;
  };

  # Enable monitor mode on wireless interfaces
  boot.extraModprobeConfig = ''
    # Enable monitor mode support
    options cfg80211 ieee80211_regdom=US
  '';

  # System description for identification
  environment.etc."sensor-info" = {
    text = ''
      SENSOR_TYPE=full-sensor
      CAPABILITIES=kismet,aircrack-ng,hcxdumptool,gps,vpn
      CREATED=${toString builtins.currentTime}
    '';
  };
}
