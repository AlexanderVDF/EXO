"""
EXO Engine — Simulation.

ScenarioPlanner, SimulationSandbox, PredictiveModelingEngine,
OutcomeAnalysisEngine.
"""

import time
import uuid
import copy

from ..core.cognitive_kernel import CognitiveEngine
from ..core.cognitive_context import Scenario, SimulationResult


class ScenarioPlanner(CognitiveEngine):
    """Planificateur de scénarios."""

    def __init__(self):
        super().__init__("scenario_planner")

    def process(self, data: dict) -> dict:
        """Générer des scénarios à partir d'un contexte."""
        self._stats["processed"] += 1
        base_params = data.get("parameters", {})
        variations = data.get("variations", [])

        scenarios = []
        # scénario de base
        scenarios.append(Scenario(
            name="baseline", parameters=base_params,
            conditions=["default"],
        ))
        # variations
        for var in variations:
            params = dict(base_params)
            params.update(var.get("overrides", {}))
            scenarios.append(Scenario(
                name=var.get("name", f"var_{len(scenarios)}"),
                parameters=params,
                conditions=var.get("conditions", []),
            ))

        return {
            "id": f"sp_{uuid.uuid4().hex[:8]}",
            "scenarios": [s.to_dict() for s in scenarios],
            "count": len(scenarios),
            "timestamp": time.time(),
        }


class SimulationSandbox(CognitiveEngine):
    """Bac à sable de simulation déterministe."""

    def __init__(self):
        super().__init__("simulation_sandbox")

    def process(self, data: dict) -> dict:
        """Simuler un scénario dans un environnement isolé."""
        self._stats["processed"] += 1
        scenario = data.get("scenario", {})
        name = scenario.get("name", "unknown")
        params = scenario.get("parameters", {})

        # Simulation déterministe : le résultat est fonction des paramètres
        risk = params.get("risk", 0.0)
        benefit = params.get("benefit", 0.0)
        score = round(benefit - risk, 3) if isinstance(risk, (int, float)) \
            and isinstance(benefit, (int, float)) else 0.0

        outcome = "favorable" if score > 0 else "neutral" if score == 0 \
            else "unfavorable"

        result = SimulationResult(
            scenario=name, outcome=outcome,
            metrics={"score": score, "risk": risk, "benefit": benefit},
        )

        return {
            "id": f"sim_{uuid.uuid4().hex[:8]}",
            "result": result.to_dict(),
            "outcome": outcome,
            "score": score,
            "timestamp": time.time(),
        }


class PredictiveModelingEngine(CognitiveEngine):
    """Moteur de modélisation prédictive (basé sur des heuristiques)."""

    def __init__(self):
        super().__init__("predictive_modeling_engine")
        self._models: dict[str, dict] = {}

    def register_model(self, name: str, weights: dict[str, float]) -> None:
        self._models[name] = {"weights": weights}

    def process(self, data: dict) -> dict:
        """Prédire un résultat basé sur les pondérations du modèle."""
        self._stats["processed"] += 1
        model_name = data.get("model", "")
        inputs = data.get("inputs", {})

        model = self._models.get(model_name)
        if model is None:
            return {"id": f"pm_{uuid.uuid4().hex[:8]}", "error": "model_not_found",
                    "timestamp": time.time()}

        prediction = 0.0
        for key, weight in model["weights"].items():
            val = inputs.get(key, 0.0)
            if isinstance(val, (int, float)):
                prediction += val * weight

        return {
            "id": f"pm_{uuid.uuid4().hex[:8]}",
            "model": model_name,
            "prediction": round(prediction, 4),
            "inputs": inputs,
            "timestamp": time.time(),
        }


class OutcomeAnalysisEngine(CognitiveEngine):
    """Moteur d'analyse des résultats de simulation."""

    def __init__(self):
        super().__init__("outcome_analysis_engine")

    def process(self, data: dict) -> dict:
        """Analyser et comparer des résultats de simulation."""
        self._stats["processed"] += 1
        results = data.get("results", [])

        if not results:
            return {"id": f"oa_{uuid.uuid4().hex[:8]}", "analysis": "no_results",
                    "timestamp": time.time()}

        scores = [r.get("score", 0.0) for r in results
                  if isinstance(r.get("score"), (int, float))]

        best = max(results, key=lambda r: r.get("score", 0.0))
        worst = min(results, key=lambda r: r.get("score", 0.0))
        avg = round(sum(scores) / len(scores), 4) if scores else 0.0

        return {
            "id": f"oa_{uuid.uuid4().hex[:8]}",
            "total_results": len(results),
            "best": best,
            "worst": worst,
            "average_score": avg,
            "recommendation": best.get("scenario", "unknown"),
            "timestamp": time.time(),
        }
