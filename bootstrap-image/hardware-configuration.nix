{ config, lib, pkgs, ... }:

{
  # Import base Raspberry Pi configuration
  imports = [
    <nixpkgs/nixos/modules/installer/sd-card/sd-image-aarch64.nix>
  ];

  # Filesystem configuration
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };

  # Boot configuration specific to Pi
  boot = {
    kernelPackages = pkgs.linuxPackages_rpi4;
    # For Pi 3, use: pkgs.linuxPackages_rpi3
    
    # Enable additional hardware support
    loader.raspberryPi = {
      enable = true;
      version = 4;  # Change to 3 for Pi 3
    };
  };

  # Hardware-specific options
  hardware = {
    enableRedistributableFirmware = true;
    raspberry-pi."4".apply-overlays-dtmerge.enable = true;
    deviceTree = {
      enable = true;
      filter = "*rpi-4-*.dtb";  # Change for different Pi models
    };
  };

  # GPU memory split (MB)
  boot.loader.raspberryPi.firmwareConfig = ''
    gpu_mem=256
  '';
}