{ config, pkgs, lib, ... }:

{
  # Networking
  networking = {
    hostName = "sensor";
    networkmanager.enable = true;
    wireless.enable = false;
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 2501 ];
      allowedUDPPorts = [ 51820 ];
    };
  };

  # Basic system
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # Packages - ensure they're in system profile
  environment.systemPackages = with pkgs; [
    # Core utilities
    coreutils
    utillinux

    # Editors and tools
    vim
    git
    tmux
    htop
    curl
    wget

    # Network tools
    netbird
    wireguard-tools
    tcpdump
    nmap
    iw
    iproute2

    # Wireless tools
    kismet
    aircrack-ng
    hcxdumptool
  ];

  # SSH service
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # User
  users.users.sensor = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "dialout" ];
    openssh.authorizedKeys.keys = [
      # Your SSH key here
    ];
  };

  # Fix sudo configuration
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
    extraConfig = ''
      # Fix PATH for sudo
      Defaults secure_path="/run/wrappers/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      Defaults env_keep += "PATH"

      # Allow sensor user to run everything without password
      sensor ALL=(ALL) NOPASSWD: ALL
    '';
  };

  # Ensure PATH is set correctly
  environment.variables = {
    PATH = lib.mkForce "/run/wrappers/bin:/run/current-system/sw/bin:\${PATH}";
  };

  # Shell configuration
  programs.bash.shellInit = ''
    # Ensure PATH includes system binaries
    export PATH="/run/current-system/sw/bin:/run/wrappers/bin:$PATH"
  '';

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # System version
  system.stateVersion = "24.05";
}
