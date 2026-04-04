"""EXO v9 — Centralized configuration with hot-reload."""

import json
import os
import threading
import time
from pathlib import Path
from typing import Any, Optional

_DEFAULT_CONFIG: dict[str, Any] = {
    "audio": {
        "backend": "rtaudio",
        "sample_rate": 16000,
        "channels": 1,
    },
    "llm": {
        "model": "claude-sonnet-4-20250514",
        "max_tokens": 4096,
        "temperature": 0.7,
        "timeout_s": 10,
        "retries": 2,
    },
    "stt": {
        "backend": "whispercpp",
        "model": "medium",
        "language": "fr",
        "beam_size": 3,
        "timeout_s": 3,
        "retries": 1,
    },
    "tts": {
        "backend": "xtts",
        "voice": "Claribel Dervla",
        "language": "fr",
        "timeout_s": 3,
        "retries": 1,
    },
    "tools": {
        "timeout_s": 5,
        "retries": 1,
    },
    "domotique": {
        "timeout_s": 3,
        "retries": 2,
    },
    "network": {
        "timeout_s": 5,
        "retries": 1,
    },
    "cache": {
        "max_entries": 64,
        "default_ttl_s": 60,
    },
    "security": {
        "audit_log_enabled": True,
        "permissions_file": "config/permissions.json",
    },
    "logs": {
        "level": "DEBUG",
        "log_to_file": True,
        "log_to_console": True,
        "max_bytes": 10485760,
        "backup_count": 3,
    },
    "metrics": {
        "enabled": True,
        "export_interval_s": 60,
    },
    "supervisor": {
        "check_interval_s": 10,
        "ping_timeout_s": 5,
        "degraded_latency_ms": 2000,
        "max_restart_attempts": 3,
    },
}

CONFIG_PATH = Path(os.environ.get("EXO_CONFIG", "config/exo_v9.json"))


class ConfigManager:
    """Thread-safe centralized config with hot-reload support."""

    _instance: Optional["ConfigManager"] = None
    _lock = threading.Lock()

    def __init__(self, config_path: Optional[Path] = None):
        self._path = config_path or CONFIG_PATH
        self._data: dict[str, Any] = {}
        self._callbacks: list = []
        self._mtime: float = 0.0
        self._watch_thread: Optional[threading.Thread] = None
        self._watching = False
        self.reload()

    @classmethod
    def instance(cls, config_path: Optional[Path] = None) -> "ConfigManager":
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = cls(config_path)
        return cls._instance

    @classmethod
    def reset(cls) -> None:
        """Reset singleton (testing)."""
        cls._instance = None

    def reload(self) -> None:
        """(Re)load config from disk, merge with defaults."""
        data: dict[str, Any] = {}
        if self._path.exists():
            try:
                raw = self._path.read_text(encoding="utf-8")
                data = json.loads(raw)
                self._mtime = self._path.stat().st_mtime
            except (json.JSONDecodeError, OSError):
                data = {}
        self._data = _deep_merge(_DEFAULT_CONFIG, data)
        for cb in self._callbacks:
            try:
                cb(self._data)
            except Exception:
                pass

    def get(self, key: str, default: Any = None) -> Any:
        """Dot-notation get: ``get('llm.timeout_s')``."""
        parts = key.split(".")
        node: Any = self._data
        for p in parts:
            if isinstance(node, dict):
                node = node.get(p)
            else:
                return default
            if node is None:
                return default
        return node

    def set(self, key: str, value: Any) -> None:
        """Dot-notation set: ``set('llm.temperature', 0.5)``."""
        parts = key.split(".")
        node = self._data
        for p in parts[:-1]:
            node = node.setdefault(p, {})
        node[parts[-1]] = value

    def section(self, name: str) -> dict[str, Any]:
        return dict(self._data.get(name, {}))

    def save(self) -> None:
        """Persist current config to disk."""
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._path.write_text(
            json.dumps(self._data, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )
        self._mtime = self._path.stat().st_mtime

    def on_reload(self, callback) -> None:
        self._callbacks.append(callback)

    # ── hot-reload watcher ───────────────────────────────────────
    def start_watching(self, interval_s: float = 2.0) -> None:
        if self._watching:
            return
        self._watching = True
        self._watch_thread = threading.Thread(
            target=self._watch_loop, args=(interval_s,), daemon=True,
        )
        self._watch_thread.start()

    def stop_watching(self) -> None:
        self._watching = False

    def _watch_loop(self, interval_s: float) -> None:
        while self._watching:
            try:
                if self._path.exists():
                    mt = self._path.stat().st_mtime
                    if mt > self._mtime:
                        self.reload()
            except OSError:
                pass
            time.sleep(interval_s)

    @property
    def data(self) -> dict[str, Any]:
        return dict(self._data)


def _deep_merge(base: dict, override: dict) -> dict:
    result = dict(base)
    for k, v in override.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = _deep_merge(result[k], v)
        else:
            result[k] = v
    return result
