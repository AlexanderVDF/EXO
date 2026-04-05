"""
EXO Core — CognitiveFlow.

Gestion du flux de données entre couches cognitives.
"""

import time
import copy


class CognitiveFlow:
    """Gestionnaire de flux de données inter‑couches."""

    def __init__(self):
        self._buffers: dict[str, dict] = {}
        self._trace: list[dict] = []
        self._stats = {"pushes": 0, "gets": 0}

    def push(self, layer_name: str, data: dict) -> None:
        """Stocker les données produites par une couche."""
        self._stats["pushes"] += 1
        self._buffers[layer_name] = copy.deepcopy(data)
        self._trace.append({
            "layer": layer_name,
            "action": "push",
            "keys": list(data.keys()),
            "timestamp": time.time(),
        })

    def get(self, layer_name: str) -> dict:
        """Récupérer les données d'une couche."""
        self._stats["gets"] += 1
        return copy.deepcopy(self._buffers.get(layer_name, {}))

    def has(self, layer_name: str) -> bool:
        return layer_name in self._buffers

    def get_trace(self) -> list[dict]:
        return list(self._trace)

    def clear(self) -> None:
        self._buffers.clear()
        self._trace.clear()
        for k in self._stats:
            self._stats[k] = 0

    def get_stats(self) -> dict:
        return dict(self._stats)

    @property
    def layers(self) -> list[str]:
        return list(self._buffers.keys())
