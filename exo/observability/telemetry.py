"""
EXO Observability — TelemetryCollector.

Collecte d'événements de télémétrie pour tout le système.
"""

import time
import uuid


class TelemetryCollector:
    """Collecte et stocke les événements de télémétrie."""

    def __init__(self, max_events: int = 10000):
        self._events: list[dict] = []
        self._max = max_events
        self._stats = {"collected": 0}

    def emit(self, source: str, event_type: str,
             data: dict | None = None) -> dict:
        event = {
            "id": uuid.uuid4().hex[:12],
            "source": source,
            "type": event_type,
            "data": data or {},
            "timestamp": time.time(),
        }
        self._events.append(event)
        if len(self._events) > self._max:
            self._events = self._events[-self._max:]
        self._stats["collected"] += 1
        return event

    def query(self, source: str | None = None,
              event_type: str | None = None,
              limit: int = 50) -> list[dict]:
        results = self._events
        if source:
            results = [e for e in results if e["source"] == source]
        if event_type:
            results = [e for e in results if e["type"] == event_type]
        return results[-limit:]

    def clear(self) -> None:
        self._events.clear()

    def count(self) -> int:
        return len(self._events)

    def get_stats(self) -> dict:
        return dict(self._stats)
