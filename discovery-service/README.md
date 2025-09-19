# Discovery Service

FastAPI-based discovery service for Raspberry Pi sensor bootstrap process.

> **⚠️ RECOMMENDED SETUP**: Use the unified configuration system for easier setup:
> ```bash
> cd .. && python3 setup_deployment.py
> ```
> This configures both the discovery service AND bootstrap images automatically.

## Features

- PSK-based device authentication  
- Encrypted payload delivery (Netbird keys, SSH keys)
- Sequential hostname assignment with custom prefixes
- Comprehensive logging and monitoring
- Rate limiting and security controls
- NTFY integration for real-time notifications

## Architecture

### Security Model
1. **PSK Authentication**: Each deployment uses a shared PSK burned into bootstrap images
2. **Request Signing**: HMAC-SHA256 signatures with timestamp validation
3. **Encrypted Payloads**: AES-256-GCM encryption for sensitive data
4. **Rate Limiting**: Per-IP and per-device registration limits

### API Endpoints
- `POST /register` - Device registration and configuration delivery
- `POST /confirm` - Device confirmation after successful bootstrap
- `GET /health` - Health check endpoint
- `GET /stats` - Registration statistics (admin only)

## Configuration

Edit `config/config.yaml`:

```yaml
deployment:
  name: "DELLDESKTOP"
  psk: "your-psk-here"
  
netbird:
  setup_key: "your-netbird-setup-key"
  
ssh_keys:
  - "ssh-ed25519 AAAAC3... admin@host"
  - "ssh-rsa AAAAB3... backup@host"

security:
  max_requests_per_ip: 10
  max_requests_per_device: 3
  signature_window_seconds: 300
  
logging:
  level: "INFO"
  file: "discovery.log"
  
ntfy:
  enabled: false
  url: "https://ntfy.sh/your-topic"
```

## Usage

```bash
# Install dependencies
pip install -r requirements.txt

# Run development server
python -m app.main

# Run with gunicorn (production)
gunicorn app.main:app --host 0.0.0.0 --port 8080
```

## Docker Deployment

```bash
# Build image
docker build -t discovery-service .

# Run container
docker run -p 8080:8080 -v ./config:/app/config discovery-service
```