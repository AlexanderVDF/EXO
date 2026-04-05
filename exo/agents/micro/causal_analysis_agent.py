"""
EXO Micro Agent — CausalAnalysisAgent.

Analyse causale : propagation et recherche de cause racine.
"""

from ...core.cognitive_kernel import MicroAgent


class CausalAnalysisAgent(MicroAgent):
    """Agent micro : analyse les relations de causalité."""

    def __init__(self, causal_engine=None):
        super().__init__("causal_analysis")
        self._engine = causal_engine

    def execute(self, context: dict) -> dict:
        self._stats["executions"] += 1

        if self._engine:
            source = context.get("source", context.get("cause"))
            if source:
                result = self._engine.process({"source": source, "initial_value": 1.0})
                chain = result.get("chain", [])
                affected = {e["effect"]: e["strength"] for e in chain}
                return {
                    "agent": self.name,
                    "propagation": affected,
                    "chain": chain,
                }

        return {"agent": self.name, "propagation": {}, "chain": []}
