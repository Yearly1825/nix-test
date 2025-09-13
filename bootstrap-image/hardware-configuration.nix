{ config, pkgs, ... }:
{
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = [ "noatime" ];
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
  };
  boot = {
    kernelPackages = pkgs.linuxPackages_rpi4; # For Pi 4; use linuxPackages_rpi5 for Pi 5
    # Optional: Firmware config for GPU memory (if still needed)
    loader.firmwareConfig = ''
      gpu_mem=256
    '';
  };
  hardware = {
    enableRedistributableFirmware = true;
    deviceTree = {
      enable = true;
      filter = "*rpi-4-*.dtb";
    };
  };
}
