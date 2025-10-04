{ config, pkgs, ... }:
{
  # Ethernet-only networking for bootstrap process
  networking = {
    # Disable WiFi completely for bootstrap
    wireless.enable = false;

    # Use dhcpcd for deterministic routing metrics (prevents cellular modem from taking priority)
    useDHCP = false;

    # Enable DHCP on eth0
    interfaces.eth0.useDHCP = true;

    # Set metric via dhcpcd to ensure ethernet is always preferred over cellular modems
    dhcpcd.extraConfig = ''
      # Ethernet always gets metric 10 (highest priority)
      interface eth0
      metric 10

      # All other interfaces get high metric (fallback only)
      interface *
      metric 2000
    '';

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
}
