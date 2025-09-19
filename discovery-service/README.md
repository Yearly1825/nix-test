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

The discovery service now uses the unified configuration system. Configuration is automatically read from `../.deployment.yaml` (or `/app/parent/.deployment.yaml` in Docker).

**No separate config directory needed!** The service reads the same configuration used by the bootstrap image builder.

Configuration is managed through:
```bash
cd .. && python3 setup_deployment.py
```

This creates a `.deployment.yaml` file that configures both the discovery service AND bootstrap images.

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
# Deploy with docker-compose (recommended)
docker-compose up -d

# Or build and run manually
docker build -t discovery-service .
docker run -p 8080:8080 -v ..:/app/parent:ro discovery-service
```

The docker-compose.yml automatically mounts the parent directory to access `.deployment.yaml`.