{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Raspberry Pi 4 hardware configuration
  boot = {
    initrd = {
      availableKernelModules = [ "xhci_pci" "usbhid" "usb_storage" ];
      kernelModules = [ ];
    };
    kernelModules = [ ];
    extraModulePackages = [ ];

    # Raspberry Pi specific boot configuration
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };

    kernelPackages = pkgs.linuxPackages_rpi4;
  };

  # File system configuration for Raspberry Pi
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
  };

  # Hardware settings
  hardware = {
    enableRedistributableFirmware = true;
    deviceTree = {
      enable = true;
      filter = "*rpi-4-*.dtb";
    };
  };

  swapDevices = [ ];

  # Networking
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
