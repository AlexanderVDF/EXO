"""
EXO Macro Agent — PlanningAgent.

Orchestre la planification hiérarchique.
"""

from ...core.cognitive_kernel import MacroAgent


class PlanningAgent(MacroAgent):
    """Agent macro de planification : orchestre le pipeline de planning."""

    def __init__(self, pipeline=None):
        super().__init__("planning")
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
