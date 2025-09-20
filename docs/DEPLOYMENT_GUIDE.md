# Discovery Service Deployment Guide

This guide covers production deployment, testing, and validation of the NixOS Raspberry Pi sensor discovery service.

## Overview

The discovery service provides secure device registration and bootstrap configuration delivery for NixOS Raspberry Pi sensors. This guide focuses on the simplified implementation which reduces complexity by 70% while maintaining full API compatibility.

## Prerequisites

- Docker and Docker Compose installed
- Valid `.deployment.yaml` configuration file in project root
- NTFY endpoint configured (optional but recommended)
- Network access between discovery service and target devices

## Production Deployment

### 1. Environment Setup

Create production environment configuration:

```bash
# Navigate to discovery service directory
cd discovery-service/

# Copy and customize deployment configuration
cp ../deployment.yaml.example ../.deployment.yaml
```

Edit `.deployment.yaml` for production:

```yaml
discovery_service:
  host: "0.0.0.0"
  port: 8000
  psk: "your-production-psk-key-32-chars-long"
  database_path: "/app/data/discovery.db"
  
ntfy:
  enabled: true
  endpoint: "https://your-ntfy-server.com"
  topic: "sensor-bootstrap"
  
logging:
  level: "INFO"
  format: "json"
```

### 2. Docker Deployment

Deploy using the simplified Docker configuration:

```bash
# Build and start the service
docker-compose -f docker-compose.simple.yml up -d

# Verify service is running
docker-compose -f docker-compose.simple.yml ps
docker-compose -f docker-compose.simple.yml logs discovery-service
```

### 3. Health Monitoring

The service provides built-in health and statistics endpoints:

```bash
# Health check
curl http://localhost:8000/health

# Service statistics
curl http://localhost:8000/stats
```

Expected health response:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-20T10:30:00Z",
  "database": "connected",
  "version": "simplified"
}
```

## Security Configuration

### PSK Management

The Pre-Shared Key (PSK) is critical for secure operation:

1. **Generation**: Use a cryptographically secure 32-character key
2. **Storage**: Store in environment variables or secure secrets management
3. **Rotation**: Plan for periodic key rotation in production

```bash
# Generate secure PSK
openssl rand -hex 16

# Set via environment (alternative to .deployment.yaml)
export DISCOVERY_PSK="your-secure-psk-here"
```

### Network Security

1. **TLS Termination**: Use reverse proxy (nginx/traefik) for HTTPS
2. **Firewall Rules**: Restrict access to known device networks
3. **Rate Limiting**: Implement at reverse proxy level

Example nginx configuration:
```nginx
server {
    listen 443 ssl;
    server_name discovery.your-domain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Testing and Validation

### 1. Unit Testing

The simplified implementation maintains the core security and functionality:

```bash
# Test database connectivity
curl -X GET http://localhost:8000/health

# Test device registration flow
curl -X POST http://localhost:8000/register \
  -H "Content-Type: application/json" \
  -d '{"device_id": "test-device", "device_type": "raspberry-pi"}'
```

### 2. Integration Testing

Test complete bootstrap flow:

```bash
# 1. Register device
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:8000/register \
  -H "Content-Type: application/json" \
  -d '{"device_id": "test-rpi-001", "device_type": "raspberry-pi"}')

echo "Registration response: $REGISTER_RESPONSE"

# 2. Extract confirmation token (would be provided to device)
TOKEN=$(echo $REGISTER_RESPONSE | jq -r '.confirmation_token')

# 3. Confirm device (simulates device confirming registration)
curl -X POST http://localhost:8000/confirm \
  -H "Content-Type: application/json" \
  -d "{\"device_id\": \"test-rpi-001\", \"confirmation_token\": \"$TOKEN\"}"
```

### 3. Load Testing

For production readiness, test service under load:

```bash
# Install wrk for load testing
# brew install wrk  # macOS
# apt-get install wrk  # Ubuntu

# Test health endpoint
wrk -t12 -c400 -d30s http://localhost:8000/health

# Test registration endpoint
wrk -t4 -c100 -d30s -s register_test.lua http://localhost:8000/register
```

Create `register_test.lua` for registration load testing:
```lua
wrk.method = "POST"
wrk.body = '{"device_id": "load-test", "device_type": "raspberry-pi"}'
wrk.headers["Content-Type"] = "application/json"
```

## Performance Monitoring

### 1. Service Metrics

Monitor key metrics:

- Registration success rate
- Response times
- Database connection health
- Memory usage
- Error rates

```bash
# Monitor container resources
docker stats discovery-service

# Check application logs
docker-compose -f docker-compose.simple.yml logs -f discovery-service
```

### 2. Database Monitoring

The simplified implementation uses SQLite with single-table design:

```bash
# Database size monitoring
docker exec discovery-service ls -lh /app/data/discovery.db

# Record count monitoring
docker exec discovery-service sqlite3 /app/data/discovery.db "SELECT COUNT(*) FROM device_registrations;"
```

## Troubleshooting

### Common Issues

1. **Database Lock Errors**
   - Symptom: SQLite database lock errors
   - Solution: Ensure single service instance, check file permissions
   - Prevention: Use proper Docker volume management

2. **PSK Mismatch**
   - Symptom: Authentication failures
   - Solution: Verify PSK in .deployment.yaml matches device configuration
   - Prevention: Use environment variable override for testing

3. **Network Connectivity**
   - Symptom: Health checks fail
   - Solution: Verify port binding and firewall rules
   - Prevention: Use docker-compose networking

### Debug Mode

Enable debug logging for troubleshooting:

```yaml
# In .deployment.yaml
logging:
  level: "DEBUG"
  format: "detailed"
```

```bash
# Restart with debug logging
docker-compose -f docker-compose.simple.yml restart discovery-service
docker-compose -f docker-compose.simple.yml logs -f discovery-service
```

## Backup and Recovery

### Database Backup

```bash
# Create backup
docker exec discovery-service cp /app/data/discovery.db /app/data/discovery.db.backup

# Copy backup to host
docker cp discovery-service:/app/data/discovery.db.backup ./discovery-backup-$(date +%Y%m%d).db
```

### Configuration Backup

```bash
# Backup deployment configuration
cp .deployment.yaml deployment-backup-$(date +%Y%m%d).yaml

# Backup Docker configuration
cp discovery-service/docker-compose.simple.yml discovery-service/docker-compose-backup-$(date +%Y%m%d).yml
```

## Scaling Considerations

The simplified implementation is designed for moderate scale:

- **Concurrent Devices**: 100-500 simultaneous registrations
- **Database Size**: Up to 10,000 device records
- **Response Time**: Sub-100ms for health checks

For larger deployments, consider:

1. **Database Migration**: PostgreSQL for higher concurrency
2. **Load Balancing**: Multiple service instances behind load balancer
3. **Caching**: Redis for session management
4. **Monitoring**: Prometheus + Grafana for metrics

## Migration from Original Implementation

If migrating from the original complex implementation:

1. **Database Schema**: Export existing registrations
2. **Configuration**: Map existing config to simplified format
3. **API Compatibility**: All endpoints remain identical
4. **Deployment**: Gradual rollout with health monitoring

```bash
# Export from original database (example)
sqlite3 original.db "SELECT device_id, device_type, status FROM devices;" > migration.csv

# Import to simplified database
sqlite3 discovery.db ".mode csv" ".import migration.csv device_registrations"
```

## Security Audit Checklist

- [ ] PSK properly secured and rotated
- [ ] TLS termination configured
- [ ] Network access restricted
- [ ] Logging configured for security events
- [ ] Database file permissions secured
- [ ] Container runs as non-root user
- [ ] Regular security updates applied
- [ ] Backup and recovery tested

## Support and Maintenance

For ongoing maintenance:

1. **Log Rotation**: Configure log rotation to prevent disk space issues
2. **Health Monitoring**: Set up automated health checks
3. **Security Updates**: Regular container image updates
4. **Performance Review**: Monthly performance analysis
5. **Documentation Updates**: Keep deployment procedures current

## Related Documentation

- [Discovery Service README](../discovery-service/README.md) - Service overview and development
- [NixOS Bootstrap Guide](../docs/nixos-bootstrap.md) - Device-side configuration
- [Troubleshooting Guide](../docs/troubleshooting.md) - Common issues and solutions