{ config, pkgs, ... }:
{
  # Ethernet-only networking for bootstrap process
  networking = {
    # Disable WiFi completely for bootstrap
    wireless.enable = false;

    # Use NetworkManager for DHCP handling
    networkmanager.enable = true;

    # Enable DHCP on ethernet interfaces
    useDHCP = false;
    interfaces = {
      eth0.useDHCP = true;
      end0.useDHCP = true;  # Some Pi models use this interface name
    };

    # Basic firewall - allow SSH and discovery service communication
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];  # SSH for remote access after bootstrap
    };
  };

  # Network discovery services
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish.enable = true;
    publish.addresses = true;
  };

  # Ensure network is available before starting bootstrap
  systemd.services.NetworkManager-wait-online.enable = true;
}
