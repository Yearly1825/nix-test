# NixOS Raspberry Pi Sensor System

**Create a fleet of Raspberry Pi sensors that configure themselves automatically!**

Flash an SD card, plug in ethernet, and watch your Pi become a fully configured network sensor within minutes. No manual setup required.

## 🎯 **What This Does**

Flash an SD card → Boot Pi with ethernet → **Done!**

Your Pi will automatically:
- Get a unique name (`SENSOR-01`, `SENSOR-02`, etc.)
- Download its configuration from your Git repository
- Join your VPN securely
- Start monitoring network traffic
- Send you notifications when ready

Perfect for deploying multiple identical sensors across different locations.

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

## 📦 **What's In This Repository**

Three simple components that work together:

```
nix-sensor/
├── 📄 setup_deployment.py   # ← Start here! Configure everything
├── 📁 discovery-service/     # ← Service that assigns names to your Pis
├── 📁 bootstrap-image/       # ← Builds the SD card images
└── 📁 docs/                 # ← Help guides if you get stuck
```

**You only need to work with these files:**
- `setup_deployment.py` - One-time configuration
- `discovery-service/` - Start the naming service
- `bootstrap-image/` - Build SD card images

## 🚀 **Quick Start**

**Total time: ~30 minutes** (most of it is waiting for downloads)

### **Step 1: Configure Everything** ⚙️

```bash
# Run the setup wizard - it asks questions and sets everything up
python3 setup_deployment.py
```

This wizard will:
- Generate security keys
- Ask for your VPN settings
- Set up your SSH keys
- Test notifications (optional)

### **Step 2: Start the Discovery Service** 🚀

Choose **Option A** (with Docker) or **Option B** (without Docker):

#### **Option A: With Docker (Easier)**
```bash
cd discovery-service
docker-compose up -d
```

#### **Option B: Without Docker**
```bash
cd discovery-service
pip install -r requirements.txt
python -m app.main
```

### **Step 3: Build Your SD Card Image** 💿

```bash
cd bootstrap-image
./build.sh
```

This creates a custom SD card image with your settings built-in.

### **Step 4: Flash and Boot** ⚡

```bash
# Find your SD card (replace sdX with your actual device like sdb, sdc, etc.)
lsblk

# Flash the image (CAUTION: This erases the SD card!)
zstd -d result/sd-image/*.img.zst --stdout | sudo dd of=/dev/sdX bs=4M status=progress

# Insert SD card in Pi, connect ethernet cable, power on
# Pi will automatically configure itself in ~10 minutes
```

**That's it!** Your Pi will appear in your discovery service logs and join your VPN automatically.

## ✨ **What You Get**

🔐 **Secure by Default**
- Each Pi gets unique encryption keys
- All traffic goes through your VPN
- SSH access with your public keys only

📡 **Professional Monitoring**
- Kismet wireless packet analysis
- GPS location tracking (if available)
- Multiple export formats (PCAP, CSV, JSON)
- Web dashboard for real-time monitoring

⚙️ **Zero Maintenance**
- Flash once, deploy anywhere
- Automatic unique naming (`SENSOR-01`, `SENSOR-02`, etc.)
- Update all sensors by pushing to Git
- No manual configuration needed

🔄 **Scales Easily**
- Add more Pis without changing anything
- One discovery service handles hundreds of devices
- Identical, replaceable sensors

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

### **What You Need**

**Your Computer** (to build images):
- Linux (CachyOS/Arch recommended, but any works)
- 8GB+ free disk space
- SD card reader
- Internet connection

**Discovery Service** (can be same computer):
- Any Linux system
- Docker (optional - can run without it)
- Accessible from your network

**Raspberry Pis**:
- Raspberry Pi 4 (2GB+ RAM recommended)
- 16GB+ SD cards
- **Ethernet cable required** (WiFi disabled during setup for security)

## 🆘 **Getting Help**

**Something not working?** Check these in order:

1. **[CachyOS Setup Guide](docs/cachyos-setup.md)** - Installing prerequisites
2. **[Troubleshooting Guide](docs/bootstrap-troubleshooting.md)** - Common issues and fixes
3. **Component guides** if you need to dive deeper:
   - [Discovery Service](discovery-service/README.md)
   - [Bootstrap Images](bootstrap-image/README.md)

## 🔧 **Daily Operations**

### **Deploy More Sensors**
```bash
# Just flash more SD cards with the same image!
zstd -d result/sd-image/*.img.zst --stdout | sudo dd of=/dev/sdX bs=4M status=progress
# Each Pi gets a unique name automatically
```

### **Monitor Your Fleet**
```bash
# Check discovery service logs
docker-compose logs -f discovery-service

# Or without Docker:
cd discovery-service && python -m app.main
```

### **Update All Sensors**
```bash
# Update your sensor config repository
git push origin main
# All sensors will update automatically on next reboot
```

## 🛠️ **Troubleshooting**

**Something not working? Here's what to check:**

**Pi not appearing in logs:**
- Is ethernet cable connected?
- Is discovery service running? (`curl http://localhost:8080/health`)
- Check discovery service logs: `docker-compose logs -f discovery-service`

**Build fails:**
- Follow [CachyOS setup guide](docs/cachyos-setup.md) for prerequisites
- Run configuration first: `python3 setup_deployment.py`

**Can't flash SD card:**
- Check if SD card is mounted: `umount /dev/sdX*` (replace sdX)
- Use correct device name from `lsblk`

**Need detailed help?** See [troubleshooting guide](docs/bootstrap-troubleshooting.md)

---

## ❓ **Need More Help?**

- **[CachyOS Setup Guide](docs/cachyos-setup.md)** - Install prerequisites
- **[Troubleshooting Guide](docs/bootstrap-troubleshooting.md)** - Fix common issues
- **[Discovery Service Guide](discovery-service/README.md)** - Service details
- **[Image Builder Guide](bootstrap-image/README.md)** - Build details

**This system is designed to "just work" - if it doesn't, the guides above will help!**
