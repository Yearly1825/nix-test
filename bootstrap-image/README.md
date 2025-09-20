# SD Card Image Builder

**Creates custom SD card images that configure your Raspberry Pis automatically.**

## Quick Build

**Step 1:** Configure everything (if you haven't already):
```bash
cd .. && python3 setup_deployment.py
```

**Step 2:** Build your custom image:
```bash
cd bootstrap-image && ./build.sh
```

**That's it!** You'll get a `.img.zst` file ready to flash to SD cards.



## First Time Setup

**Need to install prerequisites?** Follow the [CachyOS Setup Guide](../docs/cachyos-setup.md).

The build script automatically:
- Detects your platform (x86_64 → aarch64 cross-compilation)  
- Adds stability flags for CachyOS/Arch systems
- Handles all the technical details for you

**Just run `./build.sh` and it works!**

## What You Need

**For Your Raspberry Pi:**
- Raspberry Pi 4 (2GB+ RAM recommended)
- 16GB+ SD card
- **Ethernet cable** (WiFi disabled during setup for security)
- DHCP network with internet access

**The build script automatically gets everything else from your configuration!**

## Build Options

```bash
./build.sh [OPTIONS]

Options:
  --ntfy-test          Test notifications before building
  -o, --output <DIR>   Put image in different folder  
  -h, --help           Show help
```

**Most of the time you just run:** `./build.sh`



## Complete Workflow

### 1. Configure (Once)
```bash
cd .. && python3 setup_deployment.py
```

### 2. Build Image
```bash
./build.sh
```

### 3. Flash to SD Card
```bash
# Find your SD card
lsblk

# Flash (CAREFUL: Replace sdX with your actual device!)
zstd -d result/sd-image/*.img.zst --stdout | sudo dd of=/dev/sdX bs=4M status=progress
```

### 4. Boot and Watch
```bash
# Start discovery service (if not running)
cd ../discovery-service && docker-compose up -d

# Insert SD card in Pi, connect ethernet, power on
# Check logs to see your Pi register:
docker-compose logs -f discovery-service
```

**Your Pi will automatically configure itself in ~10 minutes!**

## Something Wrong?

**Common issues and quick fixes:**

**Error: "nix: command not found"**
→ Install Nix: [CachyOS Setup Guide](../docs/cachyos-setup.md)

**Error: "Configuration not found"**  
→ Run setup first: `cd .. && python3 setup_deployment.py`

**Build fails**
→ See [Troubleshooting Guide](../docs/bootstrap-troubleshooting.md)

**The build script handles most issues automatically!**

## Security Note

⚠️ **Your built image contains your security keys** - don't share the `.img.zst` file with others.

## What's Next?

After building your image:

1. **Flash to SD cards:** `zstd -d result/sd-image/*.img.zst --stdout | sudo dd of=/dev/sdX bs=4M status=progress`
2. **Boot Pis with ethernet**  
3. **Watch discovery service logs:** `docker-compose logs -f discovery-service`
4. **Pis configure themselves automatically!**

For more help, see the [main README](../README.md).