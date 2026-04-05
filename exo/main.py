"""
EXO Cognitive Framework — Point d'entrée principal.

Démontre l'architecture cognitive complète v1→v25 :
  Core → Engines → Layers → Pipelines → Agents
  + Governance + Observability.
"""

from exo.core import (
    CognitiveState,
    KnowledgeGraph,
    CognitiveContext,
    CognitiveSupervisor,
    Rule,
)
from exo.engines import (
    AdvancedRuleEngine,
    CausalGraphEngine,
    HTNPlusEngine,
    SimulationSandbox,
    ScenarioPlanner,
    OutcomeAnalysisEngine,
    CognitiveOptimizer,
    ConstraintSolver,
    MultiObjectivePlanner,
)
from exo.pipelines import MainCognitivePipeline, SimulationPipeline, PlanningPipeline
from exo.agents import (
    CognitionAgent,
    SimulationAgent,
    PlanningAgent,
    ObservabilityAgent,
    GovernanceAgent,
    EntityExtractionAgent,
    RuleVerificationAgent,
    HTNExpansionAgent,
    RiskAnalysisAgent,
)
from exo.governance import PermissionManager, MultiLevelValidator, ComplianceChecker, AuditLogger
from exo.observability import TelemetryCollector, TracingService, MetricsRegistry, ObservabilityDashboard


def build_system():
    """Construit et retourne le système cognitif complet."""

    # ── Engines ─────────────────────────────────────────
    rule_engine = AdvancedRuleEngine()
    rule_engine.add_rule(Rule("question", "question", "generate_answer", priority=2))
    rule_engine.add_rule(Rule("command", "command", "execute_command", priority=3))
    rule_engine.add_rule(Rule("greeting", "statement", "acknowledge", priority=1))

    causal = CausalGraphEngine()
    causal.add_cause("user_input", "intent_detection", 1.0)
    causal.add_cause("intent_detection", "response_generation", 0.9)

    htn = HTNPlusEngine()
    htn.define_method("respond", ["analyze", "plan", "generate", "validate"])
    htn.define_method("analyze", ["parse", "extract_entities", "classify"])

    sandbox = SimulationSandbox()
    supervisor = CognitiveSupervisor()

    # ── Pipelines ───────────────────────────────────────
    cognitive_pipeline = MainCognitivePipeline(
        rule_engine=rule_engine,
        htn_engine=htn,
        simulation_sandbox=sandbox,
        supervisor=supervisor,
    )

    sim_pipeline = SimulationPipeline(
        scenario_planner=ScenarioPlanner(),
        simulation_sandbox=sandbox,
        outcome_analysis=OutcomeAnalysisEngine(),
    )

    plan_pipeline = PlanningPipeline(
        htn_engine=htn,
        constraint_solver=ConstraintSolver(),
        multi_objective_planner=MultiObjectivePlanner(),
    )

    # ── Governance ──────────────────────────────────────
    perms = PermissionManager()
    perms.grant("cognition_agent", "read")
    perms.grant("cognition_agent", "respond")
    perms.grant("governance_agent", "audit")

    validator = MultiLevelValidator()
    compliance = ComplianceChecker()
    audit = AuditLogger()

    # ── Observability ───────────────────────────────────
    telemetry = TelemetryCollector()
    tracing = TracingService()
    metrics = MetricsRegistry()
    dashboard = ObservabilityDashboard(telemetry, tracing, metrics)

    # ── Agents ──────────────────────────────────────────
    cognition = CognitionAgent(pipeline=cognitive_pipeline)
    simulation = SimulationAgent(pipeline=sim_pipeline)
    planning = PlanningAgent(pipeline=plan_pipeline)
    observability = ObservabilityAgent(telemetry=telemetry, tracing=tracing, metrics=metrics)
    governance = GovernanceAgent(
        permission_mgr=perms, validator=validator,
        compliance=compliance, audit=audit,
    )

    return {
        "cognition": cognition,
        "simulation": simulation,
        "planning": planning,
        "observability": observability,
        "governance": governance,
        "dashboard": dashboard,
        "state": CognitiveState(),
    }


def run_demo():
    """Exécute une démonstration complète."""
    system = build_system()

    print("=" * 60)
    print("  EXO Cognitive Framework v25.0.0 — Démonstration")
    print("=" * 60)

    # 1 — Cognition
    print("\n[1] Pipeline cognitif complet:")
    result = system["cognition"].execute({"text": "Quelle est la météo à Paris ?"})
    print(f"    Action : {result.get('action')}")
    print(f"    Confiance : {result.get('confidence')}")
    print(f"    Approuvé : {result.get('approved', result.get('supervised'))}")

    # 2 — Simulation
    print("\n[2] Pipeline de simulation:")
    sim = system["simulation"].execute({"intent": "weather_query", "plan": ["fetch", "format", "respond"]})
    print(f"    Décision : {sim.get('decision')}")
    print(f"    Scénarios : {len(sim.get('scenarios', []))}")

    # 3 — Planning
    print("\n[3] Pipeline de planification:")
    plan = system["planning"].execute({"goal": "respond"})
    print(f"    Plan : {plan.get('plan')}")
    print(f"    Validé : {plan.get('validated')}")

    # 4 — Gouvernance
    print("\n[4] Vérification de gouvernance:")
    gov = system["governance"].execute({"entity": "cognition_agent", "action": "respond"})
    print(f"    Approuvé : {gov.get('approved')}")

    # 5 — Observabilité
    print("\n[5] Observabilité:")
    system["observability"].execute({"text": "check"})
    health = system["dashboard"].health()
    print(f"    Statut : {health['status']}")
    summary = system["dashboard"].summary()
    print(f"    Événements : {summary.get('telemetry', {}).get('event_count', 0)}")

    print("\n" + "=" * 60)
    print("  Démonstration terminée — Tous les sous-systèmes opérationnels")
    print("=" * 60)


if __name__ == "__main__":
    run_demo()
