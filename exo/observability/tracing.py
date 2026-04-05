"""
EXO Observability — TracingService.

Traçage structuré distribué pour les pipelines cognitifs.
"""

import time
import uuid

from ..core.cognitive_context import TraceSpan


class TracingService:
    """Gère les traces distribuées avec spans hiérarchiques."""

    def __init__(self):
        self._traces: dict[str, list[TraceSpan]] = {}
        self._stats = {"spans_created": 0}

    def start_trace(self, operation: str,
                    trace_id: str | None = None) -> TraceSpan:
        tid = trace_id or uuid.uuid4().hex[:16]
        span = TraceSpan(
            trace_id=tid,
            span_id=uuid.uuid4().hex[:12],
            operation=operation,
        )
        self._traces.setdefault(tid, []).append(span)
        self._stats["spans_created"] += 1
        return span

    def finish_span(self, span: TraceSpan) -> None:
        span.finish()

    def get_trace(self, trace_id: str) -> list[dict]:
        spans = self._traces.get(trace_id, [])
        return [s.to_dict() for s in spans]

    def list_traces(self, limit: int = 20) -> list[str]:
        return list(self._traces.keys())[-limit:]

    def count(self) -> int:
        return sum(len(v) for v in self._traces.values())

    def get_stats(self) -> dict:
        return dict(self._stats)
