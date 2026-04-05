"""
EXO Layer — PlanningLayer.

Couche de planification : génération de plans d'action.
"""

import time

from ..core.cognitive_kernel import CognitiveLayer


class PlanningLayer(CognitiveLayer):
    """Couche de planification : construit un plan d'action."""

    def __init__(self, htn_engine=None):
        super().__init__("planning")
        self._htn_engine = htn_engine

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        conclusions = data.get("conclusions", [])
        intent = data.get("intent", "unknown")
        facts = data.get("facts", {})

        steps = []
        if self._htn_engine and conclusions:
            goal = conclusions[0] if conclusions else "respond"
            result = self._htn_engine.process({"goal": goal})
            steps = result.get("primitive_steps", [goal])
        else:
            if "requires_answer" in conclusions:
                steps = ["retrieve_knowledge", "formulate_answer",
                         "validate_answer"]
            elif "requires_action" in conclusions:
                steps = ["validate_action", "execute_action",
                         "confirm_result"]
            else:
                steps = ["acknowledge", "respond"]

        return {
            "layer": self.name,
            "intent": intent,
            "conclusions": conclusions,
            "plan_steps": steps,
            "steps_count": len(steps),
            "planned": True,
            "timestamp": time.time(),
        }
