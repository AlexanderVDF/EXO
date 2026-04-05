"""
Tests — Agents EXO (agents/macro + agents/micro).

Couvre : 5 macro agents + 8 micro agents.
"""

import pytest
from exo.agents import (
    CognitionAgent,
    SimulationAgent,
    PlanningAgent,
    ObservabilityAgent,
    GovernanceAgent,
    EntityExtractionAgent,
    RuleVerificationAgent,
    CausalAnalysisAgent,
    HTNExpansionAgent,
    LocalSimulationAgent,
    RiskAnalysisAgent,
    LogicValidationAgent,
    MetricsCollectionAgent,
)
from exo.engines import (
    AdvancedRuleEngine,
    CausalGraphEngine,
    HTNPlusEngine,
    SimulationSandbox,
)
from exo.core.cognitive_context import Rule
from exo.pipelines import MainCognitivePipeline, SimulationPipeline, PlanningPipeline
from exo.governance import PermissionManager, MultiLevelValidator, ComplianceChecker, AuditLogger
from exo.observability import TelemetryCollector, TracingService, MetricsRegistry


# ── Macro Agents ────────────────────────────────────────────

class TestCognitionAgent:
    def test_with_pipeline(self):
        p = MainCognitivePipeline()
        a = CognitionAgent(pipeline=p)
        res = a.execute({"text": "Bonjour le monde"})
        assert res["agent"] == "cognition"
        assert res["supervised"] is True

    def test_with_sub_agents(self):
        a = CognitionAgent()
        a.add_agent(EntityExtractionAgent())
        res = a.execute({"text": "Paris Berlin"})
        assert res["agent"] == "cognition"

    def test_report(self):
        a = CognitionAgent()
        a.execute({"text": "test"})
        r = a.report()
        assert r["agent"] == "cognition"
        assert r["stats"]["executions"] == 1


class TestSimulationAgent:
    def test_with_pipeline(self):
        p = SimulationPipeline()
        a = SimulationAgent(pipeline=p)
        res = a.execute({"intent": "test"})
        assert res["agent"] == "simulation"

    def test_without_pipeline(self):
        a = SimulationAgent()
        res = a.execute({"intent": "x"})
        assert res["agent"] == "simulation"


class TestPlanningAgent:
    def test_with_pipeline(self):
        p = PlanningPipeline()
        a = PlanningAgent(pipeline=p)
        res = a.execute({"goal": "build"})
        assert res["agent"] == "planning"

    def test_with_sub_agents(self):
        a = PlanningAgent()
        a.add_agent(HTNExpansionAgent())
        res = a.execute({"goal": "cook"})
        assert res["agent"] == "planning"


class TestObservabilityAgent:
    def test_with_services(self):
        t = TelemetryCollector()
        tr = TracingService()
        m = MetricsRegistry()
        a = ObservabilityAgent(telemetry=t, tracing=tr, metrics=m)
        res = a.execute({"text": "test"})
        assert res["agent"] == "observability"
        assert t.count() == 1

    def test_without_services(self):
        a = ObservabilityAgent()
        res = a.execute({})
        assert res["agent"] == "observability"


class TestGovernanceAgent:
    def test_approved(self):
        perm = PermissionManager()
        perm.grant("bot", "speak")
        val = MultiLevelValidator()
        comp = ComplianceChecker()
        audit = AuditLogger()
        a = GovernanceAgent(
            permission_mgr=perm, validator=val,
            compliance=comp, audit=audit,
        )
        res = a.execute({"entity": "bot", "action": "speak"})
        assert res["approved"] is True
        assert audit.count() == 1

    def test_denied_no_permission(self):
        perm = PermissionManager()
        a = GovernanceAgent(permission_mgr=perm)
        res = a.execute({"entity": "bot", "action": "fly"})
        assert res["approved"] is False

    def test_without_services(self):
        a = GovernanceAgent()
        res = a.execute({"action": "test"})
        assert res["approved"] is True


# ── Micro Agents ────────────────────────────────────────────

class TestEntityExtractionAgent:
    def test_extract(self):
        a = EntityExtractionAgent()
        res = a.execute({"text": "Paris est grand Berlin aussi"})
        assert "Paris" in res["entities"]
        assert "Berlin" in res["entities"]

    def test_empty(self):
        a = EntityExtractionAgent()
        res = a.execute({"text": ""})
        assert res["entities"] == []

    def test_stats(self):
        a = EntityExtractionAgent()
        a.execute({"text": "Test"})
        assert a.report()["stats"]["executions"] == 1


class TestRuleVerificationAgent:
    def test_with_engine(self):
        e = AdvancedRuleEngine()
        e.add_rule(Rule("r1", "hot", "cool"))
        a = RuleVerificationAgent(rule_engine=e)
        res = a.execute({"facts": {"hot": True}})
        assert "cool" in res["actions"]
        assert len(res["matched_rules"]) == 1

    def test_without_engine(self):
        a = RuleVerificationAgent()
        res = a.execute({"facts": {}})
        assert res["matched_rules"] == []


class TestCausalAnalysisAgent:
    def test_with_engine(self):
        e = CausalGraphEngine()
        e.add_cause("rain", "flood", 0.9)
        a = CausalAnalysisAgent(causal_engine=e)
        res = a.execute({"source": "rain"})
        assert "flood" in res["propagation"]

    def test_without_engine(self):
        a = CausalAnalysisAgent()
        res = a.execute({})
        assert res["propagation"] == {}


class TestHTNExpansionAgent:
    def test_with_engine(self):
        e = HTNPlusEngine()
        e.define_method("cook", ["prep", "serve"])
        a = HTNExpansionAgent(htn_engine=e)
        res = a.execute({"goal": "cook"})
        assert res["plan"] == ["prep", "serve"]

    def test_without_engine(self):
        a = HTNExpansionAgent()
        res = a.execute({"goal": "build"})
        assert res["plan"] == ["execute_build"]


class TestLocalSimulationAgent:
    def test_with_sandbox(self):
        sb = SimulationSandbox()
        a = LocalSimulationAgent(sandbox=sb)
        res = a.execute({"scenario": {
            "name": "t", "parameters": {"benefit": 0.8, "risk": 0.1},
        }})
        assert res["simulation"]["outcome"] == "favorable"

    def test_without_sandbox(self):
        a = LocalSimulationAgent()
        res = a.execute({"scenario": {
            "name": "t", "parameters": {"benefit": 0.7, "risk": 0.1},
        }})
        assert abs(res["simulation"]["score"] - 0.6) < 0.01


class TestRiskAnalysisAgent:
    def test_low_risk(self):
        a = RiskAnalysisAgent()
        res = a.execute({"action": "greet", "confidence": 0.9})
        assert res["risk_level"] == "low"
        assert res["acceptable"] is True

    def test_high_risk(self):
        a = RiskAnalysisAgent()
        res = a.execute({"action": "delete", "confidence": 0.1})
        assert res["risk_level"] == "high"
        assert res["acceptable"] is False


class TestLogicValidationAgent:
    def test_valid(self):
        a = LogicValidationAgent()
        res = a.execute({"premises": ["sunny", "warm"]})
        assert res["valid"] is True

    def test_contradiction(self):
        a = LogicValidationAgent()
        res = a.execute({"premises": ["sunny", "not_sunny"]})
        assert res["valid"] is False
        assert len(res["contradictions"]) == 1


class TestMetricsCollectionAgent:
    def test_with_registry(self):
        reg = MetricsRegistry()
        a = MetricsCollectionAgent(metrics_registry=reg)
        res = a.execute({"metrics": {"latency": 42, "count": 5}, "source": "test"})
        assert res["count"] == 2
        assert reg.aggregate("latency")["avg"] == 42.0

    def test_without_registry(self):
        a = MetricsCollectionAgent()
        res = a.execute({"metrics": {"x": 1}})
        assert res["count"] == 0
