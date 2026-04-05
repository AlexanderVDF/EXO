"""
EXO Micro Agent — RuleVerificationAgent.

Vérifie les règles applicables au contexte courant.
"""

from ...core.cognitive_kernel import MicroAgent


class RuleVerificationAgent(MicroAgent):
    """Agent micro : vérifie les règles sur un ensemble de faits."""

    def __init__(self, rule_engine=None):
        super().__init__("rule_verification")
        self._engine = rule_engine

    def execute(self, context: dict) -> dict:
        self._stats["executions"] += 1
        facts = context.get("facts", {})

        if self._engine:
            result = self._engine.process({"facts": facts})
            fired = result.get("fired", [])
            actions = [r["action"] for r in fired if "action" in r]
            return {
                "agent": self.name,
                "matched_rules": fired,
                "actions": actions,
            }

        return {"agent": self.name, "matched_rules": [], "actions": []}
