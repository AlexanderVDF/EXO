"""
EXO Macro Agent — ObservabilityAgent.

Orchestre la collecte de télémétrie, traçage et métriques.
"""

from ...core.cognitive_kernel import MacroAgent


class ObservabilityAgent(MacroAgent):
    """Agent macro d'observabilité : collecte et agrège les données."""

    def __init__(self, telemetry=None, tracing=None, metrics=None):
        super().__init__("observability")
        self._telemetry = telemetry
        self._tracing = tracing
        self._metrics = metrics

    def execute(self, context: dict) -> dict:
        self._stats["executions"] += 1
        report = {"agent": self.name}

        if self._telemetry:
            self._telemetry.emit(self.name, "observation", context)
            report["telemetry_count"] = self._telemetry.count()

        if self._tracing:
            span = self._tracing.start_trace("observation")
            self._tracing.finish_span(span)
            report["span"] = span.to_dict()

        if self._metrics:
            self._metrics.record("observation_count", 1.0)
            report["metrics_count"] = len(self._metrics.list_metrics())

        # Exécuter les sous-agents aussi
        for agent in self._sub_agents:
            try:
                r = agent.execute(context)
                report.update(r)
            except Exception:
                self._stats["errors"] += 1

        return report
