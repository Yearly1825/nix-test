{ config, pkgs, lib, ... }:

{
  # System identification
  networking = {
    hostName = "sensor";
    domain = "local";
    
    # Use NetworkManager for network configuration
    networkmanager = {
      enable = true;
      wifi.backend = "iwd"; # Use iwd for better WiFi performance
    };
    
    # Disable wpa_supplicant since we're using NetworkManager
    wireless.enable = false;
    
    # Enable firewall with specific ports
    firewall = {
      enable = true;
      allowPing = true;
    };
  };

  # Time zone and locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # System packages
  environment.systemPackages = with pkgs; [
    # Network analysis tools
    hcxdumptool
    kismet
    aircrack-ng
    wireshark-cli
    
    # GPS support
    gpsd
    gpsd-clients
    
    # VPN and networking
    wireguard-tools
    netbird
    
    # System utilities
    rsync
    tmux
    screen
    
    # Editors
    vim
    neovim
    nano
    
    # Development tools
    git
    gh
    
    # System monitoring
    htop
    btop
    iotop
    
    # Network tools
    curl
    wget
    tcpdump
    nmap
    iw
    iproute2
    dnsutils
    iperf3
    
    # File management
    tree
    ncdu
    unzip
    
    # Hardware tools
    usbutils
    pciutils
    i2c-tools
  ];

  # Enable services
  services = {
    # Enable automatic updates
    automatic-updates = {
      enable = false; # Set to true for automatic updates
      dates = "04:00";
    };
    
    # Enable time synchronization
    chrony.enable = true;
    
    # Enable hardware monitoring
    smartd.enable = false; # Disable for SD cards
  };

  # Enable custom sensor modules
  services.sensorSSH = {
    enable = true;
    port = 22;
    allowedUsers = [ "sensor" ];
  };

  services.sensorNetbird = {
    enable = true;
    # These will be overridden during deployment
    managementUrl = "https://api.netbird.io:443";
    setupKey = ""; # Will be set via environment or secrets
  };

  services.sensorKismet = {
    enable = true;
    interface = "wlan0";
    serverName = "RaspberryPi-Sensor";
    webPort = 2501;
    allowedHosts = [ "127.0.0.1" "::1" "10.0.0.0/8" ]; # Allow access from VPN
  };

  # User configuration
  users.users.sensor = {
    isNormalUser = true;
    description = "Sensor System User";
    extraGroups = [ 
      "wheel" 
      "networkmanager" 
      "dialout" 
      "kismet" 
      "wireshark"
      "video"
      "gpio"
      "i2c"
      "spi"
    ];
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      # Add your SSH public key here
      # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... user@host"
    ];
  };

  # Root user - disable password login
  users.users.root.hashedPassword = "!";

  # Security
  security = {
    sudo = {
      enable = true;
      wheelNeedsPassword = false;
      extraConfig = ''
        # Allow sensor user to run specific commands without password
        sensor ALL=(ALL) NOPASSWD: ALL
        
        # Security options
        Defaults requiretty
        Defaults !visiblepw
        Defaults always_set_home
        Defaults env_reset
        Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      '';
    };
    
    # Enable polkit for privilege escalation
    polkit.enable = true;
  };

  # Nix configuration
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "sensor" "@wheel" ];
    };
    
    # Garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # System version - don't change this after initial installation
  system.stateVersion = "24.05";
}