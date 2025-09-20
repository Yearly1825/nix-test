# Discovery Service

**The service that gives your Raspberry Pis their names and configuration.**

When a Pi boots up, it contacts this service to get:
- A unique hostname (`SENSOR-01`, `SENSOR-02`, etc.)
- VPN connection keys
- SSH access keys  
- Configuration details

## How to Run It

**Easy way (with Docker):**
```bash
docker-compose up -d
```

**Without Docker:**
```bash
pip install -r requirements.txt
python -m app.main
```

**Configure first:** Make sure you've run `python3 setup_deployment.py` from the main directory.

## What It Does

**When a Pi contacts the service:**

1. **Authentication** - Pi proves it's yours using a secret key
2. **Name Assignment** - Gets next available name (`SENSOR-01`, `SENSOR-02`, etc.)  
3. **Secure Delivery** - Receives encrypted VPN keys and SSH keys
4. **Confirmation** - Pi reports back when setup is complete

**Built-in endpoints:**
- `POST /register` - Pi requests its configuration
- `POST /confirm` - Pi confirms setup succeeded  
- `GET /health` - Check if service is running
- `GET /stats` - See how many Pis have registered

## Security

- **Secret key authentication** - Only your Pis can register
- **Encrypted delivery** - Each Pi gets uniquely encrypted keys
- **No plaintext secrets** - Keys are protected in transit and storage

The system automatically generates all security keys when you run the setup wizard.

## Checking if it Works

**Test the service:**
```bash
# Check if running
curl http://localhost:8080/health

# See registration stats  
curl http://localhost:8080/stats
```

**Monitor logs:**
```bash
# With Docker
docker-compose logs -f discovery-service

# Without Docker  
# Logs appear in terminal where you started it
```

## Troubleshooting

**Service won't start:**
- Make sure you ran `python3 setup_deployment.py` first
- Check that port 8080 isn't already in use: `netstat -ln | grep 8080`

**Pis not registering:**
- Check Pi has ethernet connection
- Verify discovery service IP is reachable from Pi's network
- Check logs for error messages

**Need more help?** Check the main README or bootstrap-image README for additional troubleshooting.