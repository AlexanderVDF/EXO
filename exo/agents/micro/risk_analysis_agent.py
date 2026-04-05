"""
EXO Micro Agent — RiskAnalysisAgent.

Évaluation quantitative des risques d'une action.
"""

from ...core.cognitive_kernel import MicroAgent


class RiskAnalysisAgent(MicroAgent):
    """Agent micro : évalue les risques d'une décision."""

    def __init__(self):
        super().__init__("risk_analysis")

    def execute(self, context: dict) -> dict:
        self._stats["executions"] += 1
        action = context.get("action", "unknown")
        confidence = context.get("confidence", 0.5)

        risk_score = max(0.0, 1.0 - confidence)
        risk_level = "low" if risk_score < 0.3 else ("medium" if risk_score < 0.6 else "high")

        return {
            "agent": self.name,
            "action": action,
            "risk_score": round(risk_score, 3),
            "risk_level": risk_level,
            "acceptable": risk_level != "high",
        }
