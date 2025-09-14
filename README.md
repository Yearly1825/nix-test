# NixOS Raspberry Pi Sensor System

A complete NixOS configuration for deploying Raspberry Pi 4 devices as network sensors with Kismet wireless monitoring, Netbird VPN connectivity, and secure SSH access.

## 🎯 **Overview**

This project provides a **zero-touch deployment system** for Raspberry Pi sensor fleets. Flash an SD card, boot with ethernet, and devices automatically:

- Register with a discovery service
- Receive unique hostnames (`SENSOR-01`, `SENSOR-02`, etc.)
- Download and apply configurations from your Git repository
- Join your VPN automatically
- Begin monitoring tasks

## 🏗️ **Architecture**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Fresh Pi      │───▶│ Discovery       │───▶│ Your Config     │
│   (Bootstrap)   │    │ Service         │    │ Repository      │
│                 │    │                 │    │                 │
│ • Ethernet only │    │ • PSK Auth      │    │ • NixOS Flake   │
│ • Hardware ID   │    │ • Encrypted     │    │ • Sensor Configs│
│ • Auto register │    │ • Sequential    │    │ • VPN Setup     │
└─────────────────┘    │   Hostnames     │    └─────────────────┘
                       │ • SSH Keys      │
                       └─────────────────┘
                               │
                               ▼
                    ┌─────────────────┐
                    │ Configured      │
                    │ Sensor Node     │
                    │                 │
                    │ • Kismet        │
                    │ • Netbird VPN   │
                    │ • SSH Hardened  │
                    │ • Monitoring    │
                    └─────────────────┘
```

## 📦 **Repository Structure**

This repository contains three main components:

```
nix-sensor/
├── 📁 discovery-service/     # Registration and configuration service
│   ├── README.md            # Setup and deployment guide
│   ├── app/                 # FastAPI application
│   ├── config/              # Configuration templates
│   └── docker-compose.yml   # Easy deployment
│
├── 📁 bootstrap-image/       # SD card image builder
│   ├── README.md            # Build instructions and commands
│   ├── build-image.sh       # Automated build script
│   ├── flake.nix            # NixOS image definition
│   └── configuration.nix    # Bootstrap system config
│
├── 📁 sensor-template/       # Sensor configuration templates
│   ├── README.md            # Usage and customization guide
│   ├── flake.nix            # Profile-based configurations
│   ├── profiles/            # Different sensor configurations
│   │   ├── full-sensor.nix  # Complete monitoring stack
│   │   ├── wireless-monitor.nix  # Wireless monitoring only
│   │   └── minimal.nix      # Basic connectivity
│   ├── base/                # Shared configuration
│   └── modules/             # NixOS sensor modules
│       ├── kismet.nix       # Wireless monitoring
│       ├── netbird.nix      # VPN connectivity
│       └── ssh.nix          # Hardened SSH access
│
├── 📁 scripts/              # Deployment helper scripts
├── 📁 docs/                 # Extended documentation
└── 📄 README.md             # This overview (you are here)
```

## 🚀 **Quick Start**

### **Step 1: Deploy Discovery Service**

The discovery service manages device registration and provides configuration:

```bash
cd discovery-service/
python3 generate_psk.py  # Generate secure keys
# Edit config/config.yaml with your settings
docker-compose up -d     # Start the service
```

**📖 [Complete Discovery Service Setup →](discovery-service/README.md)**

### **Step 2: Build Bootstrap Images**

Create SD card images that automatically register with your discovery service:

```bash
cd bootstrap-image/
./build-image.sh -p <your-psk>  # Build with your PSK
```

**📖 [Complete Build Instructions →](bootstrap-image/README.md)**

### **Step 3: Flash and Deploy**

Flash SD cards and deploy sensors:

```bash
sudo dd if=result/nixos-sd-image-*.img of=/dev/sdX bs=4M status=progress
# Insert SD card in Pi, connect ethernet, power on
# Watch discovery service logs for registration
```

## ✨ **Key Features**

### **🔐 Security-First Design**
- **PSK Authentication**: Pre-shared keys burned into images
- **Encrypted Payloads**: AES-256-GCM for sensitive configuration
- **SSH Hardening**: Public key only, fail2ban protection
- **VPN-First**: All sensors join secure Netbird VPN

### **📡 Network Monitoring**
- **Kismet**: Professional wireless packet analysis
- **GPS Integration**: Location-aware monitoring
- **Multiple Formats**: PCAPNG, CSV, JSON output
- **Web Interface**: Real-time monitoring dashboard

### **⚙️ Automated Management**
- **Zero-Touch Deploy**: Flash, boot, done
- **Sequential Naming**: Automatic hostname assignment
- **Config Management**: Git-based configuration
- **Remote Updates**: NixOS declarative rebuilds

### **🔄 Scalable Architecture**
- **Horizontal Scaling**: Add Pis without config changes
- **Centralized Control**: Single discovery service
- **Stateless Nodes**: Identical, replaceable sensors
- **Rolling Updates**: Update all nodes from Git

## 📋 **Requirements**

### **Discovery Service Host**
- Linux system with Docker
- Network accessible to sensors
- ~100MB RAM, minimal CPU

### **Build Machine** 
- Nix package manager
- 8GB+ free disk space
- SD card reader

### **Target Hardware**
- Raspberry Pi 4 (2GB+ RAM)
- 16GB+ SD cards
- Ethernet connection (required for bootstrap)

## 📚 **Documentation**

### **Component Guides**
- **[Discovery Service Setup](discovery-service/README.md)** - FastAPI service deployment and configuration
- **[Bootstrap Image Builder](bootstrap-image/README.md)** - SD card image creation and commands
- **[Direct Build Commands](bootstrap-image/COMMANDS.md)** - Transparent build command reference
- **[Sensor Templates](sensor-template/README.md)** - Configuration profiles and customization

### **Configuration Reference**
- **[Sensor Profiles](sensor-template/profiles/)** - Pre-built sensor configurations
  - `full-sensor.nix` - Complete monitoring stack with all tools
  - `wireless-monitor.nix` - Lightweight wireless monitoring
  - `minimal.nix` - Basic connectivity only
- **[NixOS Modules](sensor-template/modules/)** - Kismet, VPN, and SSH configurations
- **[Network Configuration](bootstrap-image/network-config.nix)** - Ethernet-only bootstrap networking
- **[Hardware Support](bootstrap-image/hardware-configuration.nix)** - Raspberry Pi hardware settings

### **Extended Documentation**
- **[Scripts](scripts/README.md)** - Deployment automation helpers
- **[Documentation Hub](docs/README.md)** - Extended guides and references

## 🔧 **Development Workflow**

### **Initial Setup**
```bash
# 1. Clone repository
git clone <your-repo-url>
cd nix-sensor

# 2. Generate discovery service keys
cd discovery-service && python3 generate_psk.py

# 3. Configure discovery service
vim config/config.yaml  # Add your settings

# 4. Start discovery service
docker-compose up -d

# 5. Build bootstrap image
cd ../bootstrap-image
./build-image.sh -p <your-psk>
```

### **Sensor Deployment**
```bash
# Flash SD card
sudo dd if=result/*.img of=/dev/sdX bs=4M status=progress

# Monitor registration
cd ../discovery-service
docker-compose logs -f
```

### **Configuration Updates**
```bash
# Update your sensor config repository
git push origin main

# Sensors will pull updates on next rebuild
# Or trigger remote rebuild via SSH
```

## 🛠️ **Troubleshooting**

### **Common Issues**

| Problem | Solution |
|---------|----------|
| Pi not registering | Check ethernet connection and discovery service logs |
| Build fails | See [build troubleshooting](bootstrap-image/README.md#troubleshooting) |
| Network timeout | Verify DHCP and internet connectivity |
| PSK errors | Regenerate PSK and rebuild images |

### **Debug Commands**

```bash
# Check discovery service status
curl http://<discovery-ip>:8080/health

# Monitor sensor bootstrap (via SSH)
ssh root@<sensor-ip>  # password: bootstrap
journalctl -f -u pi-bootstrap

# View discovery service logs
docker-compose logs -f discovery-service
```

## 🤝 **Contributing**

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test on actual hardware
4. Submit a pull request

## 📄 **License**

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 **Acknowledgments**

- **[NixOS](https://nixos.org/)** - Declarative system configuration
- **[Kismet](https://www.kismetwireless.net/)** - Wireless network monitoring
- **[Netbird](https://netbird.io/)** - Modern VPN solution
- **Raspberry Pi Foundation** - Amazing hardware platform

---

**💡 Pro Tip**: Start with the [Discovery Service README](discovery-service/README.md) for your first deployment, then move to [Bootstrap Image Builder](bootstrap-image/README.md) for creating SD card images.

**🔒 Security Note**: This system is designed for legitimate security research and network monitoring. Ensure compliance with local laws and obtain proper authorization before monitoring wireless networks.