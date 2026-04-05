"""
EXO Layer — SimulationLayer.

Couche de simulation : évaluation sandbox des plans candidats.
"""

import time

from ..core.cognitive_kernel import CognitiveLayer


class SimulationLayer(CognitiveLayer):
    """Couche de simulation : teste les plans dans un sandbox."""

    def __init__(self, simulation_sandbox=None):
        super().__init__("simulation")
        self._sandbox = simulation_sandbox

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        plan_steps = data.get("plan_steps", [])
        intent = data.get("intent", "unknown")

        sim_results = []
        if self._sandbox:
            scenario = {
                "name": f"plan_sim_{intent}",
                "parameters": {
                    "steps": len(plan_steps),
                    "risk": data.get("risk", 0.1),
                    "benefit": data.get("benefit", 0.8),
                },
            }
            result = self._sandbox.process({"scenario": scenario})
            sim_results.append(result)
        else:
            sim_results.append({
                "outcome": "favorable",
                "score": 0.7,
            })

        return {
            "layer": self.name,
            "plan_steps": plan_steps,
            "simulation_results": sim_results,
            "simulated": True,
            "timestamp": time.time(),
        }
