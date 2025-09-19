# CachyOS Build Troubleshooting Checklist

Quick diagnostic steps for resolving build issues on fresh CachyOS systems.

## Step 1: Install Nix (Fixes your current error)

```bash
# Install Nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Reload shell
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# Test
nix --version
```

**✅ Expected**: `nix (Nix) 2.18.1` or similar  
**❌ If fails**: See troubleshooting below

## Step 2: Configure Nix

```bash
# Create config
mkdir -p ~/.config/nix
cat > ~/.config/nix/nix.conf << 'EOF'
experimental-features = nix-command flakes
extra-platforms = aarch64-linux
max-jobs = auto
cores = 0
EOF

# Test flakes
nix flake --help | head -1
```

**✅ Expected**: Shows flake help  
**❌ If fails**: Configuration not loaded properly

## Step 3: Install System Dependencies

```bash
# Install with paru
paru -S --needed python python-pip python-yaml

# Test
python3 -c "import yaml; print('OK')"
```

**✅ Expected**: Prints "OK"  
**❌ If fails**: Install python-yaml with pip: `pip3 install PyYAML`

## Step 4: Test Build

```bash
cd ~/nix-test/bootstrap-image
./build.sh
```

**✅ Expected**: Build starts downloading packages  
**❌ If fails**: See error-specific solutions below

## Common Error Solutions

### "nix: command not found"
```bash
# Check if nix-daemon is running
sudo systemctl status nix-daemon
sudo systemctl enable nix-daemon
sudo systemctl start nix-daemon

# Add to PATH
echo 'export PATH=/nix/var/nix/profiles/default/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

### "experimental-features not enabled"
```bash
# Ensure nix.conf exists and is correct
cat ~/.config/nix/nix.conf
# Should show experimental-features line

# If missing:
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### "system aarch64-linux not supported" OR "not a trusted user"
```bash
# Check extra-platforms setting
grep "extra-platforms" ~/.config/nix/nix.conf

# If missing:
echo "extra-platforms = aarch64-linux" >> ~/.config/nix/nix.conf

# CRITICAL: Add yourself as trusted user
echo "trusted-users = root $USER" | sudo tee -a /etc/nix/nix.conf

# Restart nix daemon (REQUIRED after changing trusted users)
sudo systemctl restart nix-daemon
```

### Build hangs or times out
```bash
# Check internet connection
ping cache.nixos.org

# Check disk space
df -h /nix

# If low on space:
nix-collect-garbage -d
```

### "sandbox" errors on CachyOS
```bash
# This should be handled automatically by build.sh
# If using direct nix commands, add:
nix build --option sandbox false ...
```

## Quick Diagnostic Commands

```bash
# Check everything at once
echo "=== Nix Version ==="
nix --version

echo "=== Nix Config ==="
cat ~/.config/nix/nix.conf

echo "=== Python/YAML ==="
python3 -c "import yaml; print('YAML: OK')"

echo "=== Disk Space ==="
df -h /nix

echo "=== Nix Daemon ==="
sudo systemctl status nix-daemon --no-pager

echo "=== Build Test ==="
nix eval --expr 'builtins.currentSystem'
```

## Ready to Build Checklist

Before running `./build.sh`, verify:

- [ ] `nix --version` works
- [ ] `nix flake --help` works  
- [ ] `python3 -c "import yaml"` works
- [ ] `df -h /nix` shows >10GB free space
- [ ] `sudo systemctl status nix-daemon` shows active
- [ ] File `~/.config/nix/nix.conf` exists with correct content

## Build Time Expectations

**First build**: 25-50 minutes  
**Subsequent builds**: 6-12 minutes  
**Download size**: ~2-4 GB  
**Final image size**: ~2-4 GB

## Get More Help

If issues persist:

1. Run full diagnostic: `bash -x ./build.sh` (shows every command)
2. Check Nix logs: `journalctl -u nix-daemon.service`  
3. Check build logs in `/tmp/nix-build-*` directories
4. Verify your `.deployment.yaml` is valid: `python3 -c "import yaml; yaml.safe_load(open('../.deployment.yaml'))"`