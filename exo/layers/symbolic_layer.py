"""
EXO Layer — SymbolicLayer.

Couche symbolique : représentation structurée, faits, relations.
"""

import time

from ..core.cognitive_kernel import CognitiveLayer


class SymbolicLayer(CognitiveLayer):
    """Couche symbolique : transforme les extractions en représentation symbolique."""

    def __init__(self):
        super().__init__("symbolic")

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        entities = data.get("entities", [])
        intent = data.get("intent", "unknown")
        keywords = data.get("keywords", [])

        facts = self._build_facts(entities, intent, keywords)
        relations = self._build_relations(entities)

        return {
            "layer": self.name,
            "facts": facts,
            "relations": relations,
            "intent": intent,
            "symbol_count": len(facts) + len(relations),
            "symbolized": True,
            "timestamp": time.time(),
        }

    def _build_facts(self, entities: list[dict], intent: str,
                     keywords: list[str]) -> dict:
        facts: dict = {"intent": intent}
        for e in entities:
            facts[f"entity_{e.get('text', '')}"] = True
        for kw in keywords:
            facts[f"keyword_{kw}"] = True
        return facts

    def _build_relations(self, entities: list[dict]) -> list[dict]:
        relations = []
        for i, e1 in enumerate(entities):
            for e2 in entities[i + 1:]:
                relations.append({
                    "source": e1.get("text", ""),
                    "target": e2.get("text", ""),
                    "relation": "co_occurrence",
                })
        return relations
