"""
EXO Engine — HTN + MultiObjectivePlanner.

Planification hiérarchique (HTN) et planification multi‑objectifs.
"""

import time
import uuid

from ..core.cognitive_kernel import CognitiveEngine
from ..core.cognitive_context import Plan


class HTNPlusEngine(CognitiveEngine):
    """Moteur HTN+ : décomposition hiérarchique de tâches."""

    def __init__(self):
        super().__init__("htn_plus_engine")
        self._methods: dict[str, list[str]] = {}

    def define_method(self, task: str, subtasks: list[str]) -> None:
        """Définir une méthode de décomposition."""
        self._methods[task] = list(subtasks)

    def process(self, data: dict) -> dict:
        """Décomposer un objectif en plan via HTN."""
        self._stats["processed"] += 1
        goal = data.get("goal", "")
        max_depth = data.get("max_depth", 5)

        steps = self._decompose(goal, max_depth, 0)
        plan = Plan(name=f"htn_{goal}", steps=steps, goal=goal)

        return {
            "id": f"htn_{uuid.uuid4().hex[:8]}",
            "goal": goal,
            "plan": plan.to_dict(),
            "steps_count": len(steps),
            "primitive_steps": steps,
            "timestamp": time.time(),
        }

    def _decompose(self, task: str, max_depth: int,
                   depth: int) -> list[str]:
        if depth >= max_depth or task not in self._methods:
            return [task]
        result = []
        for sub in self._methods[task]:
            result.extend(self._decompose(sub, max_depth, depth + 1))
        return result


class MultiObjectivePlanner(CognitiveEngine):
    """Planificateur multi‑objectifs avec arbitrage."""

    def __init__(self):
        super().__init__("multi_objective_planner")

    def process(self, data: dict) -> dict:
        """Évaluer des plans candidats selon plusieurs objectifs."""
        self._stats["processed"] += 1
        candidates = data.get("candidates", [])
        objectives = data.get("objectives", [])

        scored = []
        for cand in candidates:
            name = cand.get("name", "unnamed")
            scores = {}
            total = 0.0
            for obj in objectives:
                obj_name = obj.get("name", "")
                weight = obj.get("weight", 1.0)
                value = cand.get(obj_name, 0.0)
                scores[obj_name] = round(value * weight, 3)
                total += scores[obj_name]
            scored.append({"name": name, "scores": scores,
                           "total": round(total, 3)})

        scored.sort(key=lambda s: s["total"], reverse=True)
        best = scored[0] if scored else None

        return {
            "id": f"mop_{uuid.uuid4().hex[:8]}",
            "candidates_count": len(candidates),
            "objectives_count": len(objectives),
            "ranking": scored,
            "best": best,
            "timestamp": time.time(),
        }
