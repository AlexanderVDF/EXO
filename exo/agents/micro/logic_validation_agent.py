"""
EXO Micro Agent — LogicValidationAgent.

Validation logique des propositions et cohérence.
"""

from ...core.cognitive_kernel import MicroAgent


class LogicValidationAgent(MicroAgent):
    """Agent micro : vérifie la cohérence logique."""

    def __init__(self):
        super().__init__("logic_validation")

    def execute(self, context: dict) -> dict:
        self._stats["executions"] += 1
        premises = context.get("premises", [])
        conclusion = context.get("conclusion", context.get("action"))

        # Vérification de cohérence simple
        contradictions = []
        for i, p1 in enumerate(premises):
            for p2 in premises[i + 1:]:
                if isinstance(p1, str) and isinstance(p2, str):
                    if p1.startswith("not_") and p1[4:] == p2:
                        contradictions.append((p1, p2))
                    elif p2.startswith("not_") and p2[4:] == p1:
                        contradictions.append((p1, p2))

        valid = len(contradictions) == 0
        return {
            "agent": self.name,
            "valid": valid,
            "contradictions": contradictions,
            "conclusion": conclusion,
        }
