"""
EXO Observability — MetricsRegistry.

Registre de métriques avec agrégations temps-réel.
"""

import time
from collections import defaultdict


class MetricsRegistry:
    """Enregistre et agrège les métriques du système."""

    def __init__(self):
        self._series: dict[str, list[dict]] = defaultdict(list)
        self._stats = {"recorded": 0}

    def record(self, name: str, value: float,
               tags: dict | None = None) -> dict:
        entry = {
            "name": name,
            "value": value,
            "tags": tags or {},
            "timestamp": time.time(),
        }
        self._series[name].append(entry)
        self._stats["recorded"] += 1
        return entry

    def get(self, name: str, limit: int = 100) -> list[dict]:
        return self._series.get(name, [])[-limit:]

    def aggregate(self, name: str) -> dict:
        values = [e["value"] for e in self._series.get(name, [])]
        if not values:
            return {"count": 0}
        return {
            "count": len(values),
            "sum": sum(values),
            "avg": sum(values) / len(values),
            "min": min(values),
            "max": max(values),
        }

    def list_metrics(self) -> list[str]:
        return sorted(self._series.keys())

    def clear(self, name: str | None = None) -> None:
        if name:
            self._series.pop(name, None)
        else:
            self._series.clear()

    def get_stats(self) -> dict:
        return dict(self._stats)
