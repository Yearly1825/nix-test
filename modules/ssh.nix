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
    
    mosh = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Mosh (mobile shell)";
    };
  };

  config = mkIf config.services.sensorSSH.enable {
    # SSH daemon configuration
    services.openssh = {
      enable = true;
      ports = [ config.services.sensorSSH.port ];
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PubkeyAuthentication = true;
        PermitRootLogin = "no";
        AllowUsers = config.services.sensorSSH.allowedUsers;
        X11Forwarding = false;
        PrintMotd = true;
        PrintLastLog = true;
        TCPKeepAlive = true;
        Compression = true;
        ClientAliveInterval = 60;
        ClientAliveCountMax = 3;
        UsePAM = true;
      };
      
      extraConfig = ''
        # Security hardening
        Protocol 2
        StrictModes yes
        IgnoreRhosts yes
        HostbasedAuthentication no
        PermitEmptyPasswords no
        ChallengeResponseAuthentication no
        
        # Performance tuning
        UseDNS no
        MaxStartups 10:30:100
        MaxSessions 10
        
        # Logging
        LogLevel VERBOSE
        SyslogFacility AUTH
      '';
    };

    # Enable Mosh for better mobile connectivity
    programs.mosh.enable = config.services.sensorSSH.mosh;

    # Firewall rules
    networking.firewall.allowedTCPPorts = [ config.services.sensorSSH.port ];
    networking.firewall.allowedUDPPortRanges = mkIf config.services.sensorSSH.mosh [
      { from = 60000; to = 61000; } # Mosh ports
    ];

    # Fail2ban for SSH protection
    services.fail2ban = {
      enable = true;
      maxretry = 3;
      bantime = "1h";
      bantime-increment.enable = true;
      
      jails = {
        sshd = {
          enabled = true;
          settings = {
            port = toString config.services.sensorSSH.port;
            filter = "sshd[mode=aggressive]";
            maxretry = 3;
          };
        };
      };
    };

    # SSH host keys - generate if not present
    services.openssh.hostKeys = [
      {
        bits = 4096;
        path = "/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
      }
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };
}