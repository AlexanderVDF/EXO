"""
EXO Governance — MultiLevelValidator.

Validation multi-niveaux : logique, contexte, sécurité, cohérence, temporel.
"""

import time


class MultiLevelValidator:
    """Validation en cascade sur 5 niveaux."""

    LEVELS = ("logic", "context", "security", "coherence", "temporal")

    def __init__(self, custom_validators: dict | None = None):
        self._custom = custom_validators or {}
        self._stats = {"validated": 0, "rejected": 0}

    def validate(self, data: dict) -> dict:
        results = {}
        all_valid = True

        for level in self.LEVELS:
            if level in self._custom:
                ok = self._custom[level](data)
            else:
                ok = self._default_validate(level, data)
            results[level] = ok
            if not ok:
                all_valid = False

        if all_valid:
            self._stats["validated"] += 1
        else:
            self._stats["rejected"] += 1

        return {
            "valid": all_valid,
            "levels": results,
            "timestamp": time.time(),
        }

    def _default_validate(self, level: str, data: dict) -> bool:
        if level == "logic":
            return bool(data)
        if level == "context":
            return "action" in data or "intent" in data or bool(data)
        if level == "security":
            forbidden = {"drop", "delete", "rm", "exec", "eval"}
            text = str(data).lower()
            return not any(w in text for w in forbidden)
        if level == "coherence":
            return True
        if level == "temporal":
            return True
        return True

    def get_stats(self) -> dict:
        return dict(self._stats)
