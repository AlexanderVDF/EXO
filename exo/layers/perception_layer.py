"""
EXO Layer — PerceptionLayer.

Couche de perception : normalisation, validation d'entrée, extraction de type.
"""

import time

from ..core.cognitive_kernel import CognitiveLayer


class PerceptionLayer(CognitiveLayer):
    """Couche de perception : première couche du pipeline cognitif."""

    def __init__(self):
        super().__init__("perception")

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        input_text = data.get("text", "")
        input_type = data.get("type", "text")
        source = data.get("source", "unknown")

        tokens = input_text.split() if input_text else []

        return {
            "layer": self.name,
            "input_text": input_text,
            "input_type": input_type,
            "source": source,
            "tokens": tokens,
            "token_count": len(tokens),
            "perceived": True,
            "timestamp": time.time(),
        }
