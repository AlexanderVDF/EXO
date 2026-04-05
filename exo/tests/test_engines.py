"""
Tests — Moteurs cognitifs EXO (engines/).

Couvre : RuleEngine, CausalGraph, Inference, HTN, Simulation,
Optimization, Observability, Governance engines.
"""

import pytest
from exo.core.cognitive_context import Rule
from exo.engines import (
    AdvancedRuleEngine,
    CausalGraphEngine,
    DeductiveReasoner,
    InductiveReasoner,
    AbductiveReasoner,
    ConstraintSolver,
    HTNPlusEngine,
    MultiObjectivePlanner,
    ScenarioPlanner,
    SimulationSandbox,
    PredictiveModelingEngine,
    OutcomeAnalysisEngine,
    CognitiveOptimizer,
    CognitiveTelemetryEngine,
    StructuredTracingEngine,
    CognitiveMetricsEngine,
    GovernancePermissionSystem,
    GovernanceMultiLevelValidation,
    GovernanceComplianceEngine,
    GovernanceAuditEngine,
)


# ── RuleEngine ──────────────────────────────────────────────

class TestAdvancedRuleEngine:
    def test_add_and_match(self):
        e = AdvancedRuleEngine()
        r = Rule("r1", "hot", "cool_down", priority=1)
        e.add_rule(r)
        res = e.process({"facts": {"hot": True}})
        actions = [r["action"] for r in res["fired"]]
        assert "cool_down" in actions

    def test_no_match(self):
        e = AdvancedRuleEngine()
        e.add_rule(Rule("r1", "hot", "cool_down"))
        res = e.process({"facts": {"cold": True}})
        assert res["fired"] == []

    def test_remove_rule(self):
        e = AdvancedRuleEngine()
        e.add_rule(Rule("r1", "x", "y"))
        e.remove_rule("r1")
        res = e.process({"facts": {"x": True}})
        assert res["fired"] == []

    def test_forward_chain(self):
        e = AdvancedRuleEngine()
        e.add_rule(Rule("r1", "a", "b"))
        res = e.forward_chain({"a": True}, max_iterations=3)
        assert res["iterations"] >= 1

    def test_health_check(self):
        e = AdvancedRuleEngine()
        assert e.health_check()["status"] == "ok"


# ── CausalGraph ─────────────────────────────────────────────

class TestCausalGraphEngine:
    def test_propagation(self):
        e = CausalGraphEngine()
        e.add_cause("rain", "flood", 0.8)
        res = e.process({"source": "rain", "initial_value": 1.0})
        effects = [c["effect"] for c in res["chain"]]
        assert "flood" in effects

    def test_impact_analysis(self):
        e = CausalGraphEngine()
        e.add_cause("a", "b", 0.5)
        e.add_cause("b", "c", 0.6)
        res = e.impact_analysis("a")
        assert "b" in res["affected_nodes"]

    def test_root_cause(self):
        e = CausalGraphEngine()
        e.add_cause("x", "y", 0.9)
        roots = e.root_cause_analysis("y")
        assert "x" in roots


# ── Inference ───────────────────────────────────────────────

class TestDeductiveReasoner:
    def test_valid(self):
        r = DeductiveReasoner()
        res = r.process({"premises": [{"holds": True}, {"holds": True}]})
        assert res["valid"] is True

    def test_invalid(self):
        r = DeductiveReasoner()
        res = r.process({"premises": [{"holds": True}, {"holds": False}]})
        assert res["valid"] is False


class TestInductiveReasoner:
    def test_patterns(self):
        r = InductiveReasoner()
        res = r.process({"observations": [{"a": 1, "b": 2}, {"a": 1, "c": 3}]})
        assert "a" in res["pattern"]


class TestAbductiveReasoner:
    def test_hypotheses(self):
        r = AbductiveReasoner()
        r.add_hypothesis("h1", ["e1"], plausibility=0.9)
        res = r.process({"observations": ["e1"]})
        assert len(res["candidates"]) == 1


class TestConstraintSolver:
    def test_satisfied(self):
        s = ConstraintSolver()
        res = s.process({
            "variables": {"x": 5},
            "constraints": [{"name": "c1", "variable": "x", "op": ">", "value": 3}],
        })
        assert res["feasible"] is True

    def test_violated(self):
        s = ConstraintSolver()
        res = s.process({
            "variables": {"x": 2},
            "constraints": [{"name": "c1", "variable": "x", "op": ">", "value": 3}],
        })
        assert res["feasible"] is False


# ── HTN ─────────────────────────────────────────────────────

class TestHTNPlusEngine:
    def test_decompose(self):
        e = HTNPlusEngine()
        e.define_method("cook", ["prep", "heat", "serve"])
        res = e.process({"goal": "cook"})
        assert res["primitive_steps"] == ["prep", "heat", "serve"]

    def test_recursive(self):
        e = HTNPlusEngine()
        e.define_method("travel", ["pack", "go"])
        e.define_method("go", ["drive", "arrive"])
        res = e.process({"goal": "travel"})
        assert "drive" in res["primitive_steps"]


class TestMultiObjectivePlanner:
    def test_ranking(self):
        p = MultiObjectivePlanner()
        res = p.process({
            "candidates": [
                {"name": "a", "speed": 10, "cost": 2},
                {"name": "b", "speed": 5, "cost": 8},
            ],
            "objectives": [
                {"name": "speed", "weight": 1.0},
                {"name": "cost", "weight": 0.5, "minimize": True},
            ],
        })
        assert len(res["ranking"]) == 2


# ── Simulation ──────────────────────────────────────────────

class TestScenarioPlanner:
    def test_generate(self):
        s = ScenarioPlanner()
        res = s.process({"parameters": {"weather": "rain"}, "variations": [
            {"name": "windy", "overrides": {"wind": True}}
        ]})
        assert len(res["scenarios"]) >= 2


class TestSimulationSandbox:
    def test_favorable(self):
        s = SimulationSandbox()
        res = s.process({"scenario": {"name": "t", "parameters": {"benefit": 0.9, "risk": 0.1}}})
        assert res["outcome"] == "favorable"

    def test_unfavorable(self):
        s = SimulationSandbox()
        res = s.process({"scenario": {"name": "t", "parameters": {"benefit": 0.1, "risk": 0.9}}})
        assert res["outcome"] == "unfavorable"


class TestPredictiveModelingEngine:
    def test_predict(self):
        e = PredictiveModelingEngine()
        e.register_model("m1", {"x": 2.0})
        res = e.process({"model": "m1", "inputs": {"x": 5}})
        assert res["prediction"] == 10.0


class TestOutcomeAnalysisEngine:
    def test_analyze(self):
        e = OutcomeAnalysisEngine()
        res = e.process({"results": [
            {"score": 0.8}, {"score": 0.3}, {"score": 0.6},
        ]})
        assert res["best"]["score"] == 0.8
        assert res["worst"]["score"] == 0.3


# ── Optimization ────────────────────────────────────────────

class TestCognitiveOptimizer:
    def test_optimize(self):
        o = CognitiveOptimizer()
        res = o.process({
            "candidates": [
                {"name": "a", "speed": 10, "cost": 5},
                {"name": "b", "speed": 8, "cost": 2},
            ],
            "criteria": [
                {"name": "speed", "weight": 1.0},
                {"name": "cost", "weight": 0.5, "minimize": True},
            ],
        })
        assert len(res["ranking"]) == 2
        assert res["best"]["name"] in ("a", "b")


# ── Observability Engines ───────────────────────────────────

class TestCognitiveTelemetryEngine:
    def test_log(self):
        e = CognitiveTelemetryEngine()
        e.process({"source": "test", "event_type": "info", "data": {}})
        assert len(e.get_events()) == 1


class TestStructuredTracingEngine:
    def test_trace(self):
        e = StructuredTracingEngine()
        e.process({"operation": "test_op"})
        traces = e.get_traces()
        assert len(traces) == 1


class TestCognitiveMetricsEngine:
    def test_record(self):
        e = CognitiveMetricsEngine()
        e.process({"name": "latency", "value": 42.0})
        agg = e.get_aggregate("latency")
        assert agg["avg"] == 42.0


# ── Governance Engines ──────────────────────────────────────

class TestGovernancePermissionSystem:
    def test_grant_check(self):
        e = GovernancePermissionSystem()
        e.process({"operation": "grant", "entity": "bot", "action": "speak"})
        res = e.process({"operation": "check", "entity": "bot", "action": "speak"})
        assert res["allowed"] is True

    def test_denied(self):
        e = GovernancePermissionSystem()
        res = e.process({"operation": "check", "entity": "bot", "action": "fly"})
        assert res["allowed"] is False


class TestGovernanceMultiLevelValidation:
    def test_valid(self):
        e = GovernanceMultiLevelValidation()
        res = e.process({"action": "greet", "rationale": "greeting user"})
        assert res["validated"] is True


class TestGovernanceComplianceEngine:
    def test_compliant(self):
        e = GovernanceComplianceEngine()
        res = e.process({"action": "greet", "entity": "user"})
        assert res["compliant"] is True


class TestGovernanceAuditEngine:
    def test_log_query(self):
        e = GovernanceAuditEngine()
        e.process({"action": "login", "category": "auth", "source": "user1"})
        res = e.query(category="auth")
        assert len(res) == 1
