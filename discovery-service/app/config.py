import yaml
from pathlib import Path
from pydantic import BaseModel, Field
from typing import List, Optional

class DeploymentConfig(BaseModel):
    name: str = Field(..., description="Hostname prefix")
    psk: str = Field(..., description="Pre-shared key for authentication")

class NetbirdConfig(BaseModel):
    setup_key: str = Field(..., description="Netbird VPN setup key")

class SecurityConfig(BaseModel):
    max_requests_per_ip: int = Field(10, description="Max requests per IP")
    max_requests_per_device: int = Field(3, description="Max requests per device")
    signature_window_seconds: int = Field(300, description="HMAC signature validity window")
    admin_token: str = Field(..., description="Admin API token")

class APIConfig(BaseModel):
    host: str = Field("0.0.0.0", description="API host")
    port: int = Field(8080, description="API port")

class LoggingConfig(BaseModel):
    level: str = Field("INFO", description="Log level")
    file: str = Field("logs/discovery.log", description="Log file path")
    max_size_mb: int = Field(10, description="Max log file size in MB")
    backup_count: int = Field(5, description="Number of backup files")

class DatabaseConfig(BaseModel):
    file: str = Field("data/registrations.db", description="SQLite database file")

class NTFYConfig(BaseModel):
    enabled: bool = Field(False, description="Enable NTFY notifications")
    url: str = Field("", description="NTFY topic URL")
    priority: str = Field("default", description="Message priority")
    tags: List[str] = Field(default_factory=lambda: ["raspberry-pi", "bootstrap"])

class Config(BaseModel):
    deployment: DeploymentConfig
    netbird: NetbirdConfig
    ssh_keys: List[str] = Field(default_factory=list, description="SSH public keys")
    security: SecurityConfig
    api: APIConfig
    logging: LoggingConfig
    database: DatabaseConfig
    ntfy: NTFYConfig

def load_config(config_path: str = "config/config.yaml") -> Config:
    """Load configuration from YAML file"""
    config_file = Path(config_path)

    if not config_file.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_path}")

    with open(config_file, 'r') as f:
        config_data = yaml.safe_load(f)

    return Config(**config_data)
