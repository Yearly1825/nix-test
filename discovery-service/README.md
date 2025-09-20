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
- Basic logging and monitoring
- NTFY integration for real-time notifications

## Architecture

### Security Model (Simplified)
1. **PSK Authentication**: Each deployment uses a shared PSK burned into bootstrap images
2. **Request Signing**: HMAC-SHA256 signatures (no timestamp validation)
3. **Encrypted Payloads**: AES-256-GCM encryption for sensitive data

### API Endpoints
- `POST /register` - Device registration and configuration delivery
- `POST /confirm` - Device confirmation after successful bootstrap
- `GET /health` - Health check endpoint
- `GET /stats` - Registration statistics (public access)

### API Request Format (Simplified)

**Registration Request:**
```json
{
  "serial": "10000000a1b2c3d4",
  "mac": "b8:27:eb:12:34:56",
  "signature": "hmac_sha256_hex"
}
```

**Confirmation Request:**
```json
{
  "serial": "10000000a1b2c3d4", 
  "hostname": "sensor-01",
  "signature": "hmac_sha256_hex",
  "status": "success"
}
```

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

# Run simplified development server
python -m app.simple_main

# Run with gunicorn (production)
gunicorn app.simple_main:app --host 0.0.0.0 --port 8080
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

**Note**: To use the simplified version in Docker, modify the Dockerfile CMD from:
- `CMD ["python", "-m", "app.main"]` 
- to: `CMD ["python", "-m", "app.simple_main"]`

## Documentation

### Phase 4: Production Deployment and Testing

For production deployment, comprehensive testing, and validation:

- **[Deployment Guide](../docs/DEPLOYMENT_GUIDE.md)** - Complete production deployment instructions
- **[Example Configurations](../docs/examples/)** - Environment-specific configuration templates
  - `deployment-dev.yaml` - Development environment
  - `deployment-staging.yaml` - Staging environment  
  - `deployment-prod.yaml` - Production environment
  - `docker-compose.prod.yml` - Production Docker setup

### Additional Resources

- **[Project Documentation](../docs/)** - Broader project documentation
- **[NixOS Bootstrap Guide](../docs/nixos-bootstrap.md)** - Device-side configuration
- **[Troubleshooting Guide](../docs/troubleshooting.md)** - Common issues and solutions