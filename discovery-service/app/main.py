from fastapi import FastAPI, HTTPException, Depends, Request, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
import time
import asyncio
from typing import Dict, Any

from .config import load_config, Config
from .models import (
    RegistrationRequest, RegistrationResponse,
    ConfirmationRequest, ConfirmationResponse,
    HealthResponse, StatsResponse, ErrorResponse
)
from .security import SecurityManager
from .database import DatabaseManager
from .logging import DiscoveryLogger
from .notifications import NTFYNotifier

# Global variables (initialized in create_app)
config: Config = None
security: SecurityManager = None
database: DatabaseManager = None
logger: DiscoveryLogger = None
notifier: NTFYNotifier = None
app_start_time: float = None

# Rate limiter
limiter = Limiter(key_func=get_remote_address)

def create_app(config_path: str = None) -> FastAPI:
    """Create and configure FastAPI application"""
    global config, security, database, logger, notifier, app_start_time

    # Load configuration
    config = load_config(config_path)

    # Initialize components
    security = SecurityManager(config.discovery_service.psk)
    database = DatabaseManager(config.database.file)
    logger = DiscoveryLogger(config)
    notifier = NTFYNotifier(config)
    app_start_time = time.time()

    # Create FastAPI app
    app = FastAPI(
        title="Discovery Service",
        description="Secure device registration and configuration service",
        version="1.0.0",
        docs_url="/docs" if config.logging.level == "DEBUG" else None,
        redoc_url="/redoc" if config.logging.level == "DEBUG" else None
    )

    # Add middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["GET", "POST"],
        allow_headers=["*"],
    )

    # Add rate limiting
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

    # Add request logging middleware
    @app.middleware("http")
    async def log_requests(request: Request, call_next):
        start_time = time.time()
        response = await call_next(request)
        process_time = time.time() - start_time

        logger.log_api_request(
            method=request.method,
            path=request.url.path,
            ip=get_remote_address(request),
            status_code=response.status_code,
            response_time=process_time
        )

        return response

    return app

app = create_app()

def verify_admin_token(request: Request):
    """Verify admin token for protected endpoints"""
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authorization header"
        )

    token = auth_header.split(" ")[1]
    if token != config.discovery_service.admin_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin token"
        )

@app.post("/register", response_model=RegistrationResponse)
@limiter.limit(f"{config.security.max_requests_per_ip}/hour")
async def register_device(request: Request, reg_request: RegistrationRequest):
    """Register a new device and provide configuration"""
    client_ip = get_remote_address(request)

    try:
        # Verify signature
        if not security.verify_registration_request(
            reg_request.serial,
            reg_request.mac,
            reg_request.signature,
            reg_request.timestamp,
            config.security.signature_window_seconds
        ):
            logger.log_security_event(
                "invalid_signature",
                client_ip,
                {"serial": reg_request.serial, "endpoint": "/register"}
            )
            database.log_request(client_ip, "/register", False, reg_request.serial, "Invalid signature")

            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid signature"
            )

        # Check device-specific rate limiting
        device_requests = database.get_device_request_count(reg_request.serial, 60)
        if device_requests >= config.security.max_requests_per_device:
            logger.log_rate_limit(client_ip, "/register", device_requests, config.security.max_requests_per_device)
            database.log_request(client_ip, "/register", False, reg_request.serial, "Rate limit exceeded")

            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many requests for this device"
            )

        # Check if device already registered
        existing_device = database.get_device_by_serial(reg_request.serial)
        if existing_device:
            hostname = existing_device['hostname']
            logger.log_registration_attempt(
                reg_request.serial, reg_request.mac, client_ip,
                True, hostname, "Device already registered"
            )
        else:
            # Generate new hostname
            hostname = database.get_next_hostname(config.deployment.name)

            # Register device
            database.register_device(
                reg_request.serial,
                reg_request.mac,
                hostname,
                client_ip
            )

            logger.log_registration_attempt(
                reg_request.serial, reg_request.mac, client_ip,
                True, hostname
            )

            # Send notification
            await notifier.notify_registration(hostname, reg_request.serial, client_ip)

        # Create encrypted configuration payload
        config_payload = {
            "netbird_setup_key": config.netbird.setup_key,
            "ssh_keys": config.ssh_keys,
            "timestamp": int(time.time())
        }

        encrypted_config = security.encrypt_payload(config_payload, reg_request.serial)

        database.log_request(client_ip, "/register", True, reg_request.serial)

        return RegistrationResponse(
            hostname=hostname,
            encrypted_config=encrypted_config
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Registration error: {str(e)}",
                    serial=reg_request.serial, client_ip=client_ip)
        database.log_request(client_ip, "/register", False, reg_request.serial, str(e))

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )

@app.post("/confirm", response_model=ConfirmationResponse)
@limiter.limit("30/hour")
async def confirm_bootstrap(request: Request, conf_request: ConfirmationRequest):
    """Confirm device bootstrap completion"""
    client_ip = get_remote_address(request)

    try:
        # Verify signature
        if not security.verify_confirmation_request(
            conf_request.serial,
            conf_request.hostname,
            conf_request.signature,
            conf_request.timestamp,
            config.security.signature_window_seconds
        ):
            logger.log_security_event(
                "invalid_confirmation_signature",
                client_ip,
                {"serial": conf_request.serial, "hostname": conf_request.hostname}
            )
            database.log_request(client_ip, "/confirm", False, conf_request.serial, "Invalid signature")

            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid signature"
            )

        # Update device confirmation
        success = database.confirm_device(
            conf_request.serial,
            conf_request.status,
            conf_request.error_message
        )

        if not success:
            database.log_request(client_ip, "/confirm", False, conf_request.serial, "Device not found")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Device not found"
            )

        logger.log_confirmation(
            conf_request.serial,
            conf_request.hostname,
            conf_request.status,
            client_ip,
            conf_request.error_message
        )

        # Send notification
        await notifier.notify_confirmation(
            conf_request.hostname,
            conf_request.serial,
            conf_request.status,
            conf_request.error_message
        )

        database.log_request(client_ip, "/confirm", True, conf_request.serial)

        return ConfirmationResponse()

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Confirmation error: {str(e)}",
                    serial=conf_request.serial, client_ip=client_ip)
        database.log_request(client_ip, "/confirm", False, conf_request.serial, str(e))

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    stats = database.get_statistics()
    uptime = time.time() - app_start_time

    return HealthResponse(
        uptime_seconds=uptime,
        total_registrations=stats['total_registrations']
    )

@app.get("/stats", response_model=StatsResponse)
async def get_stats(request: Request, _: None = Depends(verify_admin_token)):
    """Get registration statistics (admin only)"""
    stats = database.get_statistics()
    return StatsResponse(**stats)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler"""
    client_ip = get_remote_address(request)
    logger.error(f"Unhandled exception: {str(exc)}", client_ip=client_ip, path=request.url.path)

    return JSONResponse(
        status_code=500,
        content=ErrorResponse(error="Internal server error").dict()
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=config.api.host,
        port=config.api.port,
        reload=False,
        access_log=False
    )
