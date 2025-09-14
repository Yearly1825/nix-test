# Scripts

Helper scripts for sensor deployment and management.

## 📁 **Available Scripts**

*This directory is prepared for future deployment automation scripts such as:*

### **Planned Scripts**
- `bulk-flash.sh` - Mass SD card flashing utility
- `deploy-sensors.sh` - Automated sensor deployment
- `monitor-fleet.sh` - Fleet monitoring dashboard
- `update-sensors.sh` - Remote sensor configuration updates

## 🚀 **Manual Deployment Process**

Since we're using manual SD flashing for now, here's the recommended workflow:

### **1. Build Bootstrap Images**
```bash
cd ../bootstrap-image
./build-image.sh -p <your-psk>
```

### **2. Flash SD Cards**
```bash
# Identify SD card (BE CAREFUL!)
lsblk

# Flash image
sudo dd if=../bootstrap-image/result/nixos-sd-image-*.img of=/dev/sdX bs=4M status=progress sync
```

### **3. Deploy Sensors**
1. Insert SD card in Raspberry Pi
2. Connect ethernet cable
3. Power on Pi
4. Monitor discovery service logs for registration

### **4. Monitor Deployment**
```bash
cd ../discovery-service
docker-compose logs -f
```

## 🔧 **Future Automation**

This directory is ready for automation scripts when needed for larger deployments.