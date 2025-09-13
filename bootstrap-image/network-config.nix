{ config, lib, pkgs, ... }:

{
  # Ethernet-only configuration for reliable bootstrap
  networking = {
    # Use DHCP on all Ethernet interfaces
    useDHCP = false;  # Disable global DHCP
    interfaces = {
      # Raspberry Pi 4/5 Ethernet
      eth0.useDHCP = true;
      # Alternative naming on some systems
      end0.useDHCP = true;
      enp0s3.useDHCP = true;
    };

    # Disable WiFi during bootstrap for simplicity
    wireless.enable = false;
    
    # Network manager not needed for simple Ethernet
    networkmanager.enable = false;

    # Ensure we wait for network before starting services
    dhcpcd = {
      enable = true;
      wait = "if-carrier-up";
    };

    # Basic firewall (allow SSH and discovery service communication)
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];  # SSH only
    };

    # Set timeouts for faster boot if network issues
    dhcpcd.extraConfig = ''
      timeout 30
      retry 60
    '';
  };

  # Ensure network-online target waits for actual connectivity
  systemd.services.network-online = {
    serviceConfig = {
      ExecStart = lib.mkForce [
        ""
        "${pkgs.bash}/bin/bash -c 'until ping -c1 1.1.1.1 &>/dev/null; do sleep 1; done'"
      ];
      TimeoutStartSec = "60s";
    };
  };
}