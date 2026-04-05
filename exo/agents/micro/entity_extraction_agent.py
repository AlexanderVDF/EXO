"""
EXO Micro Agent — EntityExtractionAgent.

Extraction d'entités nommées depuis le texte brut.
"""

from ...core.cognitive_kernel import MicroAgent


class EntityExtractionAgent(MicroAgent):
    """Agent micro : extrait les entités d'un texte."""

    def __init__(self):
        super().__init__("entity_extraction")

    def execute(self, context: dict) -> dict:
        self._stats["executions"] += 1
        text = context.get("text", context.get("input", ""))

        if not isinstance(text, str):
            return {"agent": self.name, "entities": []}

        words = text.split()
        entities = [w for w in words if w and w[0].isupper() and len(w) > 1]

        return {
            "agent": self.name,
            "entities": entities,
            "entity_count": len(entities),
        }
