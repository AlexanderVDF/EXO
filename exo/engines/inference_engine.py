"""
EXO Engine — Inference Engines.

Quatre raisonneurs : déductif, inductif, abductif, solveur de contraintes.
"""

import time
import uuid

from ..core.cognitive_kernel import CognitiveEngine


class DeductiveReasoner(CognitiveEngine):
    """Raisonnement déductif : prémisses → conclusion."""

    def __init__(self):
        super().__init__("deductive_reasoner")

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        premises = data.get("premises", [])
        conclusion = data.get("hypothesis", "")
        valid = all(p.get("holds", False) for p in premises) if premises else False
        return {
            "id": f"ded_{uuid.uuid4().hex[:8]}",
            "method": "deductive",
            "premises_count": len(premises),
            "hypothesis": conclusion,
            "valid": valid,
            "confidence": 1.0 if valid else 0.0,
            "timestamp": time.time(),
        }


class InductiveReasoner(CognitiveEngine):
    """Raisonnement inductif : observations → généralisation."""

    def __init__(self):
        super().__init__("inductive_reasoner")

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        observations = data.get("observations", [])
        if not observations:
            return {"id": f"ind_{uuid.uuid4().hex[:8]}",
                    "method": "inductive", "pattern": None,
                    "confidence": 0.0, "timestamp": time.time()}

        # Trouver les clés communes à toutes les observations
        common_keys = set(observations[0].keys())
        for obs in observations[1:]:
            common_keys &= set(obs.keys())

        pattern = {}
        for key in common_keys:
            values = [obs[key] for obs in observations]
            if len(set(str(v) for v in values)) == 1:
                pattern[key] = values[0]

        confidence = len(pattern) / max(len(common_keys), 1)
        return {
            "id": f"ind_{uuid.uuid4().hex[:8]}",
            "method": "inductive",
            "observations_count": len(observations),
            "pattern": pattern,
            "confidence": round(confidence, 3),
            "timestamp": time.time(),
        }


class AbductiveReasoner(CognitiveEngine):
    """Raisonnement abductif : effet → meilleure explication."""

    def __init__(self):
        super().__init__("abductive_reasoner")
        self._hypotheses: list[dict] = []

    def add_hypothesis(self, name: str, explains: list[str],
                       plausibility: float = 0.5) -> None:
        self._hypotheses.append({
            "name": name, "explains": explains,
            "plausibility": plausibility,
        })

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        observations = set(data.get("observations", []))
        if not observations:
            return {"id": f"abd_{uuid.uuid4().hex[:8]}",
                    "method": "abductive", "best": None,
                    "confidence": 0.0, "timestamp": time.time()}

        scored = []
        for hyp in self._hypotheses:
            explained = observations & set(hyp["explains"])
            coverage = len(explained) / len(observations) if observations else 0
            score = coverage * hyp["plausibility"]
            scored.append({**hyp, "coverage": round(coverage, 3),
                           "score": round(score, 3)})

        scored.sort(key=lambda h: h["score"], reverse=True)
        best = scored[0] if scored else None
        return {
            "id": f"abd_{uuid.uuid4().hex[:8]}",
            "method": "abductive",
            "best": best,
            "candidates": scored[:5],
            "confidence": best["score"] if best else 0.0,
            "timestamp": time.time(),
        }


class ConstraintSolver(CognitiveEngine):
    """Solveur de contraintes : vérification + résolution."""

    def __init__(self):
        super().__init__("constraint_solver")

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        variables = data.get("variables", {})
        constraints = data.get("constraints", [])

        satisfied = []
        violated = []
        for c in constraints:
            name = c.get("name", "unnamed")
            var = c.get("variable", "")
            op = c.get("op", "==")
            value = c.get("value")
            actual = variables.get(var)

            ok = self._evaluate(actual, op, value)
            (satisfied if ok else violated).append(name)

        return {
            "id": f"cs_{uuid.uuid4().hex[:8]}",
            "method": "constraint",
            "total_constraints": len(constraints),
            "satisfied": satisfied,
            "violated": violated,
            "feasible": len(violated) == 0,
            "timestamp": time.time(),
        }

    @staticmethod
    def _evaluate(actual, op: str, expected) -> bool:
        if actual is None:
            return False
        ops = {
            "==": lambda a, b: a == b,
            "!=": lambda a, b: a != b,
            ">": lambda a, b: a > b,
            "<": lambda a, b: a < b,
            ">=": lambda a, b: a >= b,
            "<=": lambda a, b: a <= b,
        }
        fn = ops.get(op)
        if fn is None:
            return False
        try:
            return fn(actual, expected)
        except TypeError:
            return False
