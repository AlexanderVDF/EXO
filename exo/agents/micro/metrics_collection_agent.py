"""
EXO Micro Agent — MetricsCollectionAgent.

Collecte de métriques pendant l'exécution.
"""

import time

from ...core.cognitive_kernel import MicroAgent


class MetricsCollectionAgent(MicroAgent):
    """Agent micro : collecte et enregistre des métriques."""

    def __init__(self, metrics_registry=None):
        super().__init__("metrics_collection")
        self._registry = metrics_registry

    def execute(self, context: dict) -> dict:
        self._stats["executions"] += 1
        metrics_data = context.get("metrics", {})
        source = context.get("source", "unknown")

        recorded = []
        if self._registry and isinstance(metrics_data, dict):
            for name, value in metrics_data.items():
                if isinstance(value, (int, float)):
                    self._registry.record(name, float(value),
                                          tags={"source": source})
                    recorded.append(name)

        return {
            "agent": self.name,
            "recorded": recorded,
            "count": len(recorded),
        }
