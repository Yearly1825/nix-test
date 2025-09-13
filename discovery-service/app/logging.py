import logging
import logging.handlers
from pathlib import Path
from typing import Optional
import json
from datetime import datetime

class DiscoveryLogger:
    """Enhanced logging for the discovery service"""

    def __init__(self, config):
        self.config = config
        self.logger = self._setup_logger()

    def _setup_logger(self) -> logging.Logger:
        """Setup structured logging with rotation"""
        logger = logging.getLogger("discovery_service")
        logger.setLevel(getattr(logging, self.config.logging.level))

        # Remove existing handlers
        for handler in logger.handlers[:]:
            logger.removeHandler(handler)

        # Create logs directory
        log_file = Path(self.config.logging.file)
        log_file.parent.mkdir(parents=True, exist_ok=True)

        # File handler with rotation
        file_handler = logging.handlers.RotatingFileHandler(
            log_file,
            maxBytes=self.config.logging.max_size_mb * 1024 * 1024,
            backupCount=self.config.logging.backup_count
        )

        # Console handler
        console_handler = logging.StreamHandler()

        # Custom formatter for structured logs
        formatter = StructuredFormatter()
        file_handler.setFormatter(formatter)
        console_handler.setFormatter(formatter)

        logger.addHandler(file_handler)
        logger.addHandler(console_handler)

        return logger

    def log_registration_attempt(self, serial: str, mac: str, ip: str, success: bool,
                                hostname: str = None, error: str = None):
        """Log device registration attempt"""
        event_data = {
            "event": "registration_attempt",
            "device_serial": serial,
            "device_mac": mac,
            "client_ip": ip,
            "success": success,
            "hostname": hostname,
            "error": error
        }

        if success:
            self.logger.info("Device registration successful", extra=event_data)
        else:
            self.logger.warning("Device registration failed", extra=event_data)

    def log_confirmation(self, serial: str, hostname: str, status: str,
                        ip: str = None, error: str = None):
        """Log device confirmation"""
        event_data = {
            "event": "bootstrap_confirmation",
            "device_serial": serial,
            "hostname": hostname,
            "bootstrap_status": status,
            "client_ip": ip,
            "error": error
        }

        if status == "success":
            self.logger.info("Device bootstrap confirmed successful", extra=event_data)
        else:
            self.logger.error("Device bootstrap confirmed failed", extra=event_data)

    def log_security_event(self, event_type: str, ip: str, details: dict = None):
        """Log security-related events"""
        event_data = {
            "event": "security_event",
            "security_event_type": event_type,
            "client_ip": ip,
            "details": details or {}
        }

        self.logger.warning("Security event detected", extra=event_data)

    def log_rate_limit(self, ip: str, endpoint: str, request_count: int, limit: int):
        """Log rate limiting events"""
        event_data = {
            "event": "rate_limit_exceeded",
            "client_ip": ip,
            "endpoint": endpoint,
            "request_count": request_count,
            "limit": limit
        }

        self.logger.warning("Rate limit exceeded", extra=event_data)

    def log_api_request(self, method: str, path: str, ip: str, status_code: int,
                       response_time: float = None):
        """Log API requests"""
        event_data = {
            "event": "api_request",
            "method": method,
            "path": path,
            "client_ip": ip,
            "status_code": status_code,
            "response_time_ms": round(response_time * 1000, 2) if response_time else None
        }

        if status_code < 400:
            self.logger.info("API request", extra=event_data)
        elif status_code < 500:
            self.logger.warning("API client error", extra=event_data)
        else:
            self.logger.error("API server error", extra=event_data)

    def info(self, message: str, **kwargs):
        """Log info message"""
        self.logger.info(message, extra=kwargs)

    def warning(self, message: str, **kwargs):
        """Log warning message"""
        self.logger.warning(message, extra=kwargs)

    def error(self, message: str, **kwargs):
        """Log error message"""
        self.logger.error(message, extra=kwargs)

    def debug(self, message: str, **kwargs):
        """Log debug message"""
        self.logger.debug(message, extra=kwargs)

class StructuredFormatter(logging.Formatter):
    """Custom formatter for structured JSON logging"""

    def format(self, record):
        # Base log structure
        log_entry = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name
        }

        # Add any extra fields from the log record
        extra_fields = {
            key: value for key, value in record.__dict__.items()
            if key not in {
                'name', 'msg', 'args', 'levelname', 'levelno', 'pathname',
                'filename', 'module', 'exc_info', 'exc_text', 'stack_info',
                'lineno', 'funcName', 'created', 'msecs', 'relativeCreated',
                'thread', 'threadName', 'processName', 'process', 'getMessage'
            }
        }

        if extra_fields:
            log_entry.update(extra_fields)

        # Add exception info if present
        if record.exc_info:
            log_entry["exception"] = self.formatException(record.exc_info)

        return json.dumps(log_entry, default=str)
