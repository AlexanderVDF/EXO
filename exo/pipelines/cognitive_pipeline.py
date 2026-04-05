"""
EXO Pipeline — MainCognitivePipeline.

Pipeline principal : perception → extraction → symbolic → inférence
→ planning → simulation → décision → supervision.
"""

import time

from ..core.cognitive_kernel import CognitivePipeline
from ..layers import (
    PerceptionLayer,
    ExtractionLayer,
    SymbolicLayer,
    InferenceLayer,
    PlanningLayer,
    SimulationLayer,
    DecisionLayer,
    SupervisionLayer,
)


class MainCognitivePipeline(CognitivePipeline):
    """Pipeline cognitif complet en 8 couches."""

    def __init__(self, rule_engine=None, htn_engine=None,
                 simulation_sandbox=None, supervisor=None):
        super().__init__("cognitive")
        self._layers = [
            PerceptionLayer(),
            ExtractionLayer(),
            SymbolicLayer(),
            InferenceLayer(rule_engine=rule_engine),
            PlanningLayer(htn_engine=htn_engine),
            SimulationLayer(simulation_sandbox=simulation_sandbox),
            DecisionLayer(),
            SupervisionLayer(supervisor=supervisor),
        ]

    def run(self, input_data: dict) -> dict:
        self._stats["runs"] += 1
        t0 = time.time()
        current = dict(input_data)
        traces = []

        for layer in self._layers:
            try:
                result = layer.process(current)
                traces.append({
                    "layer": layer.name,
                    "status": "ok",
                    "ts": time.time(),
                })
                # Propager les résultats
                current.update(result)
            except Exception as exc:
                self._stats["errors"] += 1
                traces.append({
                    "layer": layer.name,
                    "status": "error",
                    "error": str(exc),
                })
                current["error"] = str(exc)
                break

        self._traces.extend(traces)
        current["pipeline"] = self.name
        current["duration_ms"] = round((time.time() - t0) * 1000, 2)
        current["layers_executed"] = len(traces)
        return current
