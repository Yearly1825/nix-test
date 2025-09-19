import httpx
import asyncio
from typing import Optional, Dict, Any
import json

class NTFYNotifier:
    """NTFY notification service for real-time monitoring"""

    def __init__(self, config):
        self.config = config.ntfy
        self.enabled = self.config.enabled and self.config.url

    async def send_notification(self, title: str, message: str,
                               priority: str = None, tags: list = None):
        """Send notification to NTFY service"""
        if not self.enabled:
            return

        priority = priority or self.config.priority
        tags = tags or self.config.tags

        headers = {
            "Title": title,
            "Priority": priority,
            "Tags": ",".join(tags) if tags else ""
        }

        # Add authentication if configured
        auth_type = getattr(self.config, 'auth_type', 'none')

        if auth_type == 'basic':
            username = getattr(self.config, 'username', '')
            password = getattr(self.config, 'password', '')
            if username and password:
                import base64
                credentials = base64.b64encode(f"{username}:{password}".encode()).decode()
                headers['Authorization'] = f"Basic {credentials}"

        elif auth_type == 'bearer':
            token = getattr(self.config, 'token', '')
            if token:
                headers['Authorization'] = f"Bearer {token}"

        try:
            timeout = getattr(self.config, 'timeout_seconds', 10)
            async with httpx.AsyncClient(timeout=timeout) as client:
                response = await client.post(
                    self.config.url,
                    content=message,
                    headers=headers
                )
                response.raise_for_status()
        except Exception as e:
            # Don't let notification failures break the main flow
            print(f"NTFY notification failed: {e}")

    async def notify_registration(self, hostname: str, serial: str, ip: str):
        """Notify successful device registration"""
        title = "🖥️ New Device Registered"
        message = (
            f"Device: {hostname}\n"
            f"Serial: {serial}\n"
            f"IP: {ip}\n"
            f"Status: Bootstrapping..."
        )

        await self.send_notification(
            title,
            message,
            priority="default",
            tags=["registration", "raspberry-pi"]
        )

    async def notify_confirmation(self, hostname: str, serial: str, status: str,
                                 error: str = None):
        """Notify device bootstrap confirmation"""
        if status == "success":
            title = "✅ Device Bootstrap Complete"
            message = (
                f"Device: {hostname}\n"
                f"Serial: {serial}\n"
                f"Status: Bootstrap successful!"
            )
            priority = "default"
            tags = ["success", "bootstrap"]
        else:
            title = "❌ Device Bootstrap Failed"
            message = (
                f"Device: {hostname}\n"
                f"Serial: {serial}\n"
                f"Status: Bootstrap failed\n"
                f"Error: {error or 'Unknown error'}"
            )
            priority = "high"
            tags = ["failure", "bootstrap", "error"]

        await self.send_notification(title, message, priority, tags)

    async def notify_security_event(self, event_type: str, ip: str, details: Dict[str, Any]):
        """Notify security events"""
        title = "🚨 Security Alert"
        message = (
            f"Event: {event_type}\n"
            f"IP: {ip}\n"
            f"Details: {json.dumps(details, indent=2)}"
        )

        await self.send_notification(
            title,
            message,
            priority="urgent",
            tags=["security", "alert"]
        )

    async def notify_rate_limit(self, ip: str, endpoint: str, count: int, limit: int):
        """Notify rate limiting events"""
        title = "⚠️ Rate Limit Exceeded"
        message = (
            f"IP: {ip}\n"
            f"Endpoint: {endpoint}\n"
            f"Requests: {count}/{limit}"
        )

        await self.send_notification(
            title,
            message,
            priority="high",
            tags=["rate-limit", "security"]
        )
