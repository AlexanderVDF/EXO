"""
EXO Pipeline — SimulationPipeline.

Pipeline de simulation : plan → scénarios → simulation → analyse
→ arbitrage → décision.
"""

import time

from ..core.cognitive_kernel import CognitivePipeline


class SimulationPipeline(CognitivePipeline):
    """Pipeline dédié à la simulation de plans."""

    def __init__(self, scenario_planner=None, simulation_sandbox=None,
                 outcome_analysis=None):
        super().__init__("simulation")
        self._planner = scenario_planner
        self._sandbox = simulation_sandbox
        self._analysis = outcome_analysis

    def run(self, input_data: dict) -> dict:
        self._stats["runs"] += 1
        t0 = time.time()
        traces = []

        plan = input_data.get("plan", input_data.get("plan_steps", []))
        intent = input_data.get("intent", "unknown")

        # 1 — Génération de scénarios
        scenarios = []
        if self._planner:
            sr = self._planner.process({"context": intent, "factors": plan})
            scenarios = sr.get("scenarios", [])
            traces.append({"step": "scenario_generation", "count": len(scenarios)})
        else:
            scenarios = [{"name": "baseline", "parameters": {"steps": len(plan)}}]
            traces.append({"step": "scenario_generation", "count": 1})

        # 2 — Simulation de chaque scénario
        sim_results = []
        for sc in scenarios:
            if self._sandbox:
                r = self._sandbox.process({"scenario": sc})
            else:
                r = {"outcome": "favorable", "score": 0.7, "scenario": sc.get("name")}
            sim_results.append(r)
        traces.append({"step": "simulation", "count": len(sim_results)})

        # 3 — Analyse des résultats
        if self._analysis and sim_results:
            analysis = self._analysis.process({"results": sim_results})
        else:
            best = max(sim_results, key=lambda x: x.get("score", 0)) if sim_results else {}
            analysis = {"best": best, "recommendation": "proceed"}
        traces.append({"step": "analysis", "status": "ok"})

        # 4 — Arbitrage
        best_result = analysis.get("best", {})
        decision = best_result.get("outcome", "neutral") if best_result else "neutral"

        self._traces.extend(traces)
        return {
            "pipeline": self.name,
            "intent": intent,
            "scenarios": scenarios,
            "simulation_results": sim_results,
            "analysis": analysis,
            "decision": decision,
            "duration_ms": round((time.time() - t0) * 1000, 2),
        }
