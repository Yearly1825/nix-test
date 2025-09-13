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
    environment.systemPackages = with pkgs; [ 
      kismet 
      aircrack-ng 
      iw 
    ];

    # Create kismet user and group
    users.users.kismet = {
      isSystemUser = true;
      group = "kismet";
      description = "Kismet daemon user";
      extraGroups = [ "dialout" "plugdev" ];
    };
    
    users.groups.kismet = {};

    # Add sensor user to kismet group
    users.users.sensor.extraGroups = [ "kismet" ];

    # Kismet configuration file
    environment.etc."kismet/kismet_site.conf".text = ''
      # Kismet site-specific configuration
      
      # Server name
      server_name=${cfg.serverName}
      
      # Data sources - will be configured at runtime
      # source=${cfg.interface}:name=sensor_monitor
      
      # Logging configuration  
      log_types=kismetdb,pcapng,alert
      log_prefix=${cfg.logPrefix}
      log_title=sensor
      
      # Web server configuration
      httpd_port=${toString cfg.webPort}
      httpd_bind_address=0.0.0.0
      httpd_allowed_hosts=${concatStringsSep "," cfg.allowedHosts}
      
      # Default credentials (CHANGE THESE!)
      httpd_username=kismet
      httpd_password=changeme
      
      # GPS configuration (if gpsd is available)
      gps=gpsd:host=localhost,port=2947,reconnect=true
      
      # Memory and performance tuning for Raspberry Pi
      packet_backlog_warning=20000
      packet_backlog_limit=40000
      packet_rate_max=1000
      
      # Channel hopping
      channel_hop=true
      channel_hop_speed=5/sec
      
      # 2.4GHz channels
      channel_list=1,2,3,4,5,6,7,8,9,10,11,12,13,14
      
      # Alerts configuration
      alert=ADHOCCONFLICT,5/min,1/sec
      alert=AIRJACKSSID,5/min,1/sec
      alert=APSPOOF,10/min,1/sec
      alert=BCASTDISCON,5/min,1/sec
      alert=CHANCHANGE,5/min,1/sec
      alert=CRYPTODROP,5/min,1/sec
      alert=DEAUTHFLOOD,5/min,2/sec
      alert=DISCONCODEINVALID,10/min,1/sec
      alert=DISASSOCTRAFFIC,10/min,1/sec
      alert=DHCPNAMECHANGE,5/min,1/sec
      alert=DHCPOSCHANGE,5/min,1/sec
      alert=DHCPCLIENTID,5/min,1/sec
      alert=DHCPCONFLICT,10/min,1/sec
      alert=NETSTUMBLER,5/min,1/sec
      alert=LUCENTTEST,5/min,1/sec
      alert=LONGSSID,5/min,1/sec
      alert=MSFBCOMSSID,5/min,1/sec
      alert=MSFDLINKRATE,5/min,1/sec
      alert=MSFNETGEARBEACON,5/min,1/sec
      alert=NULLPROBERESP,5/min,1/sec
      
      # OUI lookups
      manuf_lookup=true
      
      # Log rotation
      log_rotate=true
      log_rotate_size=100
      log_rotate_days=7
    '';

    # Systemd service for Kismet
    systemd.services.kismet = {
      description = "Kismet Wireless Monitor";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = mkIf cfg.autoStart [ "multi-user.target" ];
      
      path = with pkgs; [ 
        kismet 
        iw 
        iproute2 
        wirelesstools 
        aircrack-ng 
      ];
      
      serviceConfig = {
        Type = "simple";
        User = "root"; # Needs root for interface management
        ExecStartPre = pkgs.writeShellScript "kismet-pre" ''
          # Create log directory
          mkdir -p ${cfg.logPrefix}
          chown kismet:kismet ${cfg.logPrefix}
          chmod 755 ${cfg.logPrefix}
          
          # Check if interface exists
          if ip link show ${cfg.interface} > /dev/null 2>&1; then
            echo "Setting ${cfg.interface} to monitor mode..."
            
            # Bring interface down
            ip link set ${cfg.interface} down || true
            
            # Set monitor mode
            iw dev ${cfg.interface} set type monitor || true
            
            # Bring interface up
            ip link set ${cfg.interface} up || true
          else
            echo "Warning: Interface ${cfg.interface} not found"
          fi
        '';
        
        ExecStart = ''
          ${pkgs.kismet}/bin/kismet \
            --no-ncurses \
            --config-file /etc/kismet/kismet_site.conf
        '';
        
        ExecStop = pkgs.writeShellScript "kismet-stop" ''
          # Reset interface to managed mode
          if ip link show ${cfg.interface} > /dev/null 2>&1; then
            ip link set ${cfg.interface} down || true
            iw dev ${cfg.interface} set type managed || true
          fi
        '';
        
        Restart = "on-failure";
        RestartSec = 10;
      };
    };

    # System directories
    systemd.tmpfiles.rules = [
      "d ${cfg.logPrefix} 0755 kismet kismet -"
      "d /var/lib/kismet 0755 kismet kismet -"
      "d /run/kismet 0755 kismet kismet -"
    ];

    # Firewall configuration
    networking.firewall = {
      allowedTCPPorts = [ cfg.webPort ];
    };

    # Enable GPS daemon if configured
    services.gpsd = {
      enable = true;
      devices = [ "/dev/ttyUSB0" "/dev/ttyACM0" ];
      readonly = true;
      nowait = true;
    };
  };
}