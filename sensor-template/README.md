# Sensor Template

This directory contains NixOS configuration templates for Raspberry Pi sensors. Use these configurations as the target for your bootstrap process.

## 📋 **Available Profiles**

### **full-sensor** (Recommended)
Complete sensor stack with all network monitoring tools:
- Kismet (wireless monitoring)  
- aircrack-ng (wireless security testing)
- hcxdumptool (packet capture)
- tcpdump, tshark (network analysis)
- GPS support
- Netbird VPN
- Hardened SSH

### **wireless-monitor** 
Lightweight wireless monitoring only:
- Kismet (wireless monitoring)
- Basic network tools
- Netbird VPN
- SSH access

### **minimal**
Bare minimum for basic connectivity:
- Netbird VPN
- SSH access
- Essential system tools

## 🚀 **Usage**

### **For Bootstrap Process**
Your discovery service should reference one of these profiles:

```bash
# In your sensor configuration repository
export CONFIG_REPO_URL="github:yourusername/your-sensor-configs"

# Bootstrap will call:
nixos-rebuild switch --flake "${CONFIG_REPO_URL}#full-sensor"
```

### **For Direct Deployment**
```bash
# Deploy full sensor stack
nixos-rebuild switch --flake .#full-sensor

# Deploy wireless monitor only  
nixos-rebuild switch --flake .#wireless-monitor

# Deploy minimal configuration
nixos-rebuild switch --flake .#minimal
```

## 🛠️ **Customization**

1. **Fork or copy this template** to your own repository
2. **Edit profiles/** files to customize each configuration
3. **Modify base/configuration.nix** for common settings
4. **Add new profiles** by creating files in profiles/ directory

## 📁 **Directory Structure**

```
sensor-template/
├── flake.nix              # Defines available profiles
├── hardware-configuration.nix  # Pi-specific settings
├── base/
│   └── configuration.nix  # Common configuration
├── profiles/
│   ├── full-sensor.nix    # Complete sensor stack
│   ├── wireless-monitor.nix  # Wireless monitoring only
│   └── minimal.nix        # Minimal configuration  
└── modules/               # NixOS modules
    ├── kismet.nix         # Wireless monitoring
    ├── netbird.nix        # VPN connectivity  
    └── ssh.nix            # Hardened SSH
```

## 🔧 **Environment Variables**

These configurations support environment variables from the bootstrap process:

- `NETBIRD_SETUP_KEY` - VPN enrollment key
- `ASSIGNED_HOSTNAME` - Hostname from discovery service
- `GPS_DEVICE` - GPS device path (optional)

## 📚 **Next Steps**

1. **Copy this template** to your own repository
2. **Update discovery service** to point to your repository
3. **Test with a single Pi** before mass deployment
4. **Customize profiles** as needed for your use case

For more information, see the main [repository README](../README.md).