"""
EXO Layer — InferenceLayer.

Couche d'inférence : raisonnement sur les faits symboliques.
"""

import time

from ..core.cognitive_kernel import CognitiveLayer


class InferenceLayer(CognitiveLayer):
    """Couche d'inférence : applique le raisonnement aux faits."""

    def __init__(self, rule_engine=None):
        super().__init__("inference")
        self._rule_engine = rule_engine

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        facts = data.get("facts", {})
        intent = data.get("intent", "unknown")

        inferred: dict = {}
        if self._rule_engine:
            result = self._rule_engine.process({"facts": facts})
            fired = result.get("fired", [])
            for r in fired:
                inferred[r["action"]] = True

        conclusions = self._derive_conclusions(facts, intent)

        return {
            "layer": self.name,
            "facts": facts,
            "inferred": inferred,
            "conclusions": conclusions,
            "rules_fired": len(inferred),
            "inferred_ok": True,
            "timestamp": time.time(),
        }

    def _derive_conclusions(self, facts: dict, intent: str) -> list[str]:
        conclusions = []
        if intent == "question":
            conclusions.append("requires_answer")
        elif intent == "command":
            conclusions.append("requires_action")
        elif intent == "statement":
            conclusions.append("requires_acknowledgment")

        entity_count = sum(1 for k in facts if k.startswith("entity_"))
        if entity_count > 1:
            conclusions.append("multi_entity_context")
        return conclusions
