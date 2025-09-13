{ config, lib, pkgs, ... }:

with lib;

{
  options.services.sensorSSH = {
    enable = mkEnableOption "SSH configuration for sensor";

    port = mkOption {
      type = types.int;
      default = 22;
      description = "SSH port";
    };

    allowedUsers = mkOption {
      type = types.listOf types.str;
      default = [ "sensor" ];
      description = "Users allowed to SSH";
    };
  };

  config = mkIf config.services.sensorSSH.enable {
    services.openssh = {
      enable = true;
      ports = [ config.services.sensorSSH.port ];
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        PubkeyAuthentication = true;
      };
    };

    networking.firewall.allowedTCPPorts = [ config.services.sensorSSH.port ];
  };
}
