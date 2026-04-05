"""
EXO Cognitive Framework — Point d'entrée principal.

Démontre l'architecture cognitive complète v1→v26 :
  Core → Engines → Layers → Pipelines → Agents
  + Governance + Observability.
"""

import logging

logger = logging.getLogger(__name__)

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
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    system = build_system()

    logger.info("=" * 60)
    logger.info("  EXO Cognitive Framework v26.0.0 — Démonstration")
    logger.info("=" * 60)

    # 1 — Cognition
    logger.info("\n[1] Pipeline cognitif complet:")
    result = system["cognition"].execute({"text": "Quelle est la météo à Paris ?"})
    logger.info("    Action : %s", result.get('action'))
    logger.info("    Confiance : %s", result.get('confidence'))
    logger.info("    Approuvé : %s", result.get('approved', result.get('supervised')))

    # 2 — Simulation
    logger.info("\n[2] Pipeline de simulation:")
    sim = system["simulation"].execute({"intent": "weather_query", "plan": ["fetch", "format", "respond"]})
    logger.info("    Décision : %s", sim.get('decision'))
    logger.info("    Scénarios : %d", len(sim.get('scenarios', [])))

    # 3 — Planning
    logger.info("\n[3] Pipeline de planification:")
    plan = system["planning"].execute({"goal": "respond"})
    logger.info("    Plan : %s", plan.get('plan'))
    logger.info("    Validé : %s", plan.get('validated'))

    # 4 — Gouvernance
    logger.info("\n[4] Vérification de gouvernance:")
    gov = system["governance"].execute({"entity": "cognition_agent", "action": "respond"})
    logger.info("    Approuvé : %s", gov.get('approved'))

    # 5 — Observabilité
    logger.info("\n[5] Observabilité:")
    system["observability"].execute({"text": "check"})
    health = system["dashboard"].health()
    logger.info("    Statut : %s", health['status'])
    summary = system["dashboard"].summary()
    logger.info("    Événements : %d", summary.get('telemetry', {}).get('event_count', 0))

    logger.info("\n" + "=" * 60)
    logger.info("  Démonstration terminée — Tous les sous-systèmes opérationnels")
    logger.info("=" * 60)


if __name__ == "__main__":
    run_demo()
