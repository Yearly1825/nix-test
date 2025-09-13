{ config, pkgs, ... }:
{
  networking.wireless.enable = true;
  networking.wireless.networks = {
    "your-ssid" = { psk = "your-password"; };
  };
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish.enable = true;
    publish.addresses = true;
  };
}
