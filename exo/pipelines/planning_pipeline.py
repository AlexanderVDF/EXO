"""
EXO Pipeline — PlanningPipeline.

Pipeline de planification : intention → HTN → contraintes
→ multi-objectifs → arbitrage → validation.
"""

import time

from ..core.cognitive_kernel import CognitivePipeline


class PlanningPipeline(CognitivePipeline):
    """Pipeline dédié à la planification hiérarchique."""

    def __init__(self, htn_engine=None, constraint_solver=None,
                 multi_objective_planner=None):
        super().__init__("planning")
        self._htn = htn_engine
        self._constraints = constraint_solver
        self._mop = multi_objective_planner

    def run(self, input_data: dict) -> dict:
        self._stats["runs"] += 1
        t0 = time.time()
        traces = []

        goal = input_data.get("goal", input_data.get("intent", "unknown"))
        constraints = input_data.get("constraints", {})

        # 1 — Décomposition HTN
        if self._htn:
            htn_result = self._htn.process({"goal": goal})
            raw_steps = htn_result.get("primitive_steps", [])
        else:
            raw_steps = [f"execute_{goal}"]
        traces.append({"step": "htn_decomposition", "plan_size": len(raw_steps)})

        # 2 — Vérification des contraintes
        valid_steps = raw_steps
        constraint_report = {"all_satisfied": True}
        if self._constraints and constraints:
            cr = self._constraints.process({
                "variables": {f"step_{i}": s for i, s in enumerate(raw_steps)},
                "constraints": constraints,
            })
            constraint_report = cr
        traces.append({"step": "constraint_check", "satisfied": constraint_report.get("all_satisfied", True)})

        # 3 — Optimisation multi-objectifs
        if self._mop and len(valid_steps) > 1:
            candidates = [{"name": s, "score": 0.5 + 0.1 * i} for i, s in enumerate(valid_steps)]
            mop_result = self._mop.process({
                "candidates": candidates,
                "objectives": input_data.get("objectives", [{"name": "efficiency", "weight": 1.0}])
            })
            ranking = mop_result.get("ranking", candidates)
        else:
            ranking = [{"name": s, "score": 0.5} for s in valid_steps]
        traces.append({"step": "multi_objective", "candidates": len(ranking)})

        # 4 — Arbitrage et validation
        final_plan = [r.get("name", r) if isinstance(r, dict) else r for r in ranking]

        self._traces.extend(traces)
        return {
            "pipeline": self.name,
            "goal": goal,
            "plan": final_plan,
            "constraint_report": constraint_report,
            "ranking": ranking,
            "validated": constraint_report.get("all_satisfied", True),
            "duration_ms": round((time.time() - t0) * 1000, 2),
        }
