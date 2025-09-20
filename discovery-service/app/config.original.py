import yaml
from pathlib import Path
from pydantic import BaseModel, Field
from typing import List, Optional

class DeploymentConfig(BaseModel):
    name: str = Field(..., description="Hostname prefix")
    environment: str = Field("production", description="Environment identifier")
    description: str = Field("", description="Deployment description")

class DiscoveryServiceConfig(BaseModel):
    ip: str = Field("10.42.0.1", description="Discovery service IP")
    port: int = Field(8080, description="Discovery service port")
    psk: str = Field(..., description="Pre-shared key for authentication")
    admin_token: str = Field(..., description="Admin API token")

class NetbirdConfig(BaseModel):
    setup_key: str = Field(..., description="Netbird VPN setup key")

class SecurityConfig(BaseModel):
    max_requests_per_ip: int = Field(10, description="Max requests per IP")
    max_requests_per_device: int = Field(3, description="Max requests per device")
    signature_window_seconds: int = Field(300, description="HMAC signature validity window")

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
    auth_type: str = Field("none", description="Authentication type")
    username: str = Field("", description="Username for basic auth")
    password: str = Field("", description="Password for basic auth")
    token: str = Field("", description="Bearer token")
    priority: str = Field("default", description="Message priority")
    tags: List[str] = Field(default_factory=lambda: ["raspberry-pi", "bootstrap"])
    retry_attempts: int = Field(3, description="Retry attempts")
    timeout_seconds: int = Field(10, description="Timeout in seconds")

class Config(BaseModel):
    deployment: DeploymentConfig
    discovery_service: DiscoveryServiceConfig
    netbird: NetbirdConfig
    ssh_keys: List[str] = Field(default_factory=list, description="SSH public keys")
    security: SecurityConfig
    api: APIConfig
    logging: LoggingConfig
    database: DatabaseConfig
    ntfy: NTFYConfig

def load_config(config_path: str = None) -> Config:
    """Load configuration from unified deployment YAML file"""
    if config_path is None:
        # Auto-detect configuration file location
        possible_paths = [
            "/app/parent/.deployment.yaml",  # Docker environment
            "../.deployment.yaml",           # Local development
            ".deployment.yaml"               # Same directory
        ]

        config_file = None
        for path in possible_paths:
            if Path(path).exists():
                config_file = Path(path)
                break

        if config_file is None:
            # Fallback to legacy config for backward compatibility
            legacy_config = Path("config/config.yaml")
            if legacy_config.exists():
                print("⚠️  WARNING: Using legacy config/config.yaml")
                print("   Please migrate to unified configuration: cd .. && python3 setup_deployment.py")
                config_file = legacy_config
            else:
                raise FileNotFoundError(
                    "Configuration file not found. Tried:\n" +
                    "\n".join([f"  - {p}" for p in possible_paths]) +
                    "\n\nPlease create configuration: cd .. && python3 setup_deployment.py"
                )
    else:
        config_file = Path(config_path)
        if not config_file.exists():
            raise FileNotFoundError(f"Configuration file not found: {config_path}")

    with open(config_file, 'r') as f:
        config_data = yaml.safe_load(f)

    # Transform unified config format to discovery service format if needed
    if 'discovery_service' in config_data:
        # This is the new unified format
        transformed_config = {
            'deployment': config_data.get('deployment', {}),
            'discovery_service': config_data.get('discovery_service', {}),
            'netbird': config_data.get('netbird', {}),
            'ssh_keys': config_data.get('ssh_keys', []),
            'security': config_data.get('security', {}),
            'api': {
                'host': '0.0.0.0',  # Always bind to all interfaces in container
                'port': config_data.get('discovery_service', {}).get('port', 8080)
            },
            'logging': config_data.get('logging', {}),
            'database': config_data.get('database', {}),
            'ntfy': config_data.get('ntfy', {})
        }
        config_data = transformed_config
    else:
        # This is legacy format, need to transform to new structure
        discovery_service = {
            'ip': '10.42.0.1',
            'port': config_data.get('api', {}).get('port', 8080),
            'psk': config_data.get('deployment', {}).get('psk', ''),
            'admin_token': config_data.get('security', {}).get('admin_token', '')
        }
        config_data['discovery_service'] = discovery_service

    return Config(**config_data)
