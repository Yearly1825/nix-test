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
│   │   ├── main.py          # API endpoints and routes
│   │   ├── models.py        # Database models
│   │   ├── config.py        # Configuration management
│   │   ├── security.py      # PSK authentication
│   │   ├── database.py      # Database operations
│   │   ├── logging.py       # Logging configuration
│   │   └── notifications.py # NTFY integration
│   ├── client_example.py    # Example client implementation
│   ├── bootstrap_client.py  # Bootstrap registration client
│   ├── generate_psk.py      # PSK generation (deprecated)
│   ├── docker-compose.yml   # Easy deployment
│   ├── Dockerfile           # Container definition
│   ├── requirements.txt     # Python dependencies
│   ├── nginx.conf           # Reverse proxy config
│   └── entrypoint.sh        # Container startup script
│
├── 📁 bootstrap-image/       # SD card image builder
│   ├── README.md            # Build instructions and commands
│   ├── build.sh             # Automated build script
│   ├── flake.nix            # NixOS image definition
│   ├── flake.lock           # Locked dependencies
│   ├── configuration.nix    # Bootstrap system config
│   ├── hardware-configuration.nix  # Pi hardware settings
│   └── network-config.nix   # Ethernet bootstrap networking
│
├── 📁 docs/                 # Extended documentation
│   ├── README.md            # Documentation hub
│   ├── bootstrap-troubleshooting.md # Bootstrap debugging
│   ├── bootstrap-walkthrough.md # Step-by-step guide
│   ├── bootstrap-commands.md # Command reference
│   ├── cachyos-setup.md     # CachyOS specific setup
│   └── CachyOS Raspberry Pi Bootstrap Preparation
│
├── 📄 setup_deployment.py   # Unified configuration system
└── 📄 README.md             # This overview (you are here)
```

## 🚀 **Quick Start**

### **🎯 Unified Setup (Recommended)**

Configure everything from one place with the unified configuration system:

```bash
# 1. Interactive setup - configures discovery service AND bootstrap images
python3 setup_deployment.py

# 2. Deploy discovery service
cd discovery-service && docker-compose up -d

# 3. Build bootstrap image (reads shared config automatically)
cd ../bootstrap-image && ./build.sh

# 4. Flash and deploy (compressed image)
zstd -d result/sd-image/*.img.zst --stdout | sudo dd of=/dev/sdX bs=4M status=progress
```

**✅ Benefits:** No copy-paste errors, NTFY notifications, single source of truth

### **📋 Manual Setup (Alternative)**

For manual configuration or CI/CD workflows:

**Step 1: Discovery Service**
```bash
cd discovery-service/
python3 generate_psk.py  # DEPRECATED: Use unified setup instead
# Edit config/config.yaml with your settings - DEPRECATED
docker-compose up -d     # Start the service
```

**Note:** The `generate_psk.py` script is deprecated. Use the unified configuration system for new deployments.

**Step 2: Bootstrap Images**
```bash
cd bootstrap-image/
# DEPRECATED: Use ./build.sh without parameters (reads .deployment.yaml)
./build.sh  # Build with unified config
```

**Step 3: Flash and Deploy**
```bash
# For compressed images (default)
zstd -d result/sd-image/*.img.zst --stdout | sudo dd of=/dev/sdX bs=4M status=progress
# Or for uncompressed images
sudo dd if=result/*.img of=/dev/sdX bs=4M status=progress
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

## 📋 **Requirements & Installation**

### **Prerequisites Installation (CachyOS/Arch Linux)**

Before using this system, install required packages and configure your build environment:

```bash
# 1. Install Required System Packages
paru -S nix docker docker-compose python python-yaml git base-devel qemu-user-static qemu-user-static-binfmt

# 2. Configure Nix for Cross-Compilation
sudo tee /etc/nix/nix.conf << 'EOF'
experimental-features = nix-command flakes
extra-platforms = aarch64-linux
system-features = nixos-test benchmark big-parallel kvm
trusted-users = root @wheel
EOF

# 3. Enable Services
sudo systemctl enable --now nix-daemon.service
sudo systemctl enable --now docker.service
sudo systemctl enable --now systemd-binfmt.service

# 4. Add user to docker group
sudo usermod -aG docker $USER

# 5. Reboot for changes to take effect
# Reboot or re-login for group changes to take effect
```

**For detailed CachyOS setup instructions, see: [CachyOS Setup Guide](docs/cachyos-setup.md)**

### **System Requirements**

### **Discovery Service Host**
- Linux system with Docker
- Network accessible to sensors
- ~100MB RAM, minimal CPU

### **Build Machine**
- Nix package manager with flakes enabled
- ARM64 emulation support (QEMU)
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

### **Configuration Reference**
- **[Unified Configuration](setup_deployment.py)** - Single configuration system for all components
- **[Network Configuration](bootstrap-image/network-config.nix)** - Ethernet-only bootstrap networking
- **[Hardware Support](bootstrap-image/hardware-configuration.nix)** - Raspberry Pi hardware settings
- **[NixOS Image Definition](bootstrap-image/flake.nix)** - Complete system configuration

### **Extended Documentation**
- **[Documentation Hub](docs/README.md)** - Extended guides and references
- **[CachyOS Setup Guide](docs/cachyos-setup.md)** - Host system preparation
- **[Bootstrap Troubleshooting](docs/bootstrap-troubleshooting.md)** - Common issues and solutions

## 🔧 **Development Workflow**

### **Initial Setup**
```bash
# 1. Clone repository
git clone <your-repo-url>
cd nix-sensor

# 2. Configure deployment (unified setup)
python3 setup_deployment.py

# 3. Start discovery service
cd discovery-service && docker-compose up -d

# 4. Build bootstrap image (reads unified config)
cd ../bootstrap-image && ./build.sh
```

### **Sensor Deployment**
```bash
# Flash SD card (compressed image)
zstd -d result/sd-image/*.img.zst --stdout | sudo dd of=/dev/sdX bs=4M status=progress

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

---

**💡 Pro Tip**: Start with the [Discovery Service README](discovery-service/README.md) for your first deployment, then move to [Bootstrap Image Builder](bootstrap-image/README.md) for creating SD card images.
