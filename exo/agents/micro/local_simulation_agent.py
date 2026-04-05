"""
EXO Micro Agent — LocalSimulationAgent.

Simulation locale d'un scénario isolé.
"""

from ...core.cognitive_kernel import MicroAgent


class LocalSimulationAgent(MicroAgent):
    """Agent micro : exécute une simulation locale."""

    def __init__(self, sandbox=None):
        super().__init__("local_simulation")
        self._sandbox = sandbox

    def execute(self, context: dict) -> dict:
        self._stats["executions"] += 1
        scenario = context.get("scenario", {})

        if self._sandbox and scenario:
            result = self._sandbox.process({"scenario": scenario})
            return {
                "agent": self.name,
                "simulation": result,
            }

        params = scenario.get("parameters", {})
        benefit = params.get("benefit", 0.5)
        risk = params.get("risk", 0.2)
        score = benefit - risk

        return {
            "agent": self.name,
            "simulation": {
                "outcome": "favorable" if score > 0.3 else "neutral",
                "score": round(score, 3),
            },
        }
