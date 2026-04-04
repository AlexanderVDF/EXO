"""EXO v9 — BaseService: unified foundation for all microservices.

Integrates: LogManager, MetricsManager, TraceManager, ErrorManager,
SecurityManager, ConfigManager, health check endpoint.
"""

import asyncio
import json
import signal
import time
from typing import Any, Optional

from .log_manager import LogManager
from .metrics_manager import MetricsManager
from .trace_manager import TraceManager
from .error_manager import ErrorManager, ExoError
from .security_manager import SecurityManager
from .config_manager import ConfigManager
from .singleton_guard import ensure_single_instance


class BaseService:
    """Base class that every EXO microservice can compose or inherit.

    Provides structured logging, metrics, tracing, error handling,
    security, config and a standard health-check WebSocket response.
    """

    def __init__(self, name: str, port: int, *, init_config: bool = True):
        self.name = name
        self.port = port
        self._start_time = time.monotonic()

        # ── v9 modules ───────────────────────────────────────────
        self.log = LogManager.get(name)
        self.metrics = MetricsManager(name)
        self.traces = TraceManager(name)
        self.errors = ErrorManager.instance()
        self.errors.set_metrics(self.metrics)
        self.security = SecurityManager.instance()

        if init_config:
            self.config = ConfigManager.instance()
        else:
            self.config = None

        self.log.info(f"Service {name} initializing on port {port}")

    # ── health check ─────────────────────────────────────────────
    def health_check(self) -> dict[str, Any]:
        uptime = time.monotonic() - self._start_time
        return {
            "type": "health",
            "service": self.name,
            "status": "ok",
            "uptime_s": round(uptime, 1),
            "metrics": {
                "requests": self.metrics.counter("requests_total").value,
                "errors": self.metrics.counter("errors_total").value,
            },
        }

    # ── WebSocket message handler ────────────────────────────────
    async def handle_ws_message(self, ws, raw: str) -> Optional[str]:
        """Handle standard v9 protocol messages.

        Returns JSON response string, or None if not a v9 message.
        """
        try:
            msg = json.loads(raw)
        except json.JSONDecodeError:
            return None

        msg_type = msg.get("type")

        if msg_type == "ping":
            return json.dumps({"type": "pong"})

        if msg_type == "health":
            return json.dumps(self.health_check())

        if msg_type == "metrics":
            return json.dumps({"type": "metrics", **self.metrics.snapshot()})

        if msg_type == "traces":
            n = msg.get("count", 20)
            return json.dumps({"type": "traces", "traces": self.traces.recent(n)},
                              default=str)

        if msg_type == "errors":
            n = msg.get("count", 20)
            return json.dumps({"type": "errors",
                               "errors": self.errors.recent_errors(n)},
                              default=str)

        return None

    # ── request instrumentation ──────────────────────────────────
    def begin_request(self, request_id: Optional[str] = None) -> str:
        rid = request_id or LogManager.new_request_id()
        LogManager.set_request_id(rid)
        self.metrics.counter("requests_total").inc()
        return rid

    def end_request(self, request_id: str, *, error: bool = False) -> None:
        if error:
            self.metrics.counter("errors_total").inc()

    # ── lifecycle ────────────────────────────────────────────────
    def on_shutdown(self) -> None:
        self.log.info(f"Service {self.name} shutting down")
        self.traces.export_json()


def init_v9(service_name: str, port: int, *,
            init_config: bool = True) -> BaseService:
    """One-liner to initialize all v9 infrastructure for a microservice."""
    return BaseService(service_name, port, init_config=init_config)
