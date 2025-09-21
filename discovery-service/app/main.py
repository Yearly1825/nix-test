#!/usr/bin/env python3
"""
Simplified Discovery Service - Web Application
==============================================

FastAPI web application for the simplified discovery service.
Uses core components from simple_core.py for business logic.

Features:
- PSK-based device authentication (no timestamp validation)
- Encrypted payload delivery (Netbird keys, SSH keys)
- Sequential hostname assignment
- Basic logging
- Unified configuration system compatibility
"""

import time
import logging

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

# Import all core components
from .core import (
    load_config, Config,
    SecurityManager, DatabaseManager, NTFYNotifier,
    RegistrationRequest, RegistrationResponse,
    ConfirmationRequest, ConfirmationResponse,
    HealthResponse, StatsResponse
)


# =============================================================================
# FastAPI Application
# =============================================================================

# Global variables (initialized in create_app)
config: Config = None
security: SecurityManager = None
database: DatabaseManager = None
notifier: NTFYNotifier = None
app_start_time: float = None

def create_app(config_path: str = None) -> FastAPI:
    """Create and configure FastAPI application"""
    global config, security, database, notifier, app_start_time

    # Load configuration
    config = load_config(config_path)

    # Initialize components
    security = SecurityManager(config.discovery_service.psk)
    database = DatabaseManager(config.database.file)
    notifier = NTFYNotifier(config)
    app_start_time = time.time()

    # Setup basic logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

    # Create FastAPI app
    app = FastAPI(
        title="Simplified Discovery Service",
        description="Simplified secure device registration and configuration service",
        version="1.0.0-simple"
    )

    # Add middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["GET", "POST"],
        allow_headers=["*"],
    )

    return app

app = create_app()

@app.post("/register", response_model=RegistrationResponse)
async def register_device(request: Request, reg_request: RegistrationRequest):
    """Register a new device and provide configuration (simplified)"""
    client_ip = request.client.host

    try:
        # Verify signature (simplified - no timestamp validation)
        if not security.verify_registration_request(
            reg_request.serial,
            reg_request.mac,
            reg_request.signature
        ):
            logging.warning(f"Invalid signature from {client_ip} for device {reg_request.serial}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid signature"
            )

        # Check if device already registered
        existing_device = database.get_device_by_serial(reg_request.serial)
        if existing_device:
            hostname = existing_device['hostname']
            logging.info(f"Device {reg_request.serial} already registered as {hostname}")
        else:
            # Generate new hostname
            hostname = database.get_next_hostname(config.deployment.name)

            # Register device
            success = database.register_device(reg_request.serial, reg_request.mac, hostname)
            if not success:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Failed to register device"
                )

            logging.info(f"Registered new device {reg_request.serial} as {hostname}")

            # Send notification
            await notifier.notify_registration(hostname, reg_request.serial)

        # Create encrypted configuration payload
        config_payload = {
            "netbird_setup_key": config.netbird.setup_key,
            "ssh_keys": config.ssh_keys,
            "timestamp": int(time.time())
        }

        encrypted_config = security.encrypt_payload(config_payload, reg_request.serial)

        return RegistrationResponse(
            hostname=hostname,
            encrypted_config=encrypted_config
        )

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Registration error for {reg_request.serial}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )

@app.post("/confirm", response_model=ConfirmationResponse)
async def confirm_bootstrap(request: Request, conf_request: ConfirmationRequest):
    """Confirm device bootstrap completion (simplified)"""
    client_ip = request.client.host

    try:
        # Verify signature (simplified - no timestamp validation)
        if not security.verify_confirmation_request(
            conf_request.serial,
            conf_request.hostname,
            conf_request.signature
        ):
            logging.warning(f"Invalid confirmation signature from {client_ip} for device {conf_request.serial}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid signature"
            )

        # Update device confirmation
        success = database.confirm_device(conf_request.serial, conf_request.status)
        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Device not found"
            )

        logging.info(f"Confirmed bootstrap for {conf_request.hostname} ({conf_request.serial}): {conf_request.status}")

        # Send notification
        await notifier.notify_confirmation(
            conf_request.hostname,
            conf_request.serial,
            conf_request.status
        )

        return ConfirmationResponse()

    except HTTPException:
        raise
    except Exception as e:
        logging.error(f"Confirmation error for {conf_request.serial}: {str(e)}")
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
async def get_stats():
    """Get registration statistics (simplified - no admin auth)"""
    stats = database.get_statistics()
    return StatsResponse(**stats)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler"""
    logging.error(f"Unhandled exception: {str(exc)}")
    return JSONResponse(
        status_code=500,
        content={"success": False, "error": "Internal server error"}
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
