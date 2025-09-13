# In configuration.nix, update the sensor user's extraGroups to remove non-existent groups:
users.users.sensor = {
  isNormalUser = true;
  description = "Sensor System User";
  extraGroups = [
    "wheel"
    "networkmanager"
    "dialout"
    # "kismet" will be added by the kismet module
    "video"
    # Remove these if they cause errors:
    # "gpio"
    # "i2c"
    # "spi"
  ];
  shell = pkgs.bash;
  openssh.authorizedKeys.keys = [
    # Add your SSH public key here
  ];
};
