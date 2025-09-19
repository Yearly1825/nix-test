# Building Bootstrap Images: Complete Walkthrough

This document walks through the entire build process step-by-step, documenting common errors and solutions for new users.

## Your Current Error

You're seeing this error because Nix is not installed on your CachyOS system:

```bash
~/nix-test/bootstrap-image main
❯ ./build.sh
[INFO] 🚀 Bootstrap Image Builder (Unified Configuration)
[INFO] =================================================
[INFO] 📋 Reading configuration from ../.deployment.yaml
[INFO] ✅ Configuration loaded successfully
[INFO] 🏗  Building with configuration:
[INFO]   Deployment:     SENSOR
[INFO]   PSK:            0e5b7df6e35f835c... (truncated)
[INFO]   Service IP:     192.168.3.110:8080
[INFO]   Config Repo:    github:yearly1825/nixos-pi-configs
[INFO]   Output Dir:     ./result
[INFO]   NTFY:           Enabled (https://ntfy.sh/nixoscachyos1)

[INFO] 🔄 Cross-compiling from x86_64 to aarch64
[INFO] 🐧 CachyOS detected, adding stability flags
[INFO] 🔨 Starting build process...
./build.sh: line 252: nix: command not found
[ERROR] ❌ Build failed!
```

**What this means:** Your system needs Nix installed before it can build NixOS images.

## Step-by-Step Resolution

### Step 1: Install Nix Package Manager

The most important missing dependency is Nix itself. Install it using the Determinate Systems installer (recommended for CachyOS):

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

**What to expect:**
- Installation takes 2-5 minutes
- You'll see systemd service setup messages
- May prompt for sudo password

**Expected output:**
```
Nix was installed successfully!
To get started using Nix, open a new shell or run `. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`
```

### Step 2: Reload Your Shell Environment

After installation, you need to make Nix available in your current shell:

```bash
# Option 1: Source the nix profile (immediate)
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# Option 2: Start a new shell session
exec $SHELL

# Option 3: Close and reopen your terminal
```

**Verify it worked:**
```bash
nix --version
# Should output: nix (Nix) 2.18.1 (or similar)
```

**If you still get "command not found":**
```bash
# Check if nix-daemon is running
sudo systemctl status nix-daemon

# Start it if it's not running
sudo systemctl enable nix-daemon
sudo systemctl start nix-daemon

# Try sourcing again
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### Step 3: Configure Nix for Cross-Compilation

Create the Nix configuration to enable features needed for building Raspberry Pi images:

```bash
# Create config directory
mkdir -p ~/.config/nix

# Add required configuration
cat > ~/.config/nix/nix.conf << 'EOF'
experimental-features = nix-command flakes
extra-platforms = aarch64-linux
max-jobs = auto
cores = 0
EOF
```

**What each setting does:**
- `experimental-features`: Enables modern Nix commands (required by our build)
- `extra-platforms`: Allows cross-compilation from x86_64 to aarch64 (Pi architecture)
- `max-jobs`: Use all CPU cores for faster builds
- `cores`: Use all threads per job

### Step 4: Install System Dependencies

Your CachyOS system needs these packages for the build process:

```bash
# Using paru (your preferred package manager)
paru -S --needed python python-pip python-yaml curl git

# Verify Python and pip are working
python3 --version
pip3 --version
```

**Why these are needed:**
- `python3`: Required by build.sh to parse .deployment.yaml
- `python-yaml`: Required to parse YAML configuration
- `curl/git`: Used by Nix to fetch dependencies

### Step 5: Verify Your Build Environment

Test that all components are working:

```bash
# Test Nix installation
nix --version

# Test flakes support (required by our build)
nix flake --help

# Test cross-compilation capability
nix eval --expr 'builtins.hasAttr "aarch64-linux" (import <nixpkgs> {}).lib.systems.examples'
# Should output: true

# Test Python YAML parsing
python3 -c "import yaml; print('YAML support: OK')"
```

### Step 6: Re-run the Build

Now try your build command again:

```bash
cd ~/nix-test/bootstrap-image
./build.sh
```

**What to expect now:**
1. Configuration parsing should work
2. Nix will start downloading packages (first time will be slow)
3. Cross-compilation will begin
4. Build will take 15-30 minutes on first run

## Expected Build Output Progression

### Phase 1: Configuration Loading ✅ (You already see this)
```
[INFO] 🚀 Bootstrap Image Builder (Unified Configuration)
[INFO] 📋 Reading configuration from ../.deployment.yaml
[INFO] ✅ Configuration loaded successfully
```

### Phase 2: Build Setup ✅ (You already see this)
```
[INFO] 🏗  Building with configuration:
[INFO] 🔄 Cross-compiling from x86_64 to aarch64
[INFO] 🐧 CachyOS detected, adding stability flags
```

### Phase 3: Nix Build (What happens next)
```
[INFO] 🔨 Starting build process...
these 2 derivations will be built:
  /nix/store/xxx-nixos-system-custom-bootstrap-25.11.xxxx.drv
  /nix/store/xxx-nixos-sd-image-*.img.drv
these X paths will be fetched (Y.Z MiB download, A.B MiB unpacked):
  /nix/store/...
```

### Phase 4: Package Downloads
```
copying path '/nix/store/...' from 'https://cache.nixos.org'...
copying path '/nix/store/...' from 'https://cache.nixos.org'...
```
*This phase can take 10-20 minutes depending on your internet speed*

### Phase 5: Building
```
building '/nix/store/xxx-nixos-system-custom-bootstrap-25.11.xxx.drv'...
building '/nix/store/xxx-nixos-sd-image-*.img.drv'...
```
*This phase can take 5-15 minutes depending on your CPU*

### Phase 6: Success
```
[INFO] ✅ Build completed successfully!
[INFO] 📀 Image file: /path/to/result/sd-image/nixos-sd-image-*.img
[INFO] 📏 Image size: 2.1G
```

## Common Errors and Solutions

### Error: "experimental-features not enabled"
```bash
error: experimental Nix feature 'nix-command' is disabled
```

**Solution:**
```bash
# Add to nix.conf
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### Error: "system aarch64-linux is not supported" OR "not a trusted user"
```bash
error: a 'aarch64-linux' with features {} is required to build '/nix/store/...', but I am a 'x86_64-linux'
```
OR
```bash
warning: ignoring the client-specified setting 'extra-platforms', because it is a restricted setting and you are not a trusted user
```

**Solution (requires both steps):**
```bash
# 1. Add to nix.conf
echo "extra-platforms = aarch64-linux" >> ~/.config/nix/nix.conf

# 2. CRITICAL: Add yourself as trusted user
echo "trusted-users = root $USER" | sudo tee -a /etc/nix/nix.conf

# 3. Restart nix daemon (REQUIRED)
sudo systemctl restart nix-daemon
```

### Error: Sandbox issues on CachyOS
```bash
error: unable to start build process: Operation not permitted
```

**Solution:** The build script automatically adds `--option sandbox false` for CachyOS. If you're using direct nix commands:
```bash
nix build --option sandbox false ...
```

### Error: Out of disk space
```bash
error: not enough free disk space at '/nix/store'
```

**Solutions:**
```bash
# Check available space
df -h /nix

# Clean up old builds
nix-collect-garbage -d

# If needed, clean more aggressively
nix-collect-garbage --delete-older-than 7d
```

### Error: Network timeout
```bash
error: unable to download 'https://cache.nixos.org/...': timeout
```

**Solution:**
```bash
# The build script will retry automatically, but you can also:
# Increase timeout in nix.conf
echo "connect-timeout = 60" >> ~/.config/nix/nix.conf
echo "stalled-download-timeout = 300" >> ~/.config/nix/nix.conf
```

### Error: "no space left on device" in /tmp
```bash
error: cannot create temporary directory: No space left on device
```

**Solution:**
```bash
# Check /tmp space
df -h /tmp

# Set different temp directory
export TMPDIR=/var/tmp
# or
export TMPDIR=$HOME/tmp && mkdir -p $HOME/tmp
```

## Performance Expectations

### First Build (Cold Cache)
- **Download time**: 10-20 minutes (depends on internet speed)
- **Build time**: 15-30 minutes (depends on CPU)
- **Total time**: 25-50 minutes
- **Disk usage**: ~8-10 GB in /nix/store

### Subsequent Builds (Warm Cache)
- **Download time**: 1-2 minutes (only changed packages)
- **Build time**: 5-10 minutes
- **Total time**: 6-12 minutes

### CachyOS Performance Tips
```bash
# Check if you're using CachyOS optimized kernel
uname -r
# Should show something like: 6.x.x-cachyos

# Enable performance governor during build
sudo cpupower frequency-set -g performance

# Monitor build progress
# Terminal 1: Run build
./build.sh

# Terminal 2: Monitor resources
htop  # CPU usage
iotop  # Disk I/O
```

## Final Verification Steps

After successful build:

```bash
# Check output exists
ls -la result/sd-image/
# Should show: nixos-sd-image-*.img (or *.img.zst if compressed)

# Check image size (should be reasonable)
du -h result/sd-image/*.img*
# Should show: ~2-4G

# Verify image is valid (optional)
file result/sd-image/*.img*
# Should show: DOS/MBR boot sector or similar
```

## Quick Recovery Commands

If things go wrong, these commands will help you start fresh:

```bash
# Clean all nix builds
nix-collect-garbage -d

# Remove result symlink
rm -f result

# Check nix daemon status
sudo systemctl status nix-daemon

# Restart nix daemon
sudo systemctl restart nix-daemon

# Re-source nix environment
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# Verify setup again
nix --version && python3 -c "import yaml"
```

## Get Help

If you encounter other errors:

1. **Check the full error message** - Nix errors are verbose but usually helpful
2. **Look at build logs** - Nix stores detailed logs of failed builds
3. **Search the error online** - Many Nix cross-compilation issues have known solutions
4. **Check disk space** - Many build failures are due to insufficient space

The key is that **your build.sh script was working correctly** - it detected your system, parsed your configuration, and set up the cross-compilation flags properly. You just needed Nix installed first!