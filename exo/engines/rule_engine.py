"""
EXO Engine — AdvancedRuleEngine.

Moteur de règles avancé : évaluation, priorisation, chaînage avant.
"""

import time
import uuid

from ..core.cognitive_kernel import CognitiveEngine
from ..core.cognitive_context import Rule


class AdvancedRuleEngine(CognitiveEngine):
    """Moteur de règles cognitif avancé."""

    def __init__(self):
        super().__init__("advanced_rule_engine")
        self._rules: list[Rule] = []
        self._history: list[dict] = []

    def add_rule(self, rule: Rule) -> None:
        self._rules.append(rule)
        self._rules.sort(key=lambda r: r.priority, reverse=True)

    def remove_rule(self, name: str) -> bool:
        before = len(self._rules)
        self._rules = [r for r in self._rules if r.name != name]
        return len(self._rules) < before

    def process(self, data: dict) -> dict:
        """Évaluer toutes les règles sur les faits fournis."""
        self._stats["processed"] += 1
        facts = data.get("facts", {})
        fired = []
        for rule in self._rules:
            if rule.matches(facts):
                fired.append(rule.to_dict())
        record = {
            "id": f"re_{uuid.uuid4().hex[:8]}",
            "total_rules": len(self._rules),
            "fired": fired,
            "fired_count": len(fired),
            "timestamp": time.time(),
        }
        self._history.append(record)
        if len(self._history) > 5000:
            self._history = self._history[-2500:]
        return record

    def forward_chain(self, facts: dict, max_iterations: int = 10) -> dict:
        """Chaînage avant : appliquer les règles itérativement."""
        current_facts = dict(facts)
        all_fired: list[str] = []
        for _ in range(max_iterations):
            result = self.process({"facts": current_facts})
            newly_fired = [r["name"] for r in result["fired"]
                           if r["name"] not in all_fired]
            if not newly_fired:
                break
            all_fired.extend(newly_fired)
            for r in result["fired"]:
                if r["name"] in newly_fired:
                    current_facts[r["action"]] = True
        return {"facts": current_facts, "fired_rules": all_fired,
                "iterations": len(all_fired)}

    @property
    def rule_count(self) -> int:
        return len(self._rules)
