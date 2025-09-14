{ config, pkgs, ... }:
{
  # Ethernet-only networking for bootstrap process with DHCP + link-local fallback
  networking = {
    # Disable WiFi completely for bootstrap
    wireless.enable = false;

    # Disable NetworkManager, use systemd-networkd instead for better control
    networkmanager.enable = false;

    # Use systemd-networkd for DHCP with automatic link-local fallback
    useNetworkd = true;
    useDHCP = false;

    # Basic firewall - allow SSH and discovery service communication
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];  # SSH for remote access after bootstrap
    };
  };

  # Configure systemd-networkd for ethernet with DHCP + link-local fallback
  systemd.network = {
    enable = true;

    # Network configuration for eth0 (primary ethernet)
    networks."10-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig = {
        DHCP = "ipv4";
        LinkLocalAddressing = "ipv4";  # Enable link-local as fallback
        IPv4LLRoute = true;            # Add route for link-local
      };
      dhcpV4Config = {
        UseTimezone = true;
        UseDNS = true;
        UseNTP = true;
        FallbackLeaseLifetimeSec = 300;  # 5 minute fallback lease
      };
      linkConfig = {
        RequiredForOnline = "routable";  # Wait for routable connection
      };
    };

    # Network configuration for end0 (alternative ethernet interface name)
    networks."11-end0" = {
      matchConfig.Name = "end0";
      networkConfig = {
        DHCP = "ipv4";
        LinkLocalAddressing = "ipv4";
        IPv4LLRoute = true;
      };
      dhcpV4Config = {
        UseTimezone = true;
        UseDNS = true;
        UseNTP = true;
        FallbackLeaseLifetimeSec = 300;
      };
      linkConfig = {
        RequiredForOnline = "routable";
      };
    };

    # Wait for network to be online
    wait-online = {
      enable = true;
      timeout = 60;  # Wait up to 60 seconds for network
      anyInterface = true;  # Accept any working interface
    };
  };

  # Network discovery services
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish.enable = true;
    publish.addresses = true;
  };
}
