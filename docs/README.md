# Documentation

Comprehensive documentation for the NixOS Raspberry Pi sensor system.

## 📚 **Documentation Structure**

*This directory is prepared for expanded documentation including:*

### **Available Documentation**
- **`bootstrap-commands.md`** - Direct build commands reference
- **`bootstrap-troubleshooting.md`** - CachyOS build troubleshooting checklist
- **`bootstrap-walkthrough.md`** - Complete build process walkthrough
- **`cachyos-setup.md`** - Prerequisites installation for CachyOS
- **`package-alignment.md`** - Bootstrap and sensor package alignment

### **Planned Documentation**
- `deployment-guide.md` - End-to-end deployment walkthrough
- `troubleshooting.md` - Common issues and solutions  
- `hardware-guide.md` - Pi setup, cases, antennas, GPS modules
- `security-guide.md` - Security best practices and considerations
- `scaling-guide.md` - Managing larger sensor deployments

## 📖 **Current Documentation**

For now, documentation is distributed across component directories:

### **Getting Started**
1. **[Main README](../README.md)** - Project overview and quick start
2. **[Discovery Service](../discovery-service/README.md)** - Service setup and deployment
3. **[Bootstrap Images](../bootstrap-image/README.md)** - Image building and commands
4. **[Sensor Template](../sensor-template/README.md)** - Configuration profiles

### **Technical References**
- **[Direct Build Commands](../bootstrap-image/COMMANDS.md)** - Transparent build reference
- **[Network Configuration](../bootstrap-image/network-config.nix)** - Ethernet setup
- **[Hardware Configuration](../bootstrap-image/hardware-configuration.nix)** - Pi hardware settings

## 🎯 **Quick Reference**

### **Essential Commands**
```bash
# Generate PSK
cd discovery-service && python3 generate_psk.py

# Build bootstrap image
cd bootstrap-image && ./build-image.sh -p <psk>

# Flash SD card
sudo dd if=result/*.img of=/dev/sdX bs=4M status=progress

# Monitor deployment
cd discovery-service && docker-compose logs -f
```

### **Common Issues**
- **Pi not registering**: Check ethernet and discovery service logs
- **Build fails**: See bootstrap-image/README.md troubleshooting section
- **Network timeout**: Verify DHCP and internet connectivity

## 🤝 **Contributing Documentation**

When adding new documentation:
1. Keep component-specific docs in their respective directories
2. Use this docs/ directory for cross-component guides
3. Update this README with links to new documentation
4. Follow the established format and structure