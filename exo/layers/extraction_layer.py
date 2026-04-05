"""
EXO Layer — ExtractionLayer.

Couche d'extraction : entités, intentions, mots‑clés.
"""

import time

from ..core.cognitive_kernel import CognitiveLayer


class ExtractionLayer(CognitiveLayer):
    """Couche d'extraction d'informations."""

    INTENT_KEYWORDS = {
        "question": {"qui", "que", "quoi", "comment", "pourquoi", "où",
                      "quand", "quel", "quelle", "est-ce"},
        "command": {"fais", "exécute", "lance", "démarre", "arrête",
                     "ouvre", "ferme", "crée", "supprime"},
        "statement": {"je", "il", "elle", "nous", "c'est", "voici"},
    }

    def __init__(self):
        super().__init__("extraction")

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        tokens = data.get("tokens", [])
        text = data.get("input_text", "")

        entities = self._extract_entities(tokens)
        intent = self._detect_intent(tokens)
        keywords = self._extract_keywords(tokens)

        return {
            "layer": self.name,
            "entities": entities,
            "intent": intent,
            "keywords": keywords,
            "extracted": True,
            "timestamp": time.time(),
        }

    def _extract_entities(self, tokens: list[str]) -> list[dict]:
        entities = []
        for t in tokens:
            if t and t[0].isupper() and len(t) > 1:
                entities.append({"text": t, "type": "proper_noun"})
        return entities

    def _detect_intent(self, tokens: list[str]) -> str:
        lower_tokens = {t.lower() for t in tokens}
        for intent, kws in self.INTENT_KEYWORDS.items():
            if lower_tokens & kws:
                return intent
        return "unknown"

    def _extract_keywords(self, tokens: list[str]) -> list[str]:
        stop = {"le", "la", "les", "un", "une", "des", "de", "du", "et",
                "ou", "à", "en", "est", "a", "au", "ce", "se", "ne", "pas"}
        return [t for t in tokens if t.lower() not in stop and len(t) > 2]
