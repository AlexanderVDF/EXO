"""
EXO Engine — Observability Engines.

CognitiveTelemetryEngine, StructuredTracingEngine, CognitiveMetricsEngine.
"""

import time
import uuid

from ..core.cognitive_kernel import CognitiveEngine
from ..core.cognitive_context import Metric, TraceSpan


class CognitiveTelemetryEngine(CognitiveEngine):
    """Télémétrie cognitive : collecte d'événements système."""

    def __init__(self):
        super().__init__("cognitive_telemetry_engine")
        self._events: list[dict] = []

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        event = {
            "id": f"tel_{uuid.uuid4().hex[:8]}",
            "source": data.get("source", "unknown"),
            "event_type": data.get("type", "info"),
            "payload": data.get("payload", {}),
            "timestamp": time.time(),
        }
        self._events.append(event)
        if len(self._events) > 5000:
            self._events = self._events[-2500:]
        return {"logged": True, **event}

    def get_events(self, limit: int = 50) -> list[dict]:
        return self._events[-limit:]


class StructuredTracingEngine(CognitiveEngine):
    """Traçage structuré : spans hiérarchiques."""

    def __init__(self):
        super().__init__("structured_tracing_engine")
        self._spans: list[dict] = []

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        span = TraceSpan(
            operation=data.get("operation", "unknown"),
            trace_id=data.get("trace_id"),
        )
        span.tags = data.get("tags", {})
        span.finish(data.get("status", "ok"))
        record = span.to_dict()
        self._spans.append(record)
        if len(self._spans) > 5000:
            self._spans = self._spans[-2500:]
        return {"traced": True, **record}

    def get_traces(self, trace_id: str | None = None,
                   limit: int = 50) -> list[dict]:
        if trace_id:
            return [s for s in self._spans if s["trace_id"] == trace_id]
        return self._spans[-limit:]


class CognitiveMetricsEngine(CognitiveEngine):
    """Collecte de métriques cognitives."""

    def __init__(self):
        super().__init__("cognitive_metrics_engine")
        self._metrics: list[dict] = []
        self._aggregates: dict[str, list[float]] = {}

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        metric = Metric(
            name=data.get("name", "unnamed"),
            value=data.get("value", 0.0),
            tags=data.get("tags", {}),
        )
        record = metric.to_dict()
        record["id"] = f"met_{uuid.uuid4().hex[:8]}"
        self._metrics.append(record)
        if len(self._metrics) > 5000:
            self._metrics = self._metrics[-2500:]

        mn = metric.name
        if mn not in self._aggregates:
            self._aggregates[mn] = []
        self._aggregates[mn].append(metric.value)
        if len(self._aggregates[mn]) > 1000:
            self._aggregates[mn] = self._aggregates[mn][-500:]

        return {"recorded": True, **record}

    def get_aggregate(self, name: str) -> dict:
        vals = self._aggregates.get(name, [])
        if not vals:
            return {"name": name, "count": 0}
        return {
            "name": name,
            "count": len(vals),
            "min": round(min(vals), 4),
            "max": round(max(vals), 4),
            "avg": round(sum(vals) / len(vals), 4),
        }
