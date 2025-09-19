# Package Alignment: Bootstrap Image ↔ Sensor Config

This document tracks the package alignment between the bootstrap image and the final sensor configuration to ensure fast `nixos-rebuild switch` times.

## Status: ✅ ALIGNED

All packages required by `nixos-pi-configs` are now pre-installed in the bootstrap image.

## Package Comparison

### Core System Packages
Both configurations include:
- `git`, `curl`, `jq`, `wget`, `vim`, `htop`, `tmux`
- `iotop`, `nethogs`

### Python Environment
Both configurations include Python 3 with these packages:
- `requests` - HTTP library for discovery service
- `cryptography` - Encryption for discovery service
- `pip` - Package installer
- `gps3` - GPS Python tools
- `setuptools` - Python entry points
- `protobuf` - Kismet communication
- `numpy` - Capture tools support

### Network Monitoring Tools
Both configurations include:
- `kismet` - Primary wireless monitoring tool
- `aircrack-ng` - WiFi security auditing
- `hcxdumptool` - Capture tool for WiFi
- `hcxtools` - Conversion tools
- `tcpdump` - Packet capture
- `wireshark-cli` (tshark) - Protocol analysis
- `nmap` - Network discovery
- `iftop` - Bandwidth monitoring
- `netcat-gnu` - Network utility

### GPS Support
Both configurations include:
- `gpsd` - GPS daemon for location services

### VPN Support
Both configurations include:
- `netbird` - Mesh VPN for remote management

### Radio/SDR Support
Both configurations include:
- `rtl-sdr` - RTL-SDR hardware support
- `rtl_433` - RTL-433 decoder for various protocols

## Benefits of Pre-installation

1. **Faster Bootstrap**: `nixos-rebuild switch` completes much faster
2. **Less Network Usage**: No need to download packages during bootstrap
3. **More Reliable**: Reduces dependency on package mirrors during critical bootstrap phase
4. **Predictable Timing**: Bootstrap time is more consistent

## Package Lists

### Bootstrap Image (`nix-sensor/bootstrap-image/configuration.nix`)
```nix
environment.systemPackages = with pkgs; [
  # Core tools
  git curl jq wget vim htop tmux
  
  # Python with packages
  (python3.withPackages (ps: with ps; [
    requests cryptography pip gps3
    setuptools protobuf numpy
  ]))
  
  # Network monitoring
  kismet aircrack-ng hcxdumptool hcxtools
  tcpdump wireshark-cli nmap iftop netcat-gnu
  
  # GPS support
  gpsd
  
  # VPN support
  netbird
  
  # RTL-SDR support
  rtl-sdr rtl_433
  
  # System tools
  iotop nethogs
];
```

### Sensor Config (`nixos-pi-configs/configuration.nix` + modules)
The sensor configuration includes the same packages, split across:
- Main configuration: Core tools and Python packages
- `modules/kismet.nix`: Kismet and related tools, RTL-SDR packages
- `modules/netbird.nix`: Netbird package

Additional items in sensor config (not needed in bootstrap):
- Helper scripts (`netbird-fix`, `sensor-status`, etc.) - Generated at runtime
- Service configurations - Applied during `nixos-rebuild`

## Maintenance Notes

When adding new packages to `nixos-pi-configs`:

1. **Check if it's a runtime dependency**: If the package is needed for services to run (not just helper scripts), add it to the bootstrap image.

2. **Update bootstrap image**: Add the package to `nix-sensor/bootstrap-image/configuration.nix`

3. **Test the alignment**: Run the comparison script:
   ```bash
   cd nix-sensor/bootstrap-image/scripts
   ./compare-packages.sh
   ```

4. **Rebuild and test**: 
   ```bash
   cd nix-sensor/bootstrap-image
   ./build-image.sh -p <PSK>
   ```

## Recent Changes (2024)

- ✅ Added `netbird` package for VPN support
- ✅ Added `rtl-sdr` and `rtl_433` for radio monitoring
- ✅ Added Python packages: `gps3`, `setuptools`, `protobuf`, `numpy`
- ✅ Verified all Kismet dependencies are included

## Excluded from Bootstrap

These items are intentionally NOT in the bootstrap image:

1. **Helper Scripts**: Generated at runtime via `writeScriptBin`
   - `netbird-fix`, `netbird-enroll`, `sensor-status`
   - `gps-check`, `kismet-config`, `kismet-logs`

2. **Service Configurations**: Applied during `nixos-rebuild`
   - Systemd services
   - Firewall rules
   - User configurations

3. **Discovery-specific data**: Applied from discovery service
   - Hostname
   - SSH keys
   - Netbird setup key

These exclusions are correct - they're either generated dynamically or applied from the discovery service.

## Verification

To verify alignment after changes:

```bash
# Compare package lists
cd nix-sensor/bootstrap-image
nix eval --json '.#nixosConfigurations.custom-bootstrap.config.environment.systemPackages' | jq -r '.[]' | sort > /tmp/bootstrap-pkgs.txt

cd nixos-pi-configs  
nix eval --json '.#nixosConfigurations.sensor.config.environment.systemPackages' | jq -r '.[]' | sort > /tmp/sensor-pkgs.txt

# Show differences
diff /tmp/bootstrap-pkgs.txt /tmp/sensor-pkgs.txt
```

## Performance Impact

With aligned packages:
- **Before**: `nixos-rebuild switch` took 10-15 minutes (downloading packages)
- **After**: `nixos-rebuild switch` takes 2-3 minutes (only configuration changes)

This represents an 80% reduction in bootstrap time after initial registration!