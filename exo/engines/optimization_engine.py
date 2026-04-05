"""
EXO Engine — CognitiveOptimizer.

Optimisation cognitive : sélection, filtrage, arbitrage.
"""

import time
import uuid

from ..core.cognitive_kernel import CognitiveEngine


class CognitiveOptimizer(CognitiveEngine):
    """Optimiseur cognitif multi‑critères."""

    def __init__(self):
        super().__init__("cognitive_optimizer")
        self._history: list[dict] = []

    def process(self, data: dict) -> dict:
        """Optimiser une sélection parmi des candidats."""
        self._stats["processed"] += 1
        candidates = data.get("candidates", [])
        criteria = data.get("criteria", [])
        strategy = data.get("strategy", "weighted_sum")

        scored = []
        for cand in candidates:
            name = cand.get("name", "unnamed")
            total = 0.0
            detail = {}
            for crit in criteria:
                crit_name = crit.get("name", "")
                weight = crit.get("weight", 1.0)
                minimize = crit.get("minimize", False)
                val = cand.get(crit_name, 0.0)
                if isinstance(val, (int, float)):
                    adjusted = -val if minimize else val
                    weighted = round(adjusted * weight, 4)
                    detail[crit_name] = weighted
                    total += weighted
            scored.append({"name": name, "scores": detail,
                           "total": round(total, 4)})

        scored.sort(key=lambda s: s["total"], reverse=True)
        best = scored[0] if scored else None

        record = {
            "id": f"opt_{uuid.uuid4().hex[:8]}",
            "strategy": strategy,
            "candidates_count": len(candidates),
            "criteria_count": len(criteria),
            "ranking": scored,
            "best": best,
            "timestamp": time.time(),
        }
        self._history.append(record)
        if len(self._history) > 5000:
            self._history = self._history[-2500:]
        return record
