"""
EXO Layer — DecisionLayer.

Couche de décision : arbitrage final et sélection du plan.
"""

import time

from ..core.cognitive_kernel import CognitiveLayer


class DecisionLayer(CognitiveLayer):
    """Couche de décision : produit la décision finale."""

    def __init__(self):
        super().__init__("decision")

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        plan_steps = data.get("plan_steps", [])
        sim_results = data.get("simulation_results", [])
        conclusions = data.get("conclusions", [])
        intent = data.get("intent", "unknown")

        # Sélectionner le meilleur résultat de simulation
        best_score = 0.0
        best_outcome = "neutral"
        for sr in sim_results:
            score = sr.get("score", 0.0)
            if score > best_score:
                best_score = score
                best_outcome = sr.get("outcome", "neutral")

        # Décision
        action = plan_steps[0] if plan_steps else "no_action"
        confidence = min(best_score + 0.2, 1.0)

        return {
            "layer": self.name,
            "action": action,
            "plan": plan_steps,
            "outcome": best_outcome,
            "confidence": round(confidence, 3),
            "intent": intent,
            "decided": True,
            "timestamp": time.time(),
        }
