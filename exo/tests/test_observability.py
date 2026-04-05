"""
Tests — Observabilité EXO (observability/).

Couvre : TelemetryCollector, TracingService,
MetricsRegistry, ObservabilityDashboard.
"""

import pytest
from exo.observability import (
    TelemetryCollector,
    TracingService,
    MetricsRegistry,
    ObservabilityDashboard,
)


# ── TelemetryCollector ──────────────────────────────────────

class TestTelemetryCollector:
    def test_emit(self):
        t = TelemetryCollector()
        ev = t.emit("engine", "process", {"x": 1})
        assert ev["source"] == "engine"
        assert ev["type"] == "process"

    def test_query_source(self):
        t = TelemetryCollector()
        t.emit("a", "info")
        t.emit("b", "info")
        t.emit("a", "warn")
        assert len(t.query(source="a")) == 2

    def test_query_type(self):
        t = TelemetryCollector()
        t.emit("x", "info")
        t.emit("x", "error")
        assert len(t.query(event_type="error")) == 1

    def test_clear(self):
        t = TelemetryCollector()
        t.emit("x", "y")
        t.clear()
        assert t.count() == 0

    def test_max_events(self):
        t = TelemetryCollector(max_events=3)
        for i in range(5):
            t.emit("s", f"e{i}")
        assert t.count() == 3

    def test_stats(self):
        t = TelemetryCollector()
        t.emit("a", "b")
        assert t.get_stats()["collected"] == 1


# ── TracingService ──────────────────────────────────────────

class TestTracingService:
    def test_start_finish(self):
        ts = TracingService()
        span = ts.start_trace("op1")
        assert span.operation == "op1"
        ts.finish_span(span)
        assert span.end_time is not None

    def test_get_trace(self):
        ts = TracingService()
        s = ts.start_trace("op1")
        ts.finish_span(s)
        trace = ts.get_trace(s.trace_id)
        assert len(trace) == 1
        assert trace[0]["operation"] == "op1"

    def test_list_traces(self):
        ts = TracingService()
        ts.start_trace("a")
        ts.start_trace("b")
        ids = ts.list_traces()
        assert len(ids) == 2

    def test_count(self):
        ts = TracingService()
        ts.start_trace("x")
        ts.start_trace("y", trace_id="same")
        assert ts.count() == 2

    def test_stats(self):
        ts = TracingService()
        ts.start_trace("z")
        assert ts.get_stats()["spans_created"] == 1


# ── MetricsRegistry ─────────────────────────────────────────

class TestMetricsRegistry:
    def test_record(self):
        m = MetricsRegistry()
        entry = m.record("latency", 42.0)
        assert entry["name"] == "latency"
        assert entry["value"] == 42.0

    def test_get(self):
        m = MetricsRegistry()
        m.record("cpu", 0.5)
        m.record("cpu", 0.8)
        assert len(m.get("cpu")) == 2

    def test_aggregate(self):
        m = MetricsRegistry()
        m.record("x", 10)
        m.record("x", 20)
        m.record("x", 30)
        a = m.aggregate("x")
        assert a["count"] == 3
        assert a["avg"] == 20.0
        assert a["min"] == 10
        assert a["max"] == 30
        assert a["sum"] == 60

    def test_aggregate_empty(self):
        m = MetricsRegistry()
        assert m.aggregate("nope")["count"] == 0

    def test_list_metrics(self):
        m = MetricsRegistry()
        m.record("a", 1)
        m.record("b", 2)
        assert m.list_metrics() == ["a", "b"]

    def test_clear_specific(self):
        m = MetricsRegistry()
        m.record("a", 1)
        m.record("b", 2)
        m.clear("a")
        assert "a" not in m.list_metrics()
        assert "b" in m.list_metrics()

    def test_clear_all(self):
        m = MetricsRegistry()
        m.record("a", 1)
        m.clear()
        assert m.list_metrics() == []

    def test_stats(self):
        m = MetricsRegistry()
        m.record("x", 1)
        assert m.get_stats()["recorded"] == 1


# ── ObservabilityDashboard ──────────────────────────────────

class TestObservabilityDashboard:
    def test_summary_empty(self):
        d = ObservabilityDashboard()
        s = d.summary()
        assert "timestamp" in s

    def test_summary_full(self):
        t = TelemetryCollector()
        t.emit("x", "y")
        tr = TracingService()
        tr.start_trace("op")
        m = MetricsRegistry()
        m.record("lat", 5.0)

        d = ObservabilityDashboard(telemetry=t, tracing=tr, metrics=m)
        s = d.summary()
        assert s["telemetry"]["event_count"] == 1
        assert s["tracing"]["span_count"] == 1
        assert "lat" in s["metrics"]["metric_names"]

    def test_health(self):
        d = ObservabilityDashboard(
            telemetry=TelemetryCollector(),
            tracing=TracingService(),
        )
        h = d.health()
        assert h["status"] == "healthy"
        assert h["components"]["telemetry"] is True
        assert h["components"]["metrics"] is False
