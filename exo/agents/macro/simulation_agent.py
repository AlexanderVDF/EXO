"""
EXO Macro Agent — SimulationAgent.

Orchestre les simulations de scénarios.
"""

from ...core.cognitive_kernel import MacroAgent


class SimulationAgent(MacroAgent):
    """Agent macro de simulation : orchestre le pipeline de simulation."""

    def __init__(self, pipeline=None):
        super().__init__("simulation")
        self._pipeline = pipeline

    def execute(self, context: dict) -> dict:
        self._stats["executions"] += 1

        if self._pipeline:
            result = self._pipeline.run(context)
        else:
            current = dict(context)
            for agent in self._sub_agents:
                try:
                    r = agent.execute(current)
                    current.update(r)
                except Exception as exc:
                    self._stats["errors"] += 1
                    current["error"] = str(exc)
                    break
            result = current

        result["agent"] = self.name
        return result
