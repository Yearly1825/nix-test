import sqlite3
import json
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Dict, Any
from contextlib import contextmanager

class DatabaseManager:
    """Manages SQLite database operations for device registrations"""

    def __init__(self, db_path: str):
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_database()

    def _init_database(self):
        """Initialize database schema"""
        with self._get_connection() as conn:
            conn.executescript("""
                CREATE TABLE IF NOT EXISTS registrations (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    serial TEXT UNIQUE NOT NULL,
                    mac TEXT NOT NULL,
                    hostname TEXT UNIQUE NOT NULL,
                    ip_address TEXT,
                    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    confirmed_at TIMESTAMP NULL,
                    bootstrap_status TEXT DEFAULT 'pending',
                    error_message TEXT NULL,
                    request_count INTEGER DEFAULT 1
                );

                CREATE TABLE IF NOT EXISTS hostname_counter (
                    prefix TEXT PRIMARY KEY,
                    counter INTEGER NOT NULL DEFAULT 0
                );

                CREATE TABLE IF NOT EXISTS request_log (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    ip_address TEXT NOT NULL,
                    serial TEXT,
                    endpoint TEXT NOT NULL,
                    success BOOLEAN NOT NULL,
                    error_message TEXT,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );

                CREATE INDEX IF NOT EXISTS idx_registrations_serial ON registrations(serial);
                CREATE INDEX IF NOT EXISTS idx_registrations_hostname ON registrations(hostname);
                CREATE INDEX IF NOT EXISTS idx_request_log_ip ON request_log(ip_address);
                CREATE INDEX IF NOT EXISTS idx_request_log_timestamp ON request_log(timestamp);
            """)

    @contextmanager
    def _get_connection(self):
        """Context manager for database connections"""
        conn = sqlite3.connect(self.db_path, timeout=30.0)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def get_next_hostname(self, prefix: str) -> str:
        """Get next available hostname with given prefix"""
        with self._get_connection() as conn:
            # Get current counter
            result = conn.execute(
                "SELECT counter FROM hostname_counter WHERE prefix = ?",
                (prefix,)
            ).fetchone()

            if result:
                counter = result['counter'] + 1
            else:
                counter = 1

            # Update counter
            conn.execute(
                "INSERT OR REPLACE INTO hostname_counter (prefix, counter) VALUES (?, ?)",
                (prefix, counter)
            )

            return f"{prefix}-{counter:02d}"

    def register_device(self, serial: str, mac: str, hostname: str, ip_address: str = None) -> bool:
        """Register a new device"""
        try:
            with self._get_connection() as conn:
                conn.execute("""
                    INSERT INTO registrations (serial, mac, hostname, ip_address)
                    VALUES (?, ?, ?, ?)
                """, (serial, mac, hostname, ip_address))
                return True
        except sqlite3.IntegrityError:
            # Device already registered, update request count
            with self._get_connection() as conn:
                conn.execute("""
                    UPDATE registrations
                    SET request_count = request_count + 1,
                        ip_address = COALESCE(?, ip_address)
                    WHERE serial = ?
                """, (ip_address, serial))
                return False

    def confirm_device(self, serial: str, status: str, error_message: str = None) -> bool:
        """Confirm device bootstrap completion"""
        with self._get_connection() as conn:
            cursor = conn.execute("""
                UPDATE registrations
                SET confirmed_at = CURRENT_TIMESTAMP,
                    bootstrap_status = ?,
                    error_message = ?
                WHERE serial = ?
            """, (status, error_message, serial))

            return cursor.rowcount > 0

    def get_device_by_serial(self, serial: str) -> Optional[Dict[str, Any]]:
        """Get device registration by serial number"""
        with self._get_connection() as conn:
            result = conn.execute("""
                SELECT * FROM registrations WHERE serial = ?
            """, (serial,)).fetchone()

            if result:
                return dict(result)
            return None

    def get_device_by_hostname(self, hostname: str) -> Optional[Dict[str, Any]]:
        """Get device registration by hostname"""
        with self._get_connection() as conn:
            result = conn.execute("""
                SELECT * FROM registrations WHERE hostname = ?
            """, (hostname,)).fetchone()

            if result:
                return dict(result)
            return None

    def is_hostname_available(self, hostname: str) -> bool:
        """Check if hostname is available"""
        device = self.get_device_by_hostname(hostname)
        return device is None

    def log_request(self, ip_address: str, endpoint: str, success: bool,
                   serial: str = None, error_message: str = None):
        """Log API request"""
        with self._get_connection() as conn:
            conn.execute("""
                INSERT INTO request_log (ip_address, serial, endpoint, success, error_message)
                VALUES (?, ?, ?, ?, ?)
            """, (ip_address, serial, endpoint, success, error_message))

    def get_request_count(self, ip_address: str, minutes: int = 60) -> int:
        """Get request count for IP address in last N minutes"""
        with self._get_connection() as conn:
            result = conn.execute("""
                SELECT COUNT(*) as count FROM request_log
                WHERE ip_address = ?
                AND timestamp > datetime('now', '-{} minutes')
            """.format(minutes), (ip_address,)).fetchone()

            return result['count'] if result else 0

    def get_device_request_count(self, serial: str, minutes: int = 60) -> int:
        """Get request count for device in last N minutes"""
        with self._get_connection() as conn:
            result = conn.execute("""
                SELECT COUNT(*) as count FROM request_log
                WHERE serial = ?
                AND timestamp > datetime('now', '-{} minutes')
            """.format(minutes), (serial,)).fetchone()

            return result['count'] if result else 0

    def get_statistics(self) -> Dict[str, Any]:
        """Get registration statistics"""
        with self._get_connection() as conn:
            # Total registrations
            total = conn.execute("SELECT COUNT(*) as count FROM registrations").fetchone()['count']

            # Successful registrations
            successful = conn.execute("""
                SELECT COUNT(*) as count FROM registrations
                WHERE bootstrap_status = 'success'
            """).fetchone()['count']

            # Failed registrations
            failed = conn.execute("""
                SELECT COUNT(*) as count FROM registrations
                WHERE bootstrap_status = 'failure'
            """).fetchone()['count']

            # Confirmed devices
            confirmed = conn.execute("""
                SELECT COUNT(*) as count FROM registrations
                WHERE confirmed_at IS NOT NULL
            """).fetchone()['count']

            # Last registration
            last_reg = conn.execute("""
                SELECT registered_at FROM registrations
                ORDER BY registered_at DESC LIMIT 1
            """).fetchone()

            return {
                'total_registrations': total,
                'successful_registrations': successful,
                'failed_registrations': failed,
                'confirmed_devices': confirmed,
                'active_hostnames': total,  # All registered devices have hostnames
                'last_registration': datetime.fromisoformat(last_reg['registered_at']) if last_reg else None
            }
