"""
EXO Micro Agent — HTNExpansionAgent.

Décomposition HTN des objectifs en sous-tâches.
"""

from ...core.cognitive_kernel import MicroAgent


class HTNExpansionAgent(MicroAgent):
    """Agent micro : décompose un objectif via HTN."""

    def __init__(self, htn_engine=None):
        super().__init__("htn_expansion")
        self._engine = htn_engine

    def execute(self, context: dict) -> dict:
        self._stats["executions"] += 1
        goal = context.get("goal", context.get("intent", "unknown"))

        if self._engine:
            result = self._engine.process({"goal": goal})
            steps = result.get("primitive_steps", [])
            return {
                "agent": self.name,
                "plan": steps,
                "goal": goal,
            }

        return {"agent": self.name, "plan": [f"execute_{goal}"], "goal": goal}
