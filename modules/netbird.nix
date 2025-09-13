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
    
    interface = mkOption {
      type = types.str;
      default = "wt0";
      description = "Netbird interface name";
    };
    
    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Start Netbird automatically on boot";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.netbird ];

    # Netbird service
    systemd.services.netbird = {
      description = "Netbird VPN Client";
      after = [ "network-online.target" "nss-lookup.target" ];
      wants = [ "network-online.target" "nss-lookup.target" ];
      wantedBy = mkIf cfg.autoStart [ "multi-user.target" ];
      
      path = [ pkgs.netbird pkgs.iproute2 ];
      
      serviceConfig = {
        Type = "exec";
        Restart = "always";
        RestartSec = 15;
        RuntimeDirectory = "netbird";
        StateDirectory = "netbird";
        
        ExecStartPre = let
          setupScript = pkgs.writeShellScript "netbird-setup" ''
            # Ensure config directory exists
            mkdir -p /var/lib/netbird
            
            # If setup key is provided and we're not already configured
            if [ -n "${cfg.setupKey}" ] && [ ! -f /var/lib/netbird/config.json ]; then
              echo "Configuring Netbird with setup key..."
              ${pkgs.netbird}/bin/netbird up \
                --setup-key "${cfg.setupKey}" \
                --management-url "${cfg.managementUrl}" \
                --admin-url "" \
                --config /var/lib/netbird/config.json \
                --log-file console \
                --log-level info \
                --disable-auto-connect
              
              ${pkgs.netbird}/bin/netbird down
            fi
          '';
        in "${setupScript}";
        
        ExecStart = ''
          ${pkgs.netbird}/bin/netbird up \
            --config /var/lib/netbird/config.json \
            --log-file console \
            --log-level info \
            --foreground-mode
        '';
        
        ExecStop = "${pkgs.netbird}/bin/netbird down";
      };
    };

    # Firewall configuration for Netbird
    networking.firewall = {
      allowedUDPPorts = [ 51820 ]; # WireGuard port
      # Allow Netbird interface traffic
      trustedInterfaces = [ cfg.interface ];
    };

    # Enable IP forwarding
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    # Create netbird state directory
    systemd.tmpfiles.rules = [
      "d /var/lib/netbird 0700 root root -"
    ];
  };
}