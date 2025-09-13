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
    kernelPackages = pkgs.linuxPackages_rpi4;
    loader.raspberryPi = {
      enable = true;
      version = 4;
    };
    loader.raspberryPi.firmwareConfig = ''
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
