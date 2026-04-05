"""
Tests — Pipelines cognitifs EXO (pipelines/).

Couvre : MainCognitivePipeline, SimulationPipeline, PlanningPipeline.
"""

import pytest
from exo.engines import (
    AdvancedRuleEngine,
    HTNPlusEngine,
    SimulationSandbox,
    ScenarioPlanner,
    OutcomeAnalysisEngine,
    ConstraintSolver,
    MultiObjectivePlanner,
)
from exo.core.cognitive_context import Rule
from exo.core.cognitive_kernel import CognitiveSupervisor
from exo.pipelines import (
    MainCognitivePipeline,
    SimulationPipeline,
    PlanningPipeline,
)


# ── MainCognitivePipeline ───────────────────────────────────

class TestMainCognitivePipeline:
    def test_run_minimal(self):
        p = MainCognitivePipeline()
        res = p.run({"text": "Bonjour Paris"})
        assert res["pipeline"] == "cognitive"
        assert res["layers_executed"] == 8
        assert res["supervised"] is True

    def test_run_with_engines(self):
        rule = AdvancedRuleEngine()
        rule.add_rule(Rule("greet", "question", "respond", priority=1))
        htn = HTNPlusEngine()
        htn.define_method("respond", ["prepare_response", "deliver"])
        sand = SimulationSandbox()

        p = MainCognitivePipeline(
            rule_engine=rule,
            htn_engine=htn,
            simulation_sandbox=sand,
        )
        res = p.run({"text": "Quelle heure est-il ?"})
        assert res["supervised"] is True
        assert "action" in res

    def test_trace(self):
        p = MainCognitivePipeline()
        p.run({"text": "Hello"})
        traces = p.trace()
        assert len(traces) == 8

    def test_stats(self):
        p = MainCognitivePipeline()
        p.run({"text": "Test"})
        s = p.get_stats()
        assert s["runs"] == 1
        assert s["errors"] == 0

    def test_with_supervisor(self):
        sup = CognitiveSupervisor()
        p = MainCognitivePipeline(supervisor=sup)
        res = p.run({"text": "Vérifie ceci"})
        assert res["supervised"] is True

    def test_empty_input(self):
        p = MainCognitivePipeline()
        res = p.run({"text": ""})
        assert res["pipeline"] == "cognitive"


# ── SimulationPipeline ──────────────────────────────────────

class TestSimulationPipeline:
    def test_run_minimal(self):
        p = SimulationPipeline()
        res = p.run({"intent": "test"})
        assert res["pipeline"] == "simulation"
        assert "decision" in res

    def test_with_engines(self):
        sp = ScenarioPlanner()
        sb = SimulationSandbox()
        oa = OutcomeAnalysisEngine()
        p = SimulationPipeline(
            scenario_planner=sp,
            simulation_sandbox=sb,
            outcome_analysis=oa,
        )
        res = p.run({"intent": "weather", "plan": ["check", "report"]})
        assert len(res["scenarios"]) >= 1
        assert len(res["simulation_results"]) >= 1

    def test_stats(self):
        p = SimulationPipeline()
        p.run({"intent": "x"})
        assert p.get_stats()["runs"] == 1


# ── PlanningPipeline ────────────────────────────────────────

class TestPlanningPipeline:
    def test_run_minimal(self):
        p = PlanningPipeline()
        res = p.run({"goal": "cook"})
        assert res["pipeline"] == "planning"
        assert res["validated"] is True

    def test_with_htn(self):
        htn = HTNPlusEngine()
        htn.define_method("cook", ["prep", "heat", "serve"])
        p = PlanningPipeline(htn_engine=htn)
        res = p.run({"goal": "cook"})
        assert "prep" in res["plan"]

    def test_with_constraints(self):
        cs = ConstraintSolver()
        p = PlanningPipeline(constraint_solver=cs)
        res = p.run({
            "goal": "build",
            "constraints": [{"name": "c1", "variable": "step_0", "op": "!=", "value": ""}],
        })
        assert "constraint_report" in res

    def test_with_mop(self):
        mop = MultiObjectivePlanner()
        p = PlanningPipeline(multi_objective_planner=mop)
        res = p.run({
            "goal": "transport",
            "objectives": [{"name": "efficiency", "weight": 1.0}],
        })
        assert len(res["ranking"]) >= 1

    def test_stats(self):
        p = PlanningPipeline()
        p.run({"goal": "x"})
        p.run({"goal": "y"})
        assert p.get_stats()["runs"] == 2
