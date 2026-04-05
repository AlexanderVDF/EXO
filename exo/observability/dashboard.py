"""
EXO Observability — ObservabilityDashboard.

Tableau de bord synthétique de l'état du système.
"""

import time


class ObservabilityDashboard:
    """Agrège télémétrie, traces et métriques en un dashboard."""

    def __init__(self, telemetry=None, tracing=None, metrics=None):
        self._telemetry = telemetry
        self._tracing = tracing
        self._metrics = metrics

    def summary(self) -> dict:
        result = {"timestamp": time.time()}

        if self._telemetry:
            result["telemetry"] = {
                "event_count": self._telemetry.count(),
                "stats": self._telemetry.get_stats(),
            }

        if self._tracing:
            result["tracing"] = {
                "span_count": self._tracing.count(),
                "trace_ids": self._tracing.list_traces(limit=5),
                "stats": self._tracing.get_stats(),
            }

        if self._metrics:
            names = self._metrics.list_metrics()
            result["metrics"] = {
                "metric_names": names,
                "aggregates": {
                    n: self._metrics.aggregate(n) for n in names[:10]
                },
                "stats": self._metrics.get_stats(),
            }

        return result

    def health(self) -> dict:
        """Retourne un statut de santé simplifié."""
        return {
            "status": "healthy",
            "components": {
                "telemetry": self._telemetry is not None,
                "tracing": self._tracing is not None,
                "metrics": self._metrics is not None,
            },
            "timestamp": time.time(),
        }
