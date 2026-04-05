"""
EXO Layer — SupervisionLayer.

Couche de supervision : validation finale, audit, gouvernance.
"""

import time

from ..core.cognitive_kernel import CognitiveLayer


class SupervisionLayer(CognitiveLayer):
    """Couche de supervision : valide et audite la décision finale."""

    def __init__(self, supervisor=None):
        super().__init__("supervision")
        self._supervisor = supervisor

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        action = data.get("action", "no_action")
        confidence = data.get("confidence", 0.0)
        plan = data.get("plan", [])
        intent = data.get("intent", "unknown")

        approved = confidence >= 0.3
        reason = "confidence_sufficient" if approved else "low_confidence"

        if self._supervisor:
            val = self._supervisor.validate({
                "action": action, "reason": reason,
            })
            approved = val.get("valid", approved)

        return {
            "layer": self.name,
            "action": action,
            "plan": plan,
            "confidence": confidence,
            "approved": approved,
            "reason": reason,
            "intent": intent,
            "supervised": True,
            "timestamp": time.time(),
        }
