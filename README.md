# NixOS Raspberry Pi 4 Sensor System

A complete NixOS configuration for deploying Raspberry Pi 4 devices as network sensors with Kismet wireless monitoring, Netbird VPN connectivity, and secure SSH access.

## Features

- **Network Monitoring**: Kismet for WiFi analysis and packet capture
- **Secure Connectivity**: Netbird VPN for secure remote access
- **SSH Hardening**: Public key only authentication with fail2ban
- **Automated Deployment**: Flake-based configuration management
- **Security Tools**: Aircrack-ng, hcxdumptool, tcpdump, nmap, and more
- **GPS Support**: Built-in gpsd configuration for location awareness
- **Passwordless Sudo**: Configured for automation workflows

## Quick Start

### Prerequisites

- Raspberry Pi 4 (2GB+ RAM recommended)
- 16GB+ SD card
- NixOS ARM image
- Netbird account and setup key
- SSH key pair

### 1. Prepare SD Card

```bash
# Download NixOS ARM image
wget https://hydra.nixos.org/build/latest/nixos-sd-image-24.05-aarch64-linux.img.zst

# Flash to SD card (replace sdX with your device)
zstd -d nixos-sd-image-*.img.zst
sudo dd if=nixos-sd-image-*.img of=/dev/sdX bs=4M status=progress sync
```

### 2. Initial Boot

1. Insert SD card and power on Raspberry Pi
2. Connect via ethernet or attach keyboard/monitor
3. Login as `root` (no password initially)

### 3. Deploy Configuration

```bash
# Connect to network
nmcli device wifi connect "YOUR_WIFI_SSID" password "YOUR_PASSWORD"

# Download and run bootstrap
curl -L https://raw.githubusercontent.com/yourusername/sensor-config/main/scripts/bootstrap.sh -o bootstrap.sh
chmod +x bootstrap.sh

# Deploy with your settings
./bootstrap.sh \
  "https://github.com/yourusername/sensor-config.git" \
  "YOUR_NETBIRD_SETUP_KEY" \
  "ssh-ed25519 AAAAC3... your-public-key"

# Reboot
reboot
```

### 4. Access Your Sensor

```bash
# SSH access (password: disabled, use your key)
ssh sensor@<raspberry-pi-ip>

# Kismet Web UI
http://<raspberry-pi-ip>:2501
# Default: kismet/changeme

# Check VPN status
sudo netbird status
```

## Configuration Structure

```
.
├── flake.nix                 # Flake definition
├── configuration.nix         # Main system configuration
├── hardware-configuration.nix # Hardware-specific settings
├── modules/
│   ├── ssh.nix              # SSH hardening and fail2ban
│   ├── netbird.nix          # Netbird VPN client
│   └── kismet.nix           # Kismet wireless monitoring
├── secrets/                  # Git-ignored secrets
└── scripts/
    ├── bootstrap.sh         # Initial deployment
    └── update.sh           # Configuration updates
```

## Key Components

### Network Monitoring (Kismet)

- Automatic channel hopping on 2.4GHz
- Web interface on port 2501
- GPS integration for location tagging
- Packet capture in PCAPNG format
- Alert detection for common attacks

### VPN Connectivity (Netbird)

- Zero-config WireGuard-based VPN
- Automatic reconnection
- Management through Netbird cloud
- Secure peer-to-peer connectivity

### Security Features

- SSH public key only authentication
- Fail2ban with progressive ban times
- Firewall with minimal open ports
- Passwordless sudo for automation
- Disabled root password login

## Customization

### Adding SSH Keys

Edit `configuration.nix`:
```nix
users.users.sensor = {
  openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3... user1@host"
    "ssh-rsa AAAAB3... user2@host"
  ];
};
```

### Changing Network Interfaces

Edit `modules/kismet.nix`:
```nix
services.sensorKismet = {
  interface = "wlan1";  # Change from wlan0
};
```

### Modifying Firewall Rules

Edit `configuration.nix`:
```nix
networking.firewall = {
  allowedTCPPorts = [ 22 2501 3000 ];  # Add ports
  allowedUDPPorts = [ 51820 ];
};
```

## Maintenance

### Update Configuration

```bash
# On the sensor
cd /etc/nixos
sudo ./scripts/update.sh

# Or remotely
ssh sensor@<ip> "cd /etc/nixos && sudo ./scripts/update.sh"
```

### System Updates

```bash
# Update NixOS channel
sudo nix-channel --update

# Rebuild with updates
sudo nixos-rebuild switch --upgrade
```

### Garbage Collection

```bash
# Remove old generations
sudo nix-collect-garbage -d

# Keep last 3 generations
sudo nix-env --delete-generations +3
```

## Monitoring

### Service Status

```bash
# Check all sensor services
systemctl status sshd netbird kismet

# View logs
journalctl -u netbird -f
journalctl -u kismet -f
```

### Network Status

```bash
# VPN status
sudo netbird status

# WiFi interfaces
iw dev
ip link show

# Monitor mode check
iw dev wlan0 info
```

### Resource Usage

```bash
# System resources
htop

# Disk usage
df -h
ncdu /

# Network traffic
iftop
```

## Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| Can't SSH | Check firewall, verify key, check fail2ban |
| Netbird not connecting | Verify setup key, check management URL |
| Kismet not starting | Check WiFi interface exists, verify monitor mode support |
| Build fails | Run with `--show-trace`, check disk space |
| WiFi not working | Check NetworkManager status, verify drivers |

### Debug Commands

```bash
# System logs
journalctl -xe

# Network debugging
nmcli device status
ip addr show
ping 8.8.8.8

# Service debugging
systemctl status <service>
journalctl -u <service> --since "5 minutes ago"

# Configuration validation
nixos-rebuild dry-build
```

## Security Considerations

⚠️ **Important Security Steps**:

1. **Change default passwords**:
   - Kismet web interface password
   - Any service credentials

2. **Review firewall rules**:
   - Only open required ports
   - Use VPN for remote access when possible

3. **Keep system updated**:
   - Regular NixOS updates
   - Monitor security advisories

4. **Audit access**:
   - Review SSH keys periodically
   - Check fail2ban logs
   - Monitor login attempts

## Advanced Usage

### Custom Modules

Create new module in `modules/`:
```nix
{ config, lib, pkgs, ... }:
{
  options.services.myService = {
    enable = lib.mkEnableOption "My custom service";
  };

  config = lib.mkIf config.services.myService.enable {
    # Service configuration
  };
}
```

### Multiple Sensors

Deploy fleet with different hostnames:
```nix
# In configuration.nix
networking.hostName = "sensor-${location}";
```

### Integration Examples

```bash
# Stream Kismet data to central server
kismet_client -c <sensor-ip>:2501

# Sync captures to central storage
rsync -av sensor@<ip>:/var/lib/kismet/*.pcapng ./captures/

# Aggregate logs with Vector/Loki
vector --config /etc/vector/sensor.toml
```

## Contributing

1. Fork the repository
2. Create feature branch
3. Test on actual hardware
4. Submit pull request

## License

MIT License - See LICENSE file

## Support

- Issues: [GitHub Issues](https://github.com/yourusername/sensor-config/issues)
- Documentation: [Wiki](https://github.com/yourusername/sensor-config/wiki)
- Community: [Discussions](https://github.com/yourusername/sensor-config/discussions)

## Acknowledgments

- NixOS community for ARM support
- Kismet developers for wireless monitoring tools
- Netbird team for excellent VPN solution

---

**Note**: Remember to replace placeholder values:
- Repository URLs
- Netbird setup keys
- SSH public keys
- Default passwords
- Network SSIDs

Stay secure! 🔒
