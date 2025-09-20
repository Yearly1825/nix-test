from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
from datetime import datetime

class RegistrationRequest(BaseModel):
    """Device registration request"""
    serial: str = Field(..., description="Device serial number")
    mac: str = Field(..., description="Device MAC address")
    signature: str = Field(..., description="HMAC signature")
    timestamp: int = Field(..., description="Unix timestamp")

class RegistrationResponse(BaseModel):
    """Device registration response"""
    hostname: str = Field(..., description="Assigned hostname")
    encrypted_config: str = Field(..., description="Encrypted configuration bundle")
    success: bool = Field(True, description="Registration success status")
    message: str = Field("Registration successful", description="Status message")

class ConfirmationRequest(BaseModel):
    """Device confirmation request"""
    serial: str = Field(..., description="Device serial number")
    hostname: str = Field(..., description="Assigned hostname")
    signature: str = Field(..., description="HMAC signature")
    timestamp: int = Field(..., description="Unix timestamp")
    status: str = Field(..., description="Bootstrap status (success/failure)")
    error_message: Optional[str] = Field(None, description="Error message if bootstrap failed")

class ConfirmationResponse(BaseModel):
    """Device confirmation response"""
    success: bool = Field(True, description="Confirmation received")
    message: str = Field("Confirmation received", description="Status message")

class HealthResponse(BaseModel):
    """Health check response"""
    status: str = Field("healthy", description="Service status")
    version: str = Field("1.0.0", description="Service version")
    uptime_seconds: float = Field(..., description="Service uptime in seconds")
    total_registrations: int = Field(..., description="Total successful registrations")

class StatsResponse(BaseModel):
    """Statistics response"""
    total_registrations: int = Field(..., description="Total registrations")
    successful_registrations: int = Field(..., description="Successful registrations")
    failed_registrations: int = Field(..., description="Failed registrations")
    confirmed_devices: int = Field(..., description="Confirmed device bootstraps")
    active_hostnames: int = Field(..., description="Currently assigned hostnames")
    last_registration: Optional[datetime] = Field(None, description="Last registration time")

class ErrorResponse(BaseModel):
    """Error response"""
    success: bool = Field(False, description="Operation success status")
    error: str = Field(..., description="Error message")
    details: Optional[Dict[str, Any]] = Field(None, description="Additional error details")
