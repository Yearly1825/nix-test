{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Boot configuration for Raspberry Pi 4
  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
    kernelParams = [
      "console=ttyS0,115200"
      "console=tty1"
      "cma=128M"
    ];

    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "usbhid"
        "usb_storage"
        "uas"
        "pcie_brcmstb"
        "reset-raspberrypi"
      ];
      kernelModules = [ ];
    };

    kernelModules = [ ];
    extraModulePackages = [ ];

    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
      timeout = 3;
    };

    # Enable tmpfs for /tmp
    tmp.useTmpfs = true;
  };

  # File systems - adjust according to your SD card partitioning
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = [ "noatime" "nodiratime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [ "nofail" ];
  };

  swapDevices = [ ];

  # Raspberry Pi 4 specific hardware configuration
  hardware = {
    enableRedistributableFirmware = true;
    firmware = with pkgs; [
      raspberrypifw
      raspberrypi-armstubs
      armTrustedFirmwareAllwinner
    ];

    deviceTree = {
      enable = true;
      filter = "bcm2711-rpi-4-b.dtb";
    };
  };

  # GPU configuration
  hardware.opengl = {
    enable = true;
    setLdLibraryPath = true;
    package = pkgs.mesa;
  };

  # Enable Raspberry Pi specific features
  hardware.raspberry-pi."4" = {
    enable = true;
    fkms-3d.enable = true;
  };

  # Power management
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  nixpkgs.config.allowUnfree = true;
}
