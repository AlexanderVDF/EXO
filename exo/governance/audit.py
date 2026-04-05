"""
EXO Governance — AuditLogger.

Journal d'audit structuré pour toutes les décisions.
"""

import time
import uuid


class AuditLogger:
    """Enregistre un journal d'audit immuable."""

    def __init__(self, max_entries: int = 10000):
        self._entries: list[dict] = []
        self._max = max_entries
        self._stats = {"logged": 0}

    def log(self, action: str, entity: str, detail: dict | None = None) -> dict:
        entry = {
            "id": uuid.uuid4().hex[:12],
            "action": action,
            "entity": entity,
            "detail": detail or {},
            "timestamp": time.time(),
        }
        self._entries.append(entry)
        if len(self._entries) > self._max:
            self._entries = self._entries[-self._max:]
        self._stats["logged"] += 1
        return entry

    def query(self, action: str | None = None,
              entity: str | None = None,
              limit: int = 50) -> list[dict]:
        results = self._entries
        if action:
            results = [e for e in results if e["action"] == action]
        if entity:
            results = [e for e in results if e["entity"] == entity]
        return results[-limit:]

    def export(self) -> list[dict]:
        return list(self._entries)

    def count(self) -> int:
        return len(self._entries)

    def get_stats(self) -> dict:
        return dict(self._stats)
