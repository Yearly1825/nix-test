{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.sensorKismet;
in
{
  options.services.sensorKismet = {
    enable = mkEnableOption "Kismet wireless monitoring for sensor";

    interface = mkOption {
      type = types.str;
      default = "wlan0";
      description = "Wireless interface to monitor";
    };

    serverName = mkOption {
      type = types.str;
      default = "Sensor-Kismet";
      description = "Kismet server name";
    };

    logPrefix = mkOption {
      type = types.str;
      default = "/var/lib/kismet/";
      description = "Directory for Kismet logs";
    };

    webPort = mkOption {
      type = types.int;
      default = 2501;
      description = "Kismet web interface port";
    };

    allowedHosts = mkOption {
      type = types.listOf types.str;
      default = [ "127.0.0.1" "::1" ];
      description = "Allowed hosts for web interface";
    };

    autoStart = mkOption {
      type = types.bool;
      default = false;
      description = "Start Kismet automatically on boot";
    };
  };

  config = mkIf cfg.enable {
    # For now, just install kismet package
    environment.systemPackages = [ pkgs.kismet ];

    # Open firewall port
    networking.firewall.allowedTCPPorts = [ cfg.webPort ];
  };
}
