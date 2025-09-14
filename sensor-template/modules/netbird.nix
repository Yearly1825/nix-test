{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.sensorNetbird;
in
{
  options.services.sensorNetbird = {
    enable = mkEnableOption "Netbird VPN client for sensor";

    managementUrl = mkOption {
      type = types.str;
      default = "https://api.netbird.io:443";
      description = "Netbird management server URL";
    };

    setupKey = mkOption {
      type = types.str;
      default = "";
      description = "Netbird setup key for automatic registration";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.netbird ];

    # Basic firewall rules for Netbird
    networking.firewall.allowedUDPPorts = [ 51820 ];
  };
}
