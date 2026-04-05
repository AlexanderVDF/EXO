"""
exo_server.py — EXO backend server.

Runs:
1. Home Assistant bridge (WebSocket + REST)
2. GUI WebSocket server on ws://localhost:8765
3. BrainEngine function-calling router

This is the main entry point for the Python side of EXO.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import signal
import sys
from pathlib import Path
from typing import Any

import websockets
import websockets.server

# Add orchestrator dir to path (so 'integrations' package is importable)
sys.path.insert(0, str(Path(__file__).resolve().parent))
# Add python/ to path for shared modules
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from shared.singleton_guard import ensure_single_instance
from shared.base_service import init_v9

from integrations.home_bridge import HomeBridge
from integrations.ha_entities import EntityManager
from integrations.ha_devices import DeviceManager
from integrations.ha_areas import AreaManager
from integrations.ha_actions import ActionDispatcher, TOOL_DEFINITIONS
from integrations.ha_sync import SyncManager

# v8.2 — Ultra-Low Latency modules
from llm_warmup import LLMWarmup
from fused_pipeline import FusedPipeline, PipelineState
from tts_predictive import TTSPredictive
from context_cache import ContextCache, CacheDomain
from cpu_gpu_orchestrator import CPUGPUOrchestrator
from pipeline_profiler import PipelineProfiler
from pipeline_resilience import PipelineResilience
from pipeline_v9 import PipelineV9Integration

# v10 — Agent cognitif
from agent_manager import AgentManager

# v11 — Auto-apprentissage & auto-optimisation
from meta_memory import MetaMemory
from auto_governance import AutoGovernance
from learning_engine import LearningEngine
from feedback_engine import FeedbackEngine
from self_diagnosis_engine import SelfDiagnosisEngine
from optimization_engine import OptimizationEngine
from auto_tuning_engine import AutoTuningEngine
from meta_planner import MetaPlanner
from meta_supervisor import MetaSupervisor
from auto_explanation import AutoExplanation

# v12 — Auto-réflexion, méta-raisonnement, auto-cohérence
from self_reflection_engine import SelfReflectionEngine
from meta_reasoning_engine import MetaReasoningEngine
from meta_planner_v2 import MetaPlannerV2
from meta_verifier import MetaVerifier
from self_consistency_engine import SelfConsistencyEngine
from meta_supervisor_v2 import MetaSupervisorV2
from explainability_engine_v2 import ExplainabilityEngineV2

# v13 — Auto-simulation, prévision, planification prospective
from self_simulation_engine import SelfSimulationEngine
from prediction_engine import PredictionEngine
from future_planner import FuturePlanner
from multi_scenario_engine import MultiScenarioEngine
from temporal_coherence_engine import TemporalCoherenceEngine
from anticipation_engine import AnticipationEngine
from explainability_engine_v3 import ExplainabilityEngineV3
from meta_supervisor_v3 import MetaSupervisorV3

# v14 — Cognition distribuée, agents spécialisés
from agent_messaging_bus import AgentMessagingBus
from agent_registry import AgentRegistry
from specialized_agents import create_default_agents
from conflict_resolver import ConflictResolver
from cognitive_orchestrator import CognitiveOrchestrator
from distributed_consistency_engine import DistributedConsistencyEngine
from meta_supervisor_v4 import MetaSupervisorV4
from explainability_engine_v4 import ExplainabilityEngineV4

# v15 — Architecture cognitive complète
from expert_system_engine import ExpertSystemEngine
from knowledge_graph import KnowledgeGraph
from inference_engine import InferenceEngine
from cognitive_agent_core import CognitiveAgentCore
from meta_cognition_engine import MetaCognitionEngine
from prospective_engine import ProspectiveEngine
from distributed_cognition_layer import DistributedCognitionLayer
from global_supervisor_v5 import GlobalSupervisorV5
from explainability_engine_v5 import ExplainabilityEngineV5

# v16 — Agents autonomes supervisés, émergence cognitive, auto-régulation
from cognitive_audit_log import CognitiveAuditLog
from initiative_protocol import InitiativeProtocol
from cognitive_governor import CognitiveGovernor
from autonomous_agent_layer import AutonomousAgentLayer
from emergent_collaboration_bus import EmergentCollaborationBus
from emergent_reasoning_engine import EmergentReasoningEngine
from self_regulation_engine import SelfRegulationEngine
from explainability_engine_v6 import ExplainabilityEngineV6

# v17 — Architecture neuro-symbolique
from reasoning_bridge import ReasoningBridge
from hybrid_inference_engine import HybridInferenceEngine
from knowledge_grounded_llm import KnowledgeGroundedLLM
from neurosymbolic_coherence_engine import NeuroSymbolicCoherenceEngine
from symbolic_validator import SymbolicValidator
from semantic_extractor import SemanticExtractor
from knowledge_augmentor import KnowledgeAugmentor
from neurosymbolic_explainability_engine import NeuroSymbolicExplainabilityEngine

# v18 — Cognition hiérarchique multi-niveaux
from macro_agent_layer import MacroAgentLayer
from micro_agent_layer import MicroAgentLayer
from cognitive_layer_stack import CognitiveLayerStack
from vertical_reasoning_flow import VerticalReasoningFlow
from hierarchical_supervisor import HierarchicalSupervisor
from priority_engine import PriorityEngine
from layered_consistency_engine import LayeredConsistencyEngine
from layered_explainability_engine import LayeredExplainabilityEngine

# v19 — Optimisation cognitive
from meta_optimizer import MetaOptimizer
from adaptive_heuristics_engine import AdaptiveHeuristicsEngine
from cognitive_pipeline_optimizer import CognitivePipelineOptimizer
from cognitive_load_reducer import CognitiveLoadReducer
from multi_objective_optimizer import MultiObjectiveOptimizer
from cognitive_profiling_engine import CognitiveProfilingEngine
from plan_optimizer import PlanOptimizer
from simulation_optimizer import SimulationOptimizer
from inference_optimizer import InferenceOptimizer
from optimization_explainability_engine import OptimizationExplainabilityEngine

# v20 — Architecture modulaire ultra-scalable
from modular_cognitive_unit import ModularCognitiveUnit
from plug_and_play_agent_system import PlugAndPlayAgentSystem
from distributed_orchestrator import DistributedOrchestrator
from scalable_cognitive_fabric import ScalableCognitiveFabric
from cognitive_partitioning_engine import CognitivePartitioningEngine
from module_lifecycle_manager import ModuleLifecycleManager
from hot_swap_engine import HotSwapEngine
from module_compatibility_checker import ModuleCompatibilityChecker
from modular_explainability_engine import ModularExplainabilityEngine

# v21 — Système expert étendu
from advanced_rule_engine import AdvancedRuleEngine
from causal_graph_engine import CausalGraphEngine
from deductive_reasoner import DeductiveReasoner
from inductive_reasoner import InductiveReasoner
from abductive_reasoner import AbductiveReasoner
from constraint_solver import ConstraintSolver
from logical_coherence_engine import LogicalCoherenceEngine
from knowledge_graph_v2 import KnowledgeGraphV2
from symbolic_explainability_v2 import SymbolicExplainabilityEngineV2

# v22 — Planification stratégique
from strategic_planner import StrategicPlanner
from htn_plus_engine import HTNPlusEngine
from multi_objective_planner import MultiObjectivePlanner
from constraint_aware_planner import ConstraintAwarePlanner
from scenario_planner import ScenarioPlanner
from strategic_arbitration_engine import StrategicArbitrationEngine
from temporal_planning_engine import TemporalPlanningEngine
from plan_coherence_engine import PlanCoherenceEngine
from planning_explainability_engine import PlanningExplainabilityEngine
from context_simulation_sandbox import ContextSimulationSandbox
from multi_scenario_simulation_engine import MultiScenarioSimulationEngine
from predictive_modeling_engine import PredictiveModelingEngine
from outcome_analysis_engine import OutcomeAnalysisEngine
from temporal_simulation_engine import TemporalSimulationEngine
from simulation_coherence_engine import SimulationCoherenceEngine
from simulation_governance_engine import SimulationGovernanceEngine
from simulation_explainability_engine import SimulationExplainabilityEngine

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("exo.server")

# ---------------------------------------------------------------------------
# Load .env
# ---------------------------------------------------------------------------

def _load_env() -> None:
    env_path = Path(__file__).resolve().parent.parent.parent / ".env"
    if env_path.exists():
        for line in env_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, _, val = line.partition("=")
                os.environ.setdefault(key.strip(), val.strip())


# ---------------------------------------------------------------------------
# GUI WebSocket server
# ---------------------------------------------------------------------------

class GUIServer:
    """WebSocket server that the React GUI connects to (ws://localhost:8765)."""

    def __init__(self, sync: SyncManager, pipeline_mgr: "PipelineManager",
                 agent_mgr: AgentManager | None = None,
                 v11: dict | None = None,
                 v12: dict | None = None,
                 v13: dict | None = None,
                 v14: dict | None = None,
                 v15: dict | None = None,
                 v16: dict | None = None,
                 v17: dict | None = None,
                 v18: dict | None = None,
                 v19: dict | None = None,
                 v20: dict | None = None,
                 v21: dict | None = None,
                 v22: dict | None = None,
                 v23: dict | None = None) -> None:
        self._sync = sync
        self._pipeline = pipeline_mgr
        self._agent = agent_mgr
        self._v11 = v11 or {}
        self._v12 = v12 or {}
        self._v13 = v13 or {}
        self._v14 = v14 or {}
        self._v15 = v15 or {}
        self._v16 = v16 or {}
        self._v17 = v17 or {}
        self._v18 = v18 or {}
        self._v19 = v19 or {}
        self._v20 = v20 or {}
        self._v21 = v21 or {}
        self._v22 = v22 or {}
        self._v23 = v23 or {}
        self._clients: set[websockets.server.WebSocketServerProtocol] = set()
        self._state = "IDLE"
        self._volume = 0.0
        self._text = ""

    async def handler(self, ws: websockets.server.WebSocketServerProtocol) -> None:
        self._clients.add(ws)
        logger.info("GUI client connected (%d total)", len(self._clients))
        try:
            # ReadinessProtocol v5 — envoyer ready avant le snapshot
            await ws.send(json.dumps({"type": "ready", "service": "orchestrator"}))

            # Send initial snapshot
            snapshot = self._sync.build_full_snapshot()
            snapshot["state"] = self._state
            snapshot["volume"] = self._volume
            snapshot["text"] = self._text
            await ws.send(json.dumps(snapshot))

            async for raw in ws:
                await self._handle_client_message(ws, raw)
        finally:
            self._clients.discard(ws)
            logger.info("GUI client disconnected (%d remaining)", len(self._clients))

    async def _handle_client_message(self, ws: Any, raw: str) -> None:
        try:
            msg = json.loads(raw)
        except json.JSONDecodeError:
            return

        msg_type = msg.get("type")

        if msg_type == "ping":
            await ws.send(json.dumps({"type": "pong"}))

        elif msg_type == "plan_move":
            await self._sync.on_plan_move(
                device_id=msg.get("device_id", ""),
                x=msg.get("x", 0),
                y=msg.get("y", 0),
                room=msg.get("room", ""),
            )

        elif msg_type == "settings_update":
            logger.info("Settings update: %s = %s", msg.get("key"), msg.get("value"))

        elif msg_type == "network_scan":
            hosts = msg.get("hosts", [])
            await self._sync.sync_network_devices(hosts)

        elif msg_type == "transcript":
            text = msg.get("text", "")
            timestamp = msg.get("timestamp", 0)
            req_id = msg.get("req_id", "")
            logger.info("[req_id=%s] Voice transcript: %s (ts=%s)", req_id, text, timestamp)
            await self.broadcast({"type": "transcript", "text": text, "req_id": req_id})

        elif msg_type == "partial_transcript":
            text = msg.get("text", "")
            await self.broadcast({"type": "partial_transcript", "text": text})

        elif msg_type == "pipeline_state":
            state = msg.get("state", "idle")
            logger.info("Pipeline state: %s", state)
            await self.push_state(state)

        elif msg_type == "audio_level":
            rms = msg.get("rms", 0.0)
            vad = msg.get("vad_score", 0.0)
            is_speech = msg.get("is_speech", False)
            await self.broadcast({
                "type": "audio_level",
                "rms": rms,
                "vad_score": vad,
                "is_speech": is_speech,
            })

        elif msg_type == "pipeline_metrics":
            metrics = self._pipeline.metrics()
            await ws.send(json.dumps({"type": "pipeline_metrics", **metrics}))

        # v10 — Agent actions
        elif msg_type == "agent_process":
            if self._agent:
                text = msg.get("text", "")
                result = await self._agent.process_intent(text)
                await ws.send(json.dumps({"type": "agent_result", **result}))

        elif msg_type == "agent_health":
            if self._agent:
                health = await self._agent.health_check()
                await ws.send(json.dumps({"type": "agent_health", **health}))

        elif msg_type == "agent_state":
            if self._agent:
                state = self._agent.get_state()
                await ws.send(json.dumps({"type": "agent_state", **state}))

        elif msg_type == "agent_metrics":
            if self._agent:
                metrics = self._agent.get_metrics()
                await ws.send(json.dumps({"type": "agent_metrics", **metrics}))

        # ── v11 — Auto-apprentissage & auto-optimisation ─────
        elif msg_type == "v11_learn":
            eng = self._v11.get("learning")
            if eng:
                entry_id = eng.learn(msg.get("event", {}))
                await ws.send(json.dumps({"type": "v11_learn_result",
                                          "entry_id": entry_id}))

        elif msg_type == "v11_feedback":
            eng = self._v11.get("feedback")
            if eng:
                fb_type = msg.get("feedback_type", "positive")
                event = msg.get("event", {})
                method = getattr(eng, f"feedback_{fb_type}", None)
                if method:
                    method(event)
                await ws.send(json.dumps({"type": "v11_feedback_ack",
                                          "feedback_type": fb_type}))

        elif msg_type == "v11_optimize":
            eng = self._v11.get("optimization")
            if eng:
                result = eng.optimize_all()
                await ws.send(json.dumps({"type": "v11_optimize_result",
                                          **result}))

        elif msg_type == "v11_diagnose":
            eng = self._v11.get("diagnosis")
            if eng:
                report = eng.diagnose()
                await ws.send(json.dumps({"type": "v11_diagnose_result",
                                          **report}))

        elif msg_type == "v11_tune":
            eng = self._v11.get("tuning")
            if eng:
                param = msg.get("parameter", "")
                value = msg.get("value", 0)
                ok = eng.tune(param, float(value))
                await ws.send(json.dumps({"type": "v11_tune_result",
                                          "parameter": param, "applied": ok}))

        elif msg_type == "v11_auto_tune":
            eng = self._v11.get("tuning")
            if eng:
                result = eng.auto_tune_all()
                await ws.send(json.dumps({"type": "v11_auto_tune_result",
                                          **result}))

        elif msg_type == "v11_explain":
            eng = self._v11.get("explanation")
            if eng:
                kind = msg.get("kind", "decision")
                if kind == "decision":
                    text = eng.explain_decision(msg.get("action", ""),
                                                msg.get("context"))
                elif kind == "learning":
                    text = eng.explain_learning(msg.get("entry_id", ""))
                elif kind == "tuning":
                    text = eng.explain_tuning(msg.get("parameter", ""))
                elif kind == "diagnosis":
                    text = eng.explain_diagnosis(msg.get("report", {}))
                elif kind == "optimization":
                    text = eng.explain_optimization(msg.get("record", {}))
                else:
                    text = ""
                await ws.send(json.dumps({"type": "v11_explain_result",
                                          "explanation": text}))

        elif msg_type == "v11_stats":
            stats = {}
            for name, mod in self._v11.items():
                if hasattr(mod, "get_stats"):
                    stats[name] = mod.get_stats()
            await ws.send(json.dumps({"type": "v11_stats", **stats}))

        elif msg_type == "v11_governance":
            eng = self._v11.get("governance")
            if eng:
                sub = msg.get("sub", "rules")
                if sub == "rules":
                    await ws.send(json.dumps({"type": "v11_governance_result",
                                              "rules": eng.get_rules()}))
                elif sub == "set_rules":
                    eng.set_rules(msg.get("rules", {}))
                    await ws.send(json.dumps({"type": "v11_governance_ack"}))
                elif sub == "set_limits":
                    eng.set_limits(msg.get("limits", {}))
                    await ws.send(json.dumps({"type": "v11_governance_ack"}))
                elif sub == "set_permissions":
                    eng.set_permissions(msg.get("permissions", {}))
                    await ws.send(json.dumps({"type": "v11_governance_ack"}))
                elif sub == "audit":
                    log = eng.get_audit_log(msg.get("limit", 50))
                    await ws.send(json.dumps({"type": "v11_governance_audit",
                                              "audit": log}))

        elif msg_type == "v11_supervisor":
            eng = self._v11.get("supervisor")
            if eng:
                sub = msg.get("sub", "drift")
                if sub == "drift":
                    report = eng.get_drift_report()
                    await ws.send(json.dumps({"type": "v11_supervisor_drift",
                                              **report}))
                elif sub == "enforce":
                    result = eng.enforce_rules()
                    await ws.send(json.dumps({"type": "v11_supervisor_enforce",
                                              **result}))
                elif sub == "rollback":
                    entry_id = msg.get("entry_id", "")
                    ok = eng.rollback_learning(entry_id)
                    await ws.send(json.dumps({"type": "v11_supervisor_rollback",
                                              "entry_id": entry_id,
                                              "success": ok}))

        elif msg_type == "v11_memory":
            mem = self._v11.get("meta_memory")
            if mem:
                sub = msg.get("sub", "stats")
                if sub == "stats":
                    await ws.send(json.dumps({"type": "v11_memory_stats",
                                              **mem.get_stats()}))
                elif sub == "search":
                    results = mem.meta_get(msg.get("query", ""))
                    await ws.send(json.dumps({"type": "v11_memory_results",
                                              "results": results}))
                elif sub == "list":
                    entries = mem.list_entries(
                        msg.get("category"), msg.get("limit", 50))
                    await ws.send(json.dumps({"type": "v11_memory_list",
                                              "entries": entries}))

        # ── v12 — Auto-réflexion, méta-raisonnement, auto-cohérence ──
        elif msg_type == "v12_reflect":
            eng = self._v12.get("reflection")
            if eng:
                sub = msg.get("sub", "reasoning")
                if sub == "reasoning":
                    result = eng.reflect_on_reasoning(msg.get("trace", {}))
                elif sub == "plan":
                    result = eng.reflect_on_plan(msg.get("plan", {}))
                elif sub == "decision":
                    result = eng.reflect_on_decision(msg.get("decision", {}))
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v12_reflect_result",
                                          **result}))

        elif msg_type == "v12_meta_reason":
            eng = self._v12.get("reasoning")
            if eng:
                sub = msg.get("sub", "full")
                trace = msg.get("trace", {})
                if sub == "full":
                    result = eng.meta_reason(trace)
                elif sub == "quality":
                    result = eng.evaluate_reasoning_quality(trace)
                elif sub == "improve":
                    result = eng.propose_reasoning_improvements(trace)
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v12_meta_reason_result",
                                          **result}))

        elif msg_type == "v12_evaluate_plan":
            eng = self._v12.get("planner_v2")
            if eng:
                sub = msg.get("sub", "evaluate")
                if sub == "evaluate":
                    result = eng.evaluate_plan(msg.get("plan", {}))
                elif sub == "compare":
                    result = eng.compare_plans(msg.get("plans", []))
                elif sub == "improve":
                    result = eng.improve_plan(msg.get("plan", {}))
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v12_evaluate_plan_result",
                                          **result}))

        elif msg_type == "v12_verify":
            eng = self._v12.get("verifier")
            if eng:
                sub = msg.get("sub", "plan")
                if sub == "plan":
                    result = eng.meta_verify(msg.get("plan", {}))
                elif sub == "reasoning":
                    result = eng.meta_verify_reasoning(msg.get("trace", {}))
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v12_verify_result",
                                          **result}))

        elif msg_type == "v12_consistency":
            eng = self._v12.get("consistency")
            if eng:
                sub = msg.get("sub", "plan")
                if sub == "plan":
                    result = eng.check_consistency(msg.get("plan", {}))
                elif sub == "reasoning":
                    result = eng.check_consistency_reasoning(msg.get("trace", {}))
                elif sub == "enforce":
                    result = eng.enforce_consistency()
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v12_consistency_result",
                                          **result}))

        elif msg_type == "v12_supervise":
            eng = self._v12.get("supervisor_v2")
            if eng:
                sub = msg.get("sub", "reasoning")
                if sub == "reasoning":
                    result = eng.supervise_reasoning(msg.get("trace", {}))
                elif sub == "planning":
                    result = eng.supervise_planning(msg.get("plan", {}))
                elif sub == "enforce":
                    result = eng.enforce_meta_rules()
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v12_supervise_result",
                                          **result}))

        elif msg_type == "v12_explain":
            eng = self._v12.get("explainability_v2")
            if eng:
                kind = msg.get("kind", "plan")
                if kind == "plan":
                    text = eng.explain_plan(msg.get("plan", {}))
                elif kind == "reasoning":
                    text = eng.explain_reasoning(msg.get("trace", {}))
                elif kind == "meta_decision":
                    text = eng.explain_meta_decision(msg.get("decision", {}))
                else:
                    text = ""
                await ws.send(json.dumps({"type": "v12_explain_result",
                                          "explanation": text}))

        elif msg_type == "v12_stats":
            stats = {}
            for name, mod in self._v12.items():
                if hasattr(mod, "get_stats"):
                    stats[name] = mod.get_stats()
            await ws.send(json.dumps({"type": "v12_stats", **stats}))

        # ── v13 — Auto-simulation, prévision, planification prospective ──
        elif msg_type == "v13_simulate":
            eng = self._v13.get("simulation")
            if eng:
                sub = msg.get("sub", "plan")
                if sub == "plan":
                    result = eng.simulate_plan(msg.get("plan", {}))
                elif sub == "step":
                    result = eng.simulate_step(msg.get("step", {}))
                elif sub == "scenario":
                    result = eng.simulate_scenario(msg.get("scenario", {}))
                elif sub == "outcome":
                    result = eng.simulate_outcome(msg.get("plan", {}))
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v13_simulate_result",
                                          **result}))

        elif msg_type == "v13_predict":
            eng = self._v13.get("prediction")
            if eng:
                sub = msg.get("sub", "user_need")
                if sub == "user_need":
                    result = eng.predict_user_need()
                elif sub == "domotic":
                    result = eng.predict_domotic_state()
                elif sub == "network":
                    result = eng.predict_network_state()
                elif sub == "routine":
                    result = eng.predict_routine()
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v13_predict_result",
                                          **result}))

        elif msg_type == "v13_future_plan":
            eng = self._v13.get("future_planner")
            if eng:
                sub = msg.get("sub", "future")
                if sub == "future":
                    result = eng.plan_future_action(
                        msg.get("action", {}), msg.get("time_target", 0))
                elif sub == "conditional":
                    result = eng.plan_conditional_action(
                        msg.get("action", {}), msg.get("condition", {}))
                elif sub == "recurrent":
                    result = eng.plan_recurrent_action(
                        msg.get("action", {}), msg.get("schedule", {}))
                elif sub == "pending":
                    result = {"plans": eng.get_pending_plans()}
                elif sub == "cancel":
                    ok = eng.cancel_plan(msg.get("plan_id", ""))
                    result = {"cancelled": ok}
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v13_future_plan_result",
                                          **result}))

        elif msg_type == "v13_scenarios":
            eng = self._v13.get("multi_scenario")
            if eng:
                sub = msg.get("sub", "generate")
                if sub == "generate":
                    result = eng.generate_future_variants(msg.get("plan", {}))
                elif sub == "compare":
                    result = eng.compare_futures(msg.get("futures", []))
                elif sub == "select":
                    result = eng.select_best_future(msg.get("futures", []))
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v13_scenarios_result",
                                          **result}))

        elif msg_type == "v13_temporal":
            eng = self._v13.get("temporal")
            if eng:
                sub = msg.get("sub", "check")
                if sub == "check":
                    result = eng.check_temporal_conflicts(msg.get("plans", []))
                elif sub == "enforce":
                    result = eng.enforce_temporal_coherence()
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v13_temporal_result",
                                          **result}))

        elif msg_type == "v13_anticipate":
            eng = self._v13.get("anticipation")
            if eng:
                sub = msg.get("sub", "need")
                if sub == "need":
                    result = eng.anticipate_need()
                elif sub == "propose":
                    result = eng.propose_anticipation()
                elif sub == "context":
                    result = eng.prepare_future_context()
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v13_anticipate_result",
                                          **result}))

        elif msg_type == "v13_explain":
            eng = self._v13.get("explainability_v3")
            if eng:
                kind = msg.get("kind", "simulation")
                if kind == "simulation":
                    text = eng.explain_simulation(msg.get("simulation", {}))
                elif kind == "prediction":
                    text = eng.explain_prediction(msg.get("prediction", {}))
                elif kind == "future":
                    text = eng.explain_future(msg.get("future", {}))
                else:
                    text = ""
                await ws.send(json.dumps({"type": "v13_explain_result",
                                          "explanation": text}))

        elif msg_type == "v13_supervise":
            eng = self._v13.get("supervisor_v3")
            if eng:
                sub = msg.get("sub", "simulation")
                if sub == "simulation":
                    result = eng.supervise_simulation(msg.get("simulation", {}))
                elif sub == "prediction":
                    result = eng.supervise_prediction(msg.get("prediction", {}))
                elif sub == "enforce":
                    result = eng.enforce_future_rules()
                elif sub == "alerts":
                    result = {"alerts": eng.get_alerts(msg.get("limit", 20))}
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v13_supervise_result",
                                          **result}))

        elif msg_type == "v13_stats":
            stats = {}
            for name, mod in self._v13.items():
                if hasattr(mod, "get_stats"):
                    stats[name] = mod.get_stats()
            await ws.send(json.dumps({"type": "v13_stats", **stats}))

        # ── v14 — Cognition distribuée, agents spécialisés ───────
        elif msg_type == "v14_orchestrate":
            eng = self._v14.get("orchestrator")
            if eng:
                result = eng.orchestrate(msg.get("intent", {}))
                await ws.send(json.dumps({"type": "v14_orchestrate_result",
                                          **result}))

        elif msg_type == "v14_agents":
            eng = self._v14.get("registry")
            if eng:
                sub = msg.get("sub", "list")
                if sub == "list":
                    result = {"agents": eng.list_agents()}
                elif sub == "info":
                    result = eng.get_agent_info(msg.get("name", ""))
                elif sub == "dispatch":
                    orch = self._v14.get("orchestrator")
                    if orch:
                        result = orch.dispatch(
                            msg.get("task", {}), msg.get("agent", ""))
                    else:
                        result = {}
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v14_agents_result",
                                          **result}))

        elif msg_type == "v14_messaging":
            eng = self._v14.get("messaging_bus")
            if eng:
                sub = msg.get("sub", "log")
                if sub == "send":
                    result = eng.send(
                        msg.get("sender", ""), msg.get("recipient", ""),
                        msg.get("message", {}))
                elif sub == "broadcast":
                    results = eng.broadcast(
                        msg.get("sender", ""), msg.get("message", {}))
                    result = {"delivered": results}
                elif sub == "log":
                    result = {"log": eng.get_message_log(
                        msg.get("limit", 50))}
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v14_messaging_result",
                                          **result}))

        elif msg_type == "v14_conflicts":
            eng = self._v14.get("conflict_resolver")
            if eng:
                sub = msg.get("sub", "detect")
                if sub == "detect":
                    result = eng.detect_conflicts(
                        msg.get("agent_outputs", []))
                elif sub == "resolve":
                    result = eng.resolve(msg.get("agent_outputs", []))
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v14_conflicts_result",
                                          **result}))

        elif msg_type == "v14_consistency":
            eng = self._v14.get("consistency")
            if eng:
                sub = msg.get("sub", "check")
                if sub == "check":
                    result = eng.check_global_consistency()
                elif sub == "enforce":
                    result = eng.enforce_global_consistency()
                elif sub == "agent":
                    result = eng.check_agent_consistency(
                        msg.get("name", ""))
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v14_consistency_result",
                                          **result}))

        elif msg_type == "v14_supervise":
            eng = self._v14.get("supervisor_v4")
            if eng:
                sub = msg.get("sub", "agent")
                if sub == "agent":
                    result = eng.supervise_agent(msg.get("name", ""))
                elif sub == "interaction":
                    result = eng.supervise_interaction(
                        msg.get("message", {}))
                elif sub == "decision":
                    result = eng.supervise_decision(
                        msg.get("decision", {}))
                elif sub == "enforce":
                    result = eng.enforce_meta_rules()
                elif sub == "alerts":
                    result = {"alerts": eng.get_alerts(
                        msg.get("limit", 20))}
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v14_supervise_result",
                                          **result}))

        elif msg_type == "v14_explain":
            eng = self._v14.get("explainability_v4")
            if eng:
                kind = msg.get("kind", "agent")
                if kind == "agent":
                    result = eng.explain_agent_decision(
                        msg.get("name", ""))
                elif kind == "global":
                    result = eng.explain_global_decision(
                        msg.get("decision", {}))
                elif kind == "conflict":
                    result = eng.explain_conflict_resolution(
                        msg.get("resolution", {}))
                elif kind == "orchestration":
                    result = eng.explain_orchestration(
                        msg.get("orch_result", {}))
                else:
                    result = {}
                await ws.send(json.dumps({"type": "v14_explain_result",
                                          **result}))

        elif msg_type == "v14_stats":
            stats = {}
            for name, mod in self._v14.items():
                if hasattr(mod, "get_stats"):
                    stats[name] = mod.get_stats()
            await ws.send(json.dumps({"type": "v14_stats", **stats}))

        # ── v15 — Architecture cognitive complète ─────────────
        elif msg_type == "v15_expert_infer":
            eng = self._v15.get("expert_system")
            if eng:
                result = eng.infer(msg.get("query", {}))
                await ws.send(json.dumps({"type": "v15_expert_result", **result}))

        elif msg_type == "v15_expert_add_rule":
            eng = self._v15.get("expert_system")
            if eng:
                rule_id = eng.add_rule(msg.get("rule", {}))
                await ws.send(json.dumps({"type": "v15_rule_added", "rule_id": rule_id}))

        elif msg_type == "v15_kg_add":
            kg = self._v15.get("knowledge_graph")
            if kg:
                eid = kg.kg_add(msg.get("node", ""), msg.get("relation", ""),
                                msg.get("target", ""))
                await ws.send(json.dumps({"type": "v15_kg_added", "edge_id": eid}))

        elif msg_type == "v15_kg_query":
            kg = self._v15.get("knowledge_graph")
            if kg:
                results = kg.kg_query(msg.get("pattern", {}))
                await ws.send(json.dumps({"type": "v15_kg_results",
                                          "results": results}))

        elif msg_type == "v15_infer":
            eng = self._v15.get("inference")
            if eng:
                mode = msg.get("mode", "logical")
                if mode == "causal":
                    r = eng.infer_causal(msg.get("chain", []))
                elif mode == "temporal":
                    r = eng.infer_temporal(msg.get("sequence", []))
                elif mode == "contextual":
                    r = eng.infer_contextual(msg.get("context", {}))
                else:
                    r = eng.infer_logical(msg.get("query", {}))
                await ws.send(json.dumps({"type": "v15_inference_result", **r}))

        elif msg_type == "v15_plan":
            cog = self._v15.get("cognitive_agent")
            if cog:
                plan = cog.plan(msg.get("intent", {}))
                await ws.send(json.dumps({"type": "v15_plan_result", **plan}))

        elif msg_type == "v15_execute":
            cog = self._v15.get("cognitive_agent")
            if cog:
                result = cog.execute(msg.get("plan", {}))
                await ws.send(json.dumps({"type": "v15_exec_result", **result}))

        elif msg_type == "v15_reflect":
            mc = self._v15.get("meta_cognition")
            if mc:
                result = mc.reflect(msg.get("trace", {}))
                await ws.send(json.dumps({"type": "v15_reflect_result", **result}))

        elif msg_type == "v15_simulate":
            pe = self._v15.get("prospective")
            if pe:
                result = pe.simulate(msg.get("plan", {}))
                await ws.send(json.dumps({"type": "v15_simulate_result", **result}))

        elif msg_type == "v15_futures":
            pe = self._v15.get("prospective")
            if pe:
                result = pe.generate_futures(msg.get("plan", {}),
                                             msg.get("n", 3))
                await ws.send(json.dumps({"type": "v15_futures_result", **result}))

        elif msg_type == "v15_supervise":
            sup = self._v15.get("supervisor_v5")
            if sup:
                result = sup.supervise_all()
                await ws.send(json.dumps({"type": "v15_supervise_result", **result}))

        elif msg_type == "v15_validate":
            sup = self._v15.get("supervisor_v5")
            if sup:
                result = sup.validate_decision(msg.get("decision", {}))
                await ws.send(json.dumps({"type": "v15_validate_result", **result}))

        elif msg_type == "v15_explain":
            exp = self._v15.get("explainability_v5")
            if exp:
                mode = msg.get("mode", "decision")
                if mode == "inference":
                    r = exp.explain_inference(msg.get("inference", {}))
                elif mode == "future":
                    r = exp.explain_future(msg.get("future", {}))
                elif mode == "conflict":
                    r = exp.explain_conflict(msg.get("conflict", {}))
                elif mode == "full":
                    r = exp.explain_full(msg.get("session", {}))
                else:
                    r = exp.explain_decision(msg.get("decision", {}))
                await ws.send(json.dumps({"type": "v15_explain_result", **r}))

        elif msg_type == "v15_dispatch":
            dc = self._v15.get("distributed")
            if dc:
                result = dc.dispatch(msg.get("task", {}))
                await ws.send(json.dumps({"type": "v15_dispatch_result", **result}))

        elif msg_type == "v15_stats":
            stats = {}
            for name, mod in self._v15.items():
                if hasattr(mod, "get_stats"):
                    stats[name] = mod.get_stats()
            await ws.send(json.dumps({"type": "v15_stats", **stats}))

        # ── v16 — Agents autonomes supervisés, émergence ──────
        elif msg_type == "v16_propose_initiative":
            layer = self._v16.get("autonomous_layer")
            if layer:
                result = layer.propose_initiative(
                    msg.get("agent", ""), msg.get("action", ""),
                    msg.get("context", {}))
                await ws.send(json.dumps({"type": "v16_initiative_proposed",
                                          **result}))

        elif msg_type == "v16_validate_initiative":
            layer = self._v16.get("autonomous_layer")
            if layer:
                result = layer.validate_initiative(msg.get("initiative_id", ""))
                await ws.send(json.dumps({"type": "v16_initiative_validated",
                                          **result}))

        elif msg_type == "v16_execute_initiative":
            layer = self._v16.get("autonomous_layer")
            if layer:
                result = layer.execute_initiative(msg.get("initiative_id", ""))
                await ws.send(json.dumps({"type": "v16_initiative_executed",
                                          **result}))

        elif msg_type == "v16_rollback_initiative":
            layer = self._v16.get("autonomous_layer")
            if layer:
                result = layer.rollback_initiative(msg.get("initiative_id", ""))
                await ws.send(json.dumps({"type": "v16_initiative_rollback",
                                          **result}))

        elif msg_type == "v16_collaborate":
            bus = self._v16.get("collaboration_bus")
            if bus:
                result = bus.collaborate(
                    msg.get("initiator", ""), msg.get("participants", []),
                    msg.get("goal", ""))
                await ws.send(json.dumps({"type": "v16_collab_started",
                                          **result}))

        elif msg_type == "v16_share_observation":
            bus = self._v16.get("collaboration_bus")
            if bus:
                result = bus.share_observation(
                    msg.get("agent", ""), msg.get("observation", {}))
                await ws.send(json.dumps({"type": "v16_observation_shared",
                                          **result}))

        elif msg_type == "v16_emergent_solve":
            eng = self._v16.get("emergent_reasoning")
            if eng:
                result = eng.generate_emergent_solution(msg.get("context", {}))
                await ws.send(json.dumps({"type": "v16_emergent_solution",
                                          **result}))

        elif msg_type == "v16_detect_emergence":
            eng = self._v16.get("emergent_reasoning")
            if eng:
                result = eng.detect_emergence(msg.get("observations", []))
                await ws.send(json.dumps({"type": "v16_emergence_detected",
                                          **result}))

        elif msg_type == "v16_regulate":
            reg = self._v16.get("self_regulation")
            if reg:
                result = reg.regulate_all(msg.get("system_state", {}))
                await ws.send(json.dumps({"type": "v16_regulation_result",
                                          **result}))

        elif msg_type == "v16_supervise":
            gov = self._v16.get("governor")
            if gov:
                result = gov.supervise_initiative(msg.get("initiative", {}))
                await ws.send(json.dumps({"type": "v16_supervise_result",
                                          **result}))

        elif msg_type == "v16_explain":
            exp = self._v16.get("explainability_v6")
            if exp:
                mode = msg.get("mode", "initiative")
                if mode == "emergence":
                    r = exp.explain_emergence(msg.get("emergence", {}))
                elif mode == "governor":
                    r = exp.explain_governor_decision(msg.get("decision", {}))
                elif mode == "regulation":
                    r = exp.explain_regulation(msg.get("regulation", {}))
                elif mode == "collaboration":
                    r = exp.explain_collaboration(msg.get("collab", {}))
                elif mode == "full":
                    r = exp.explain_full_v16(msg.get("session", {}))
                else:
                    r = exp.explain_initiative(msg.get("initiative", {}))
                await ws.send(json.dumps({"type": "v16_explain_result", **r}))

        elif msg_type == "v16_audit_trail":
            audit = self._v16.get("audit_log")
            if audit:
                result = audit.get_audit_trail(
                    msg.get("limit", 50), msg.get("filters", {}))
                await ws.send(json.dumps({"type": "v16_audit_trail",
                                          "entries": result}))

        elif msg_type == "v16_stats":
            stats = {}
            for name, mod in self._v16.items():
                if hasattr(mod, "get_stats"):
                    stats[name] = mod.get_stats()
            await ws.send(json.dumps({"type": "v16_stats", **stats}))

        # ── v17 — Architecture neuro-symbolique ──────────────
        elif msg_type == "v17_hybrid_infer":
            eng = self._v17.get("hybrid_inference")
            if eng:
                result = eng.infer_hybrid(msg.get("query", ""))
                await ws.send(json.dumps({"type": "v17_hybrid_result",
                                          **result}))

        elif msg_type == "v17_ground_prompt":
            grounded = self._v17.get("knowledge_grounded_llm")
            if grounded:
                result = grounded.ground_prompt(
                    msg.get("prompt", ""), msg.get("knowledge", {}))
                await ws.send(json.dumps({"type": "v17_ground_result",
                                          **result}))

        elif msg_type == "v17_ground_output":
            grounded = self._v17.get("knowledge_grounded_llm")
            if grounded:
                result = grounded.ground_llm_output(msg.get("output", ""))
                await ws.send(json.dumps({"type": "v17_ground_output_result",
                                          **result}))

        elif msg_type == "v17_validate_output":
            val = self._v17.get("symbolic_validator")
            if val:
                result = val.validate_llm_output(msg.get("output", ""))
                await ws.send(json.dumps({"type": "v17_validate_result",
                                          **result}))

        elif msg_type == "v17_correct_output":
            val = self._v17.get("symbolic_validator")
            if val:
                result = val.correct_llm_output(msg.get("output", ""))
                await ws.send(json.dumps({"type": "v17_correct_result",
                                          **result}))

        elif msg_type == "v17_extract_entities":
            ext = self._v17.get("semantic_extractor")
            if ext:
                result = ext.extract_entities(msg.get("text", ""))
                await ws.send(json.dumps({"type": "v17_entities_result",
                                          **result}))

        elif msg_type == "v17_extract_relations":
            ext = self._v17.get("semantic_extractor")
            if ext:
                result = ext.extract_relations(msg.get("text", ""))
                await ws.send(json.dumps({"type": "v17_relations_result",
                                          **result}))

        elif msg_type == "v17_augment_kg":
            aug = self._v17.get("knowledge_augmentor")
            if aug:
                result = aug.augment_kg(msg.get("facts", []))
                await ws.send(json.dumps({"type": "v17_augment_result",
                                          **result}))

        elif msg_type == "v17_coherence_check":
            coh = self._v17.get("coherence_engine")
            if coh:
                result = coh.check_neuro_symbolic_consistency()
                await ws.send(json.dumps({"type": "v17_coherence_result",
                                          **result}))

        elif msg_type == "v17_explain":
            exp = self._v17.get("neurosymbolic_explainability")
            if exp:
                mode = msg.get("mode", "hybrid")
                if mode == "symbolic":
                    r = exp.explain_symbolic_part(msg.get("decision", {}))
                elif mode == "neural":
                    r = exp.explain_neural_part(msg.get("decision", {}))
                elif mode == "full":
                    r = exp.explain_full_v17(msg.get("session", {}))
                else:
                    r = exp.explain_hybrid_decision(msg.get("decision", {}))
                await ws.send(json.dumps({"type": "v17_explain_result", **r}))

        elif msg_type == "v17_stats":
            stats = {}
            for name, mod in self._v17.items():
                if hasattr(mod, "get_stats"):
                    stats[name] = mod.get_stats()
            await ws.send(json.dumps({"type": "v17_stats", **stats}))

        # ── v18 — Cognition hiérarchique multi-niveaux ───────
        elif msg_type == "v18_macro_handle":
            eng = self._v18.get("macro_layer")
            if eng:
                result = eng.macro_handle(msg.get("intent", {}))
                await ws.send(json.dumps({"type": "v18_macro_result", **result}))

        elif msg_type == "v18_macro_delegate":
            eng = self._v18.get("macro_layer")
            if eng:
                result = eng.macro_delegate(msg.get("task", {}))
                await ws.send(json.dumps({"type": "v18_delegate_result", **result}))

        elif msg_type == "v18_micro_execute":
            eng = self._v18.get("micro_layer")
            if eng:
                result = eng.micro_execute(msg.get("task", {}))
                await ws.send(json.dumps({"type": "v18_micro_result", **result}))

        elif msg_type == "v18_micro_report":
            eng = self._v18.get("micro_layer")
            if eng:
                result = eng.micro_report()
                await ws.send(json.dumps({"type": "v18_micro_report_result", **result}))

        elif msg_type == "v18_push_layer":
            eng = self._v18.get("layer_stack")
            if eng:
                result = eng.push_to_layer(msg.get("layer", ""), msg.get("data", {}))
                await ws.send(json.dumps({"type": "v18_push_result", **result}))

        elif msg_type == "v18_pull_layer":
            eng = self._v18.get("layer_stack")
            if eng:
                result = eng.pull_from_layer(msg.get("layer", ""))
                await ws.send(json.dumps({"type": "v18_pull_result", **result}))

        elif msg_type == "v18_propagate_up":
            eng = self._v18.get("vertical_flow")
            if eng:
                result = eng.reason_bottom_up(msg.get("data", {}))
                await ws.send(json.dumps({"type": "v18_propagate_up_result", **result}))

        elif msg_type == "v18_propagate_down":
            eng = self._v18.get("vertical_flow")
            if eng:
                result = eng.reason_top_down(msg.get("goal", {}))
                await ws.send(json.dumps({"type": "v18_propagate_down_result", **result}))

        elif msg_type == "v18_merge_flows":
            eng = self._v18.get("vertical_flow")
            if eng:
                result = eng.merge_vertical_flows()
                await ws.send(json.dumps({"type": "v18_merge_result", **result}))

        elif msg_type == "v18_supervise_layer":
            eng = self._v18.get("hierarchical_supervisor")
            if eng:
                result = eng.supervise_layer(msg.get("layer", {}))
                await ws.send(json.dumps({"type": "v18_supervise_layer_result", **result}))

        elif msg_type == "v18_supervise_macro":
            eng = self._v18.get("hierarchical_supervisor")
            if eng:
                result = eng.supervise_macro(msg.get("agent", {}))
                await ws.send(json.dumps({"type": "v18_supervise_macro_result", **result}))

        elif msg_type == "v18_supervise_micro":
            eng = self._v18.get("hierarchical_supervisor")
            if eng:
                result = eng.supervise_micro(msg.get("agent", {}))
                await ws.send(json.dumps({"type": "v18_supervise_micro_result", **result}))

        elif msg_type == "v18_enforce_rules":
            eng = self._v18.get("hierarchical_supervisor")
            if eng:
                result = eng.enforce_hierarchy_rules()
                await ws.send(json.dumps({"type": "v18_enforce_result", **result}))

        elif msg_type == "v18_set_priority":
            eng = self._v18.get("priority_engine")
            if eng:
                result = eng.set_priority(msg.get("entity", {}), msg.get("level", "normal"))
                await ws.send(json.dumps({"type": "v18_priority_result", **result}))

        elif msg_type == "v18_adjust_priority":
            eng = self._v18.get("priority_engine")
            if eng:
                result = eng.adjust_priority(msg.get("entity", {}))
                await ws.send(json.dumps({"type": "v18_adjust_result", **result}))

        elif msg_type == "v18_priority_map":
            eng = self._v18.get("priority_engine")
            if eng:
                result = eng.compute_priority_map()
                await ws.send(json.dumps({"type": "v18_priority_map_result", **result}))

        elif msg_type == "v18_check_consistency":
            eng = self._v18.get("layered_consistency")
            if eng:
                result = eng.check_layer_consistency()
                await ws.send(json.dumps({"type": "v18_consistency_result", **result}))

        elif msg_type == "v18_enforce_consistency":
            eng = self._v18.get("layered_consistency")
            if eng:
                result = eng.enforce_layer_consistency()
                await ws.send(json.dumps({"type": "v18_enforce_consistency_result", **result}))

        elif msg_type == "v18_cross_level":
            eng = self._v18.get("layered_consistency")
            if eng:
                result = eng.check_cross_level()
                await ws.send(json.dumps({"type": "v18_cross_level_result", **result}))

        elif msg_type == "v18_explain_layer":
            eng = self._v18.get("layered_explainability")
            if eng:
                result = eng.explain_layer(msg.get("layer", {}))
                await ws.send(json.dumps({"type": "v18_explain_layer_result", **result}))

        elif msg_type == "v18_explain_macro":
            eng = self._v18.get("layered_explainability")
            if eng:
                result = eng.explain_macro(msg.get("agent", {}))
                await ws.send(json.dumps({"type": "v18_explain_macro_result", **result}))

        elif msg_type == "v18_explain_micro":
            eng = self._v18.get("layered_explainability")
            if eng:
                result = eng.explain_micro(msg.get("agent", {}))
                await ws.send(json.dumps({"type": "v18_explain_micro_result", **result}))

        elif msg_type == "v18_explain_flow":
            eng = self._v18.get("layered_explainability")
            if eng:
                result = eng.explain_vertical_flow()
                await ws.send(json.dumps({"type": "v18_explain_flow_result", **result}))

        elif msg_type == "v18_explain_decision":
            eng = self._v18.get("layered_explainability")
            if eng:
                result = eng.explain_decision(msg.get("decision", {}))
                await ws.send(json.dumps({"type": "v18_explain_decision_result", **result}))

        elif msg_type == "v18_stats":
            stats = {}
            for name, mod in self._v18.items():
                if hasattr(mod, "get_stats"):
                    stats[name] = mod.get_stats()
            await ws.send(json.dumps({"type": "v18_stats", **stats}))

        # ── v19 — Optimisation cognitive ─────────────────────
        elif msg_type == "v19_analyze_system":
            eng = self._v19.get("meta_optimizer")
            if eng:
                result = eng.analyze_system()
                await ws.send(json.dumps({"type": "v19_analyze_system_result", **result}))

        elif msg_type == "v19_detect_inefficiencies":
            eng = self._v19.get("meta_optimizer")
            if eng:
                result = eng.detect_inefficiencies()
                await ws.send(json.dumps({"type": "v19_detect_inefficiencies_result", **result}))

        elif msg_type == "v19_propose_optimizations":
            eng = self._v19.get("meta_optimizer")
            if eng:
                result = eng.propose_optimizations()
                await ws.send(json.dumps({"type": "v19_propose_optimizations_result", **result}))

        elif msg_type == "v19_update_heuristics":
            eng = self._v19.get("adaptive_heuristics")
            if eng:
                result = eng.update_heuristics()
                await ws.send(json.dumps({"type": "v19_update_heuristics_result", **result}))

        elif msg_type == "v19_select_strategy":
            eng = self._v19.get("adaptive_heuristics")
            if eng:
                result = eng.select_best_strategy(msg.get("task", {}))
                await ws.send(json.dumps({"type": "v19_select_strategy_result", **result}))

        elif msg_type == "v19_adapt_context":
            eng = self._v19.get("adaptive_heuristics")
            if eng:
                result = eng.adapt_to_context(msg.get("context", {}))
                await ws.send(json.dumps({"type": "v19_adapt_context_result", **result}))

        elif msg_type == "v19_optimize_pipeline":
            eng = self._v19.get("pipeline_optimizer")
            if eng:
                result = eng.optimize_pipeline(msg.get("pipeline", {}))
                await ws.send(json.dumps({"type": "v19_optimize_pipeline_result", **result}))

        elif msg_type == "v19_reorder_steps":
            eng = self._v19.get("pipeline_optimizer")
            if eng:
                result = eng.reorder_steps(msg.get("steps", {}))
                await ws.send(json.dumps({"type": "v19_reorder_steps_result", **result}))

        elif msg_type == "v19_optimize_flow":
            eng = self._v19.get("pipeline_optimizer")
            if eng:
                result = eng.optimize_flow(msg.get("flow", {}))
                await ws.send(json.dumps({"type": "v19_optimize_flow_result", **result}))

        elif msg_type == "v19_remove_redundancies":
            eng = self._v19.get("load_reducer")
            if eng:
                result = eng.remove_redundancies()
                await ws.send(json.dumps({"type": "v19_remove_redundancies_result", **result}))

        elif msg_type == "v19_reduce_llm_calls":
            eng = self._v19.get("load_reducer")
            if eng:
                result = eng.reduce_llm_calls()
                await ws.send(json.dumps({"type": "v19_reduce_llm_calls_result", **result}))

        elif msg_type == "v19_simplify_pipeline":
            eng = self._v19.get("load_reducer")
            if eng:
                result = eng.simplify_pipeline()
                await ws.send(json.dumps({"type": "v19_simplify_pipeline_result", **result}))

        elif msg_type == "v19_optimize_for":
            eng = self._v19.get("multi_objective")
            if eng:
                result = eng.optimize_for(msg.get("criteria", {}))
                await ws.send(json.dumps({"type": "v19_optimize_for_result", **result}))

        elif msg_type == "v19_compute_tradeoffs":
            eng = self._v19.get("multi_objective")
            if eng:
                result = eng.compute_tradeoffs(msg.get("criteria", {}))
                await ws.send(json.dumps({"type": "v19_compute_tradeoffs_result", **result}))

        elif msg_type == "v19_select_optimal":
            eng = self._v19.get("multi_objective")
            if eng:
                result = eng.select_optimal_solution()
                await ws.send(json.dumps({"type": "v19_select_optimal_result", **result}))

        elif msg_type == "v19_profile_system":
            eng = self._v19.get("profiling")
            if eng:
                result = eng.profile_system()
                await ws.send(json.dumps({"type": "v19_profile_system_result", **result}))

        elif msg_type == "v19_profile_agent":
            eng = self._v19.get("profiling")
            if eng:
                result = eng.profile_agent(msg.get("agent", {}))
                await ws.send(json.dumps({"type": "v19_profile_agent_result", **result}))

        elif msg_type == "v19_profile_layer":
            eng = self._v19.get("profiling")
            if eng:
                result = eng.profile_layer(msg.get("layer", {}))
                await ws.send(json.dumps({"type": "v19_profile_layer_result", **result}))

        elif msg_type == "v19_optimize_plan":
            eng = self._v19.get("plan_optimizer")
            if eng:
                result = eng.optimize_plan(msg.get("plan", {}))
                await ws.send(json.dumps({"type": "v19_optimize_plan_result", **result}))

        elif msg_type == "v19_simplify_plan":
            eng = self._v19.get("plan_optimizer")
            if eng:
                result = eng.simplify_plan(msg.get("plan", {}))
                await ws.send(json.dumps({"type": "v19_simplify_plan_result", **result}))

        elif msg_type == "v19_alternative_plans":
            eng = self._v19.get("plan_optimizer")
            if eng:
                result = eng.generate_alternative_plans(msg.get("plan", {}))
                await ws.send(json.dumps({"type": "v19_alternative_plans_result", **result}))

        elif msg_type == "v19_optimize_simulation":
            eng = self._v19.get("simulation_optimizer")
            if eng:
                result = eng.optimize_simulation(msg.get("sim", {}))
                await ws.send(json.dumps({"type": "v19_optimize_simulation_result", **result}))

        elif msg_type == "v19_prune_tree":
            eng = self._v19.get("simulation_optimizer")
            if eng:
                result = eng.prune_simulation_tree(msg.get("tree", {}))
                await ws.send(json.dumps({"type": "v19_prune_tree_result", **result}))

        elif msg_type == "v19_select_scenarios":
            eng = self._v19.get("simulation_optimizer")
            if eng:
                result = eng.select_relevant_scenarios()
                await ws.send(json.dumps({"type": "v19_select_scenarios_result", **result}))

        elif msg_type == "v19_optimize_inference":
            eng = self._v19.get("inference_optimizer")
            if eng:
                result = eng.optimize_inference(msg.get("query", {}))
                await ws.send(json.dumps({"type": "v19_optimize_inference_result", **result}))

        elif msg_type == "v19_simplify_rules":
            eng = self._v19.get("inference_optimizer")
            if eng:
                result = eng.simplify_rules()
                await ws.send(json.dumps({"type": "v19_simplify_rules_result", **result}))

        elif msg_type == "v19_compress_graph":
            eng = self._v19.get("inference_optimizer")
            if eng:
                result = eng.compress_knowledge_graph()
                await ws.send(json.dumps({"type": "v19_compress_graph_result", **result}))

        elif msg_type == "v19_explain_optimization":
            eng = self._v19.get("optimization_explainability")
            if eng:
                result = eng.explain_optimization()
                await ws.send(json.dumps({"type": "v19_explain_optimization_result", **result}))

        elif msg_type == "v19_explain_tradeoffs":
            eng = self._v19.get("optimization_explainability")
            if eng:
                result = eng.explain_tradeoffs()
                await ws.send(json.dumps({"type": "v19_explain_tradeoffs_result", **result}))

        elif msg_type == "v19_explain_gain":
            eng = self._v19.get("optimization_explainability")
            if eng:
                result = eng.explain_performance_gain()
                await ws.send(json.dumps({"type": "v19_explain_gain_result", **result}))

        elif msg_type == "v19_stats":
            stats = {}
            for name, mod in self._v19.items():
                if hasattr(mod, "get_stats"):
                    stats[name] = mod.get_stats()
            await ws.send(json.dumps({"type": "v19_stats", **stats}))

        # ── v20 — Architecture modulaire ultra-scalable ──────
        elif msg_type == "v20_mcu_init":
            mcu = self._v20.get("mcu")
            if mcu:
                result = mcu.mcu_init(name=data.get("name", "default"),
                                      version=data.get("version", "1.0.0"),
                                      capabilities=data.get("capabilities"),
                                      config=data.get("config"))
                await ws.send(json.dumps({"type": "v20_mcu_init_result", **result}))

        elif msg_type == "v20_mcu_execute":
            mcu = self._v20.get("mcu")
            if mcu:
                result = mcu.mcu_execute(data)
                await ws.send(json.dumps({"type": "v20_mcu_execute_result", **result}))

        elif msg_type == "v20_mcu_report":
            mcu = self._v20.get("mcu")
            if mcu:
                result = mcu.mcu_report()
                await ws.send(json.dumps({"type": "v20_mcu_report_result", **result}))

        elif msg_type == "v20_mcu_shutdown":
            mcu = self._v20.get("mcu")
            if mcu:
                result = mcu.mcu_shutdown(data.get("unit_id", ""))
                await ws.send(json.dumps({"type": "v20_mcu_shutdown_result", **result}))

        elif msg_type == "v20_register_agent":
            pnp = self._v20.get("plug_and_play")
            if pnp:
                result = pnp.register_agent(data)
                await ws.send(json.dumps({"type": "v20_register_agent_result", **result}))

        elif msg_type == "v20_unregister_agent":
            pnp = self._v20.get("plug_and_play")
            if pnp:
                result = pnp.unregister_agent(data)
                await ws.send(json.dumps({"type": "v20_unregister_agent_result", **result}))

        elif msg_type == "v20_replace_agent":
            pnp = self._v20.get("plug_and_play")
            if pnp:
                result = pnp.replace_agent(data.get("old", {}), data.get("new", {}))
                await ws.send(json.dumps({"type": "v20_replace_agent_result", **result}))

        elif msg_type == "v20_orchestrate":
            orch = self._v20.get("distributed_orchestrator")
            if orch:
                result = orch.orchestrate(data)
                await ws.send(json.dumps({"type": "v20_orchestrate_result", **result}))

        elif msg_type == "v20_distribute":
            orch = self._v20.get("distributed_orchestrator")
            if orch:
                result = orch.distribute(data)
                await ws.send(json.dumps({"type": "v20_distribute_result", **result}))

        elif msg_type == "v20_collect":
            orch = self._v20.get("distributed_orchestrator")
            if orch:
                result = orch.collect(data)
                await ws.send(json.dumps({"type": "v20_collect_result", **result}))

        elif msg_type == "v20_fabric_route":
            fab = self._v20.get("scalable_fabric")
            if fab:
                result = fab.fabric_route(data)
                await ws.send(json.dumps({"type": "v20_fabric_route_result", **result}))

        elif msg_type == "v20_fabric_register":
            fab = self._v20.get("scalable_fabric")
            if fab:
                result = fab.fabric_register(data)
                await ws.send(json.dumps({"type": "v20_fabric_register_result", **result}))

        elif msg_type == "v20_fabric_scale":
            fab = self._v20.get("scalable_fabric")
            if fab:
                result = fab.fabric_scale(data)
                await ws.send(json.dumps({"type": "v20_fabric_scale_result", **result}))

        elif msg_type == "v20_partition_cognition":
            pe = self._v20.get("partitioning")
            if pe:
                result = pe.partition_cognition(data)
                await ws.send(json.dumps({"type": "v20_partition_cognition_result", **result}))

        elif msg_type == "v20_reassign_partition":
            pe = self._v20.get("partitioning")
            if pe:
                result = pe.reassign_partition(data)
                await ws.send(json.dumps({"type": "v20_reassign_partition_result", **result}))

        elif msg_type == "v20_merge_partitions":
            pe = self._v20.get("partitioning")
            if pe:
                result = pe.merge_partitions(data.get("partition_ids"))
                await ws.send(json.dumps({"type": "v20_merge_partitions_result", **result}))

        elif msg_type == "v20_install_module":
            lm = self._v20.get("lifecycle")
            if lm:
                result = lm.install_module(data)
                await ws.send(json.dumps({"type": "v20_install_module_result", **result}))

        elif msg_type == "v20_update_module":
            lm = self._v20.get("lifecycle")
            if lm:
                result = lm.update_module(data)
                await ws.send(json.dumps({"type": "v20_update_module_result", **result}))

        elif msg_type == "v20_remove_module":
            lm = self._v20.get("lifecycle")
            if lm:
                result = lm.remove_module(data)
                await ws.send(json.dumps({"type": "v20_remove_module_result", **result}))

        elif msg_type == "v20_hotswap":
            hs = self._v20.get("hot_swap")
            if hs:
                result = hs.hotswap(data.get("old", {}), data.get("new", {}))
                await ws.send(json.dumps({"type": "v20_hotswap_result", **result}))

        elif msg_type == "v20_rollback":
            hs = self._v20.get("hot_swap")
            if hs:
                result = hs.rollback(data)
                await ws.send(json.dumps({"type": "v20_rollback_result", **result}))

        elif msg_type == "v20_validate_swap":
            hs = self._v20.get("hot_swap")
            if hs:
                result = hs.validate_swap(data.get("old", {}), data.get("new", {}))
                await ws.send(json.dumps({"type": "v20_validate_swap_result", **result}))

        elif msg_type == "v20_check_api":
            cc = self._v20.get("compatibility")
            if cc:
                result = cc.check_api(data)
                await ws.send(json.dumps({"type": "v20_check_api_result", **result}))

        elif msg_type == "v20_check_version":
            cc = self._v20.get("compatibility")
            if cc:
                result = cc.check_version(data)
                await ws.send(json.dumps({"type": "v20_check_version_result", **result}))

        elif msg_type == "v20_check_dependencies":
            cc = self._v20.get("compatibility")
            if cc:
                result = cc.check_dependencies(data)
                await ws.send(json.dumps({"type": "v20_check_dependencies_result", **result}))

        elif msg_type == "v20_explain_module":
            me = self._v20.get("modular_explainability")
            if me:
                result = me.explain_module(data)
                await ws.send(json.dumps({"type": "v20_explain_module_result", **result}))

        elif msg_type == "v20_explain_swap":
            me = self._v20.get("modular_explainability")
            if me:
                result = me.explain_swap(data.get("old", {}), data.get("new", {}))
                await ws.send(json.dumps({"type": "v20_explain_swap_result", **result}))

        elif msg_type == "v20_explain_partitioning":
            me = self._v20.get("modular_explainability")
            if me:
                result = me.explain_partitioning()
                await ws.send(json.dumps({"type": "v20_explain_partitioning_result", **result}))

        elif msg_type == "v20_stats":
            stats = {}
            for name, mod in self._v20.items():
                if hasattr(mod, "get_stats"):
                    stats[name] = mod.get_stats()
            await ws.send(json.dumps({"type": "v20_stats", **stats}))

        # ── v21 handlers ─────────────────────────────────
        elif msg_type == "v21_evaluate_rules":
            eng = self._v21.get("rule_engine")
            if eng:
                ctx = data.get("context", {})
                result = eng.evaluate_rules(ctx)
                await ws.send(json.dumps({"type": "v21_evaluate_rules_result", **result}))

        elif msg_type == "v21_causal_chain":
            eng = self._v21.get("causal_engine")
            if eng:
                query = data.get("query", {})
                result = eng.infer_causal_chain(query)
                await ws.send(json.dumps({"type": "v21_causal_chain_result", **result}))

        elif msg_type == "v21_deduce":
            eng = self._v21.get("deductive")
            if eng:
                query = data.get("query", {})
                result = eng.deduce(query)
                await ws.send(json.dumps({"type": "v21_deduce_result", **result}))

        elif msg_type == "v21_induce":
            eng = self._v21.get("inductive")
            if eng:
                patterns = data.get("patterns", {})
                result = eng.induce(patterns)
                await ws.send(json.dumps({"type": "v21_induce_result", **result}))

        elif msg_type == "v21_abduct":
            eng = self._v21.get("abductive")
            if eng:
                query = data.get("query", {})
                result = eng.abduct(query)
                await ws.send(json.dumps({"type": "v21_abduct_result", **result}))

        elif msg_type == "v21_solve_constraints":
            eng = self._v21.get("constraint_solver")
            if eng:
                cs = data.get("constraint_set", {})
                result = eng.solve_constraints(cs)
                await ws.send(json.dumps({"type": "v21_solve_constraints_result", **result}))

        elif msg_type == "v21_check_coherence":
            eng = self._v21.get("coherence")
            if eng:
                result = eng.check_logical_consistency()
                await ws.send(json.dumps({"type": "v21_check_coherence_result", **result}))

        elif msg_type == "v21_kg_add":
            eng = self._v21.get("kg_v2")
            if eng:
                node = data.get("node", {})
                result = eng.kg_add(node)
                await ws.send(json.dumps({"type": "v21_kg_add_result", **result}))

        elif msg_type == "v21_kg_query":
            eng = self._v21.get("kg_v2")
            if eng:
                pattern = data.get("pattern", {})
                result = eng.kg_query(pattern)
                await ws.send(json.dumps({"type": "v21_kg_query_result", **result}))

        elif msg_type == "v21_explain_symbolic":
            eng = self._v21.get("symbolic_explain")
            if eng:
                what = data.get("what", "deduction")
                if what == "deduction":
                    result = eng.explain_deduction()
                elif what == "induction":
                    result = eng.explain_induction()
                elif what == "abduction":
                    result = eng.explain_abduction()
                elif what == "causal":
                    result = eng.explain_causal_chain()
                else:
                    result = eng.explain_deduction()
                await ws.send(json.dumps({"type": "v21_explain_symbolic_result", **result}))

        elif msg_type == "v21_stats":
            stats = {}
            for name, mod in self._v21.items():
                if hasattr(mod, "get_stats"):
                    stats[name] = mod.get_stats()
            await ws.send(json.dumps({"type": "v21_stats", **stats}))

        # ── v22 — Planification stratégique ─────────────────
        elif msg_type == "v22_plan":
            planner = self._v22.get("strategic_planner")
            if planner:
                intent = msg.get("intent", {})
                result = planner.plan(intent)
                await ws.send(json.dumps({"type": "v22_plan_result", **result}))

        elif msg_type == "v22_htn_expand":
            eng = self._v22.get("htn_plus")
            if eng:
                task = msg.get("task", {})
                result = eng.htn_expand(task)
                await ws.send(json.dumps({"type": "v22_htn_expand_result", **result}))

        elif msg_type == "v22_multi_objective":
            eng = self._v22.get("multi_objective")
            if eng:
                intent = msg.get("intent", {})
                objectives = msg.get("objectives", [])
                result = eng.plan_multi_objectives(intent, objectives)
                await ws.send(json.dumps({"type": "v22_multi_objective_result", **result}))

        elif msg_type == "v22_apply_constraints":
            eng = self._v22.get("constraint_aware")
            if eng:
                plan = msg.get("plan", {})
                result = eng.apply_constraints(plan)
                await ws.send(json.dumps({"type": "v22_constraints_result", **result}))

        elif msg_type == "v22_scenarios":
            eng = self._v22.get("scenario_planner")
            if eng:
                intent = msg.get("intent", {})
                result = eng.generate_scenarios(intent)
                await ws.send(json.dumps({"type": "v22_scenarios_result", **result}))

        elif msg_type == "v22_arbitrate":
            eng = self._v22.get("arbitration")
            if eng:
                plans = msg.get("plans", [])
                result = eng.arbitrate(plans)
                await ws.send(json.dumps({"type": "v22_arbitrate_result", **result}))

        elif msg_type == "v22_temporal":
            eng = self._v22.get("temporal")
            if eng:
                plan = msg.get("plan", {})
                result = eng.analyze_temporal_constraints(plan)
                await ws.send(json.dumps({"type": "v22_temporal_result", **result}))

        elif msg_type == "v22_coherence":
            eng = self._v22.get("coherence")
            if eng:
                plan = msg.get("plan", {})
                result = eng.check_plan_coherence(plan)
                await ws.send(json.dumps({"type": "v22_coherence_result", **result}))

        elif msg_type == "v22_explain":
            eng = self._v22.get("explainability")
            if eng:
                what = msg.get("what", "plan")
                if what == "scenario":
                    scenario = msg.get("scenario", {})
                    result = eng.explain_scenario(scenario)
                elif what == "decision":
                    result = eng.explain_decision()
                else:
                    plan = msg.get("plan", {})
                    result = eng.explain_plan(plan)
                await ws.send(json.dumps({"type": "v22_explain_result", **result}))

        elif msg_type == "v22_stats":
            stats = {}
            for name, mod in self._v22.items():
                if hasattr(mod, "get_stats"):
                    stats[name] = mod.get_stats()
            await ws.send(json.dumps({"type": "v22_stats", **stats}))

        # ── v23 contextual simulation ──────────────────────
        elif msg_type == "v23_sandbox_init":
            eng = self._v23.get("sandbox")
            if eng:
                ctx = msg.get("context", {})
                result = eng.sandbox_init(ctx)
                await ws.send(json.dumps({"type": "v23_sandbox_init_result", **result}))

        elif msg_type == "v23_sandbox_run":
            eng = self._v23.get("sandbox")
            if eng:
                plan = msg.get("plan", {})
                result = eng.sandbox_run(plan)
                await ws.send(json.dumps({"type": "v23_sandbox_run_result", **result}))

        elif msg_type == "v23_generate_scenarios":
            eng = self._v23.get("multi_scenario")
            if eng:
                plan = msg.get("plan", {})
                result = eng.generate_scenarios(plan)
                await ws.send(json.dumps({"type": "v23_generate_scenarios_result", **result}))

        elif msg_type == "v23_simulate_scenarios":
            eng = self._v23.get("multi_scenario")
            if eng:
                scenarios = msg.get("scenarios", [])
                result = eng.simulate_scenarios(scenarios)
                await ws.send(json.dumps({"type": "v23_simulate_scenarios_result", **result}))

        elif msg_type == "v23_compare_scenarios":
            eng = self._v23.get("multi_scenario")
            if eng:
                scenarios = msg.get("scenarios", [])
                result = eng.compare_scenarios(scenarios)
                await ws.send(json.dumps({"type": "v23_compare_scenarios_result", **result}))

        elif msg_type == "v23_predict_outcomes":
            eng = self._v23.get("predictive")
            if eng:
                plan = msg.get("plan", {})
                result = eng.predict_outcomes(plan)
                await ws.send(json.dumps({"type": "v23_predict_outcomes_result", **result}))

        elif msg_type == "v23_predict_event":
            eng = self._v23.get("predictive")
            if eng:
                event = msg.get("event", {})
                result = eng.predict_event(event)
                await ws.send(json.dumps({"type": "v23_predict_event_result", **result}))

        elif msg_type == "v23_analyze_outcomes":
            eng = self._v23.get("outcome_analysis")
            if eng:
                results_data = msg.get("results", {})
                result = eng.analyze_outcomes(results_data)
                await ws.send(json.dumps({"type": "v23_analyze_outcomes_result", **result}))

        elif msg_type == "v23_classify_risks":
            eng = self._v23.get("outcome_analysis")
            if eng:
                results_data = msg.get("results", {})
                result = eng.classify_risks(results_data)
                await ws.send(json.dumps({"type": "v23_classify_risks_result", **result}))

        elif msg_type == "v23_temporal_flow":
            eng = self._v23.get("temporal_sim")
            if eng:
                plan = msg.get("plan", {})
                result = eng.simulate_temporal_flow(plan)
                await ws.send(json.dumps({"type": "v23_temporal_flow_result", **result}))

        elif msg_type == "v23_check_coherence":
            eng = self._v23.get("coherence")
            if eng:
                sim = msg.get("simulation", {})
                result = eng.check_simulation_coherence(sim)
                await ws.send(json.dumps({"type": "v23_check_coherence_result", **result}))

        elif msg_type == "v23_validate_simulation":
            eng = self._v23.get("governance")
            if eng:
                sim = msg.get("simulation", {})
                result = eng.validate_simulation(sim)
                await ws.send(json.dumps({"type": "v23_validate_simulation_result", **result}))

        elif msg_type == "v23_explain_simulation":
            eng = self._v23.get("explainability")
            if eng:
                sim = msg.get("simulation", {})
                result = eng.explain_simulation(sim)
                await ws.send(json.dumps({"type": "v23_explain_simulation_result", **result}))

        elif msg_type == "v23_explain_outcome":
            eng = self._v23.get("explainability")
            if eng:
                outcome = msg.get("outcome", {})
                result = eng.explain_outcome(outcome)
                await ws.send(json.dumps({"type": "v23_explain_outcome_result", **result}))

        elif msg_type == "v23_stats":
            stats = {}
            for name, mod in self._v23.items():
                if hasattr(mod, "get_stats"):
                    stats[name] = mod.get_stats()
            await ws.send(json.dumps({"type": "v23_stats", **stats}))

    async def broadcast(self, data: dict) -> None:
        if not self._clients:
            return
        payload = json.dumps(data)
        await asyncio.gather(
            *(c.send(payload) for c in self._clients),
            return_exceptions=True,
        )

    async def push_state(self, state: str, volume: float = 0.0, text: str = "") -> None:
        self._state = state
        if volume:
            self._volume = volume
        if text:
            self._text = text
        await self.broadcast({"state": state, "volume": self._volume, "text": text})


# ---------------------------------------------------------------------------
# Pipeline Manager v8.2
# ---------------------------------------------------------------------------

class PipelineManager:
    """Coordonne tous les modules ultra-low latency v8.2.

    Regroupe : warmup, fused pipeline, TTS prédictif, cache,
    CPU/GPU orchestrator, profiler, résilience, intégration v9.
    """

    def __init__(self) -> None:
        self.warmup = LLMWarmup()
        self.pipeline = FusedPipeline()
        self.tts_pred = TTSPredictive()
        self.cache = ContextCache()
        self.cpu_gpu = CPUGPUOrchestrator()
        self.profiler = PipelineProfiler()
        self.resilience = PipelineResilience()
        self.v9 = PipelineV9Integration("pipeline")

    async def startup(self) -> None:
        """Initialisation au démarrage du serveur."""
        # Priorité process
        self.cpu_gpu.init_process(high_priority=True)
        self.cpu_gpu.probe_gpu()

        # Warmup LLM (si send_fn configuré)
        result = await self.warmup.warmup()
        logger.info("Pipeline warmup: %s", result.get("status", "skip"))

        # KeepAlive en arrière-plan
        self.warmup.start_keepalive()
        logger.info("Pipeline v8.2 initialisé")

    def shutdown(self) -> None:
        """Arrêt propre."""
        self.warmup.stop_keepalive()
        logger.info("Pipeline v8.2 arrêté")

    def metrics(self) -> dict[str, Any]:
        """Métriques agrégées de tous les modules v8.2."""
        return {
            "warmup": self.warmup.metrics(),
            "pipeline": self.pipeline.metrics(),
            "tts_predictive": self.tts_pred.metrics(),
            "cache": self.cache.metrics(),
            "cpu_gpu": self.cpu_gpu.metrics(),
            "profiler": self.profiler.metrics(),
            "resilience": self.resilience.metrics(),
        }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

async def main() -> None:
    _load_env()

    # Prevent duplicate instances
    ensure_single_instance(8765, "exo_server")
    _v9 = init_v9("exo_server", 8765)

    # Initialize HA bridge + managers
    bridge = HomeBridge()
    entities = EntityManager(bridge)
    devices = DeviceManager(bridge)
    areas = AreaManager(bridge)
    actions = ActionDispatcher(bridge, entities, devices, areas)
    sync = SyncManager(bridge, entities, devices, areas)

    # Pipeline Manager v8.2
    pipeline_mgr = PipelineManager()

    # Agent Manager v10
    agent_mgr = AgentManager()
    logger.info("AgentManager v10 initialized")

    # ── v11 — Auto-apprentissage & auto-optimisation ─────────
    meta_memory = MetaMemory()
    governance = AutoGovernance(meta_memory)
    learning = LearningEngine(meta_memory, governance)
    feedback = FeedbackEngine(learning)

    # Optional v10 deps for diagnosis/optimization/planning
    task_memory = getattr(agent_mgr, "_task_memory", None)
    task_optimizer = getattr(agent_mgr, "_task_optimizer", None)

    diagnosis = SelfDiagnosisEngine(meta_memory, task_memory, task_optimizer)
    optimization = OptimizationEngine(meta_memory, diagnosis)
    tuning = AutoTuningEngine(meta_memory, governance)
    planner = MetaPlanner(meta_memory, task_optimizer)
    supervisor = MetaSupervisor(meta_memory, learning, governance)
    explanation = AutoExplanation(meta_memory)

    v11_modules = {
        "meta_memory": meta_memory,
        "governance": governance,
        "learning": learning,
        "feedback": feedback,
        "diagnosis": diagnosis,
        "optimization": optimization,
        "tuning": tuning,
        "planner": planner,
        "supervisor": supervisor,
        "explanation": explanation,
    }
    logger.info("EXO v11 self-learning modules initialized (%d modules)",
                len(v11_modules))

    # ── v12 — Auto-réflexion, méta-raisonnement, auto-cohérence ──
    reflection = SelfReflectionEngine(meta_memory, governance)
    meta_reasoning = MetaReasoningEngine(meta_memory, governance)
    planner_v2 = MetaPlannerV2(meta_memory, planner, reflection)
    verifier = MetaVerifier(meta_memory, governance)
    consistency = SelfConsistencyEngine(meta_memory, verifier, governance)
    supervisor_v2 = MetaSupervisorV2(
        meta_memory, supervisor, reflection, meta_reasoning, governance)
    explainability_v2 = ExplainabilityEngineV2(meta_memory, explanation)

    v12_modules = {
        "reflection": reflection,
        "reasoning": meta_reasoning,
        "planner_v2": planner_v2,
        "verifier": verifier,
        "consistency": consistency,
        "supervisor_v2": supervisor_v2,
        "explainability_v2": explainability_v2,
    }
    logger.info("EXO v12 meta-reasoning modules initialized (%d modules)",
                len(v12_modules))

    # ── v13 — Auto-simulation, prévision, planification prospective ──
    simulation_eng = SelfSimulationEngine(meta_memory, governance)
    prediction_eng = PredictionEngine(meta_memory, governance)
    future_planner = FuturePlanner(meta_memory, governance)
    multi_scenario = MultiScenarioEngine(meta_memory, simulation_eng, governance)
    temporal_coherence = TemporalCoherenceEngine(meta_memory, future_planner)
    anticipation = AnticipationEngine(meta_memory, prediction_eng, governance)
    explainability_v3 = ExplainabilityEngineV3(meta_memory, explainability_v2)
    supervisor_v3 = MetaSupervisorV3(
        meta_memory, supervisor_v2, simulation_eng, governance)

    v13_modules = {
        "simulation": simulation_eng,
        "prediction": prediction_eng,
        "future_planner": future_planner,
        "multi_scenario": multi_scenario,
        "temporal": temporal_coherence,
        "anticipation": anticipation,
        "explainability_v3": explainability_v3,
        "supervisor_v3": supervisor_v3,
    }
    logger.info("EXO v13 prospective modules initialized (%d modules)",
                len(v13_modules))

    # ── v14 — Cognition distribuée, agents spécialisés ────────
    msg_bus = AgentMessagingBus(meta_memory)
    registry = AgentRegistry(msg_bus)
    agents = create_default_agents(msg_bus, meta_memory)
    for a in agents:
        registry.register_agent(a)
    conflict_res = ConflictResolver(meta_memory, governance)
    cog_orchestrator = CognitiveOrchestrator(
        registry, msg_bus, conflict_res, meta_memory, governance)
    consistency_eng = DistributedConsistencyEngine(
        registry, msg_bus, conflict_res, meta_memory)
    supervisor_v4 = MetaSupervisorV4(
        meta_memory, registry, msg_bus, consistency_eng,
        supervisor_v3, governance)
    explainability_v4 = ExplainabilityEngineV4(
        meta_memory, registry, explainability_v3)

    v14_modules = {
        "messaging_bus": msg_bus,
        "registry": registry,
        "conflict_resolver": conflict_res,
        "orchestrator": cog_orchestrator,
        "consistency": consistency_eng,
        "supervisor_v4": supervisor_v4,
        "explainability_v4": explainability_v4,
    }
    logger.info("EXO v14 distributed cognition modules initialized "
                "(%d modules, %d agents)", len(v14_modules), len(agents))

    # ── v15 — Architecture cognitive complète ─────────────────
    expert_system = ExpertSystemEngine(meta_memory, governance)
    knowledge_graph = KnowledgeGraph(meta_memory)
    inference_eng = InferenceEngine(knowledge_graph, expert_system, meta_memory)
    cognitive_agent = CognitiveAgentCore(meta_memory, governance, inference_eng)
    meta_cognition = MetaCognitionEngine(meta_memory, governance)
    prospective = ProspectiveEngine(meta_memory, inference_eng)
    distrib_cognition = DistributedCognitionLayer(
        meta_memory, governance, agent_mgr)
    supervisor_v5 = GlobalSupervisorV5(
        meta_memory, governance, meta_cognition, distrib_cognition)
    explainability_v5 = ExplainabilityEngineV5(
        meta_memory, knowledge_graph, inference_eng)

    v15_modules = {
        "expert_system": expert_system,
        "knowledge_graph": knowledge_graph,
        "inference": inference_eng,
        "cognitive_agent": cognitive_agent,
        "meta_cognition": meta_cognition,
        "prospective": prospective,
        "distributed": distrib_cognition,
        "supervisor_v5": supervisor_v5,
        "explainability_v5": explainability_v5,
    }
    logger.info("EXO v15 cognitive architecture initialized (%d modules)",
                len(v15_modules))

    # ── v16 — Agents autonomes supervisés, émergence cognitive ─────
    cognitive_audit = CognitiveAuditLog(meta_memory)
    initiative_proto = InitiativeProtocol(cognitive_audit, governance)
    cog_governor = CognitiveGovernor(
        initiative_proto, cognitive_audit, governance, meta_memory)
    autonomous_layer = AutonomousAgentLayer(
        cog_governor, initiative_proto, cognitive_audit, meta_memory)
    collab_bus = EmergentCollaborationBus(
        cognitive_audit, msg_bus, meta_memory)
    emergent_reasoning = EmergentReasoningEngine(
        collab_bus, cog_governor, cognitive_audit, meta_memory,
        knowledge_graph, inference_eng)
    self_regulation = SelfRegulationEngine(
        cog_governor, cognitive_audit, initiative_proto, meta_memory)
    explainability_v6 = ExplainabilityEngineV6(
        meta_memory, explainability_v5, cognitive_audit)

    v16_modules = {
        "audit_log": cognitive_audit,
        "initiative_protocol": initiative_proto,
        "governor": cog_governor,
        "autonomous_layer": autonomous_layer,
        "collaboration_bus": collab_bus,
        "emergent_reasoning": emergent_reasoning,
        "self_regulation": self_regulation,
        "explainability_v6": explainability_v6,
    }
    logger.info("EXO v16 autonomous agents initialized (%d modules)",
                len(v16_modules))

    # ── v17 — Architecture neuro-symbolique ───────────────────
    reasoning_bridge = ReasoningBridge(
        knowledge_graph=knowledge_graph, inference_engine=inference_eng,
        meta_memory=meta_memory, governance=governance)
    hybrid_inference = HybridInferenceEngine(
        reasoning_bridge=reasoning_bridge, knowledge_graph=knowledge_graph,
        inference_engine=inference_eng, meta_memory=meta_memory,
        governance=governance)
    knowledge_grounded_llm = KnowledgeGroundedLLM(
        knowledge_graph=knowledge_graph, inference_engine=inference_eng,
        reasoning_bridge=reasoning_bridge, meta_memory=meta_memory,
        governance=governance)
    neurosymbolic_coherence = NeuroSymbolicCoherenceEngine(
        reasoning_bridge=reasoning_bridge, knowledge_graph=knowledge_graph,
        hybrid_inference=hybrid_inference, meta_memory=meta_memory,
        governance=governance)
    symbolic_validator = SymbolicValidator(
        knowledge_graph=knowledge_graph, inference_engine=inference_eng,
        reasoning_bridge=reasoning_bridge, governance=governance,
        meta_memory=meta_memory)
    semantic_extractor = SemanticExtractor(
        knowledge_graph=knowledge_graph, reasoning_bridge=reasoning_bridge,
        meta_memory=meta_memory)
    knowledge_augmentor = KnowledgeAugmentor(
        knowledge_graph=knowledge_graph, semantic_extractor=semantic_extractor,
        reasoning_bridge=reasoning_bridge, governance=governance,
        meta_memory=meta_memory)
    neurosymbolic_explainability = NeuroSymbolicExplainabilityEngine(
        meta_memory=meta_memory, explainability_v6=explainability_v6,
        reasoning_bridge=reasoning_bridge, hybrid_inference=hybrid_inference,
        symbolic_validator=symbolic_validator,
        coherence_engine=neurosymbolic_coherence)

    v17_modules = {
        "reasoning_bridge": reasoning_bridge,
        "hybrid_inference": hybrid_inference,
        "knowledge_grounded_llm": knowledge_grounded_llm,
        "coherence_engine": neurosymbolic_coherence,
        "symbolic_validator": symbolic_validator,
        "semantic_extractor": semantic_extractor,
        "knowledge_augmentor": knowledge_augmentor,
        "neurosymbolic_explainability": neurosymbolic_explainability,
    }
    logger.info("EXO v17 neuro-symbolic architecture initialized (%d modules)",
                len(v17_modules))

    # ── v18 — Cognition hiérarchique multi-niveaux ───────────
    macro_layer = MacroAgentLayer(
        meta_memory=meta_memory, governance=governance,
        registry=agent_registry)
    micro_layer = MicroAgentLayer(
        meta_memory=meta_memory, governance=governance)
    layer_stack = CognitiveLayerStack(
        macro_layer=macro_layer, micro_layer=micro_layer,
        governance=governance, meta_memory=meta_memory)
    vertical_flow = VerticalReasoningFlow(
        layer_stack=layer_stack, governance=governance,
        meta_memory=meta_memory)
    hierarchical_supervisor = HierarchicalSupervisor(
        layer_stack=layer_stack, macro_layer=macro_layer,
        micro_layer=micro_layer, governance=governance,
        meta_memory=meta_memory)
    priority_engine = PriorityEngine(
        layer_stack=layer_stack, macro_layer=macro_layer,
        micro_layer=micro_layer, governance=governance)
    layered_consistency = LayeredConsistencyEngine(
        layer_stack=layer_stack, macro_layer=macro_layer,
        micro_layer=micro_layer, supervisor=hierarchical_supervisor,
        governance=governance)
    layered_explainability = LayeredExplainabilityEngine(
        layer_stack=layer_stack, macro_layer=macro_layer,
        micro_layer=micro_layer, vertical_flow=vertical_flow,
        supervisor=hierarchical_supervisor, governance=governance)

    v18_modules = {
        "macro_layer": macro_layer,
        "micro_layer": micro_layer,
        "layer_stack": layer_stack,
        "vertical_flow": vertical_flow,
        "hierarchical_supervisor": hierarchical_supervisor,
        "priority_engine": priority_engine,
        "layered_consistency": layered_consistency,
        "layered_explainability": layered_explainability,
    }
    logger.info("EXO v18 hierarchical cognition initialized (%d modules)",
                len(v18_modules))

    # ── v19 — Optimisation cognitive ─────────────────────────
    meta_optimizer = MetaOptimizer(
        layer_stack=layer_stack, macro_layer=macro_layer,
        micro_layer=micro_layer, priority_engine=priority_engine,
        governance=governance, meta_memory=meta_memory)
    adaptive_heuristics = AdaptiveHeuristicsEngine(
        meta_optimizer=meta_optimizer, priority_engine=priority_engine,
        governance=governance)
    pipeline_optimizer = CognitivePipelineOptimizer(
        layer_stack=layer_stack, meta_optimizer=meta_optimizer,
        governance=governance)
    load_reducer = CognitiveLoadReducer(
        layer_stack=layer_stack, macro_layer=macro_layer,
        micro_layer=micro_layer, pipeline_optimizer=pipeline_optimizer,
        governance=governance)
    multi_objective = MultiObjectiveOptimizer(
        meta_optimizer=meta_optimizer, heuristics=adaptive_heuristics,
        governance=governance)
    profiling = CognitiveProfilingEngine(
        layer_stack=layer_stack, macro_layer=macro_layer,
        micro_layer=micro_layer, meta_optimizer=meta_optimizer)
    plan_opt = PlanOptimizer(
        meta_optimizer=meta_optimizer, pipeline_optimizer=pipeline_optimizer,
        governance=governance)
    sim_opt = SimulationOptimizer(
        meta_optimizer=meta_optimizer, profiling=profiling,
        governance=governance)
    inf_opt = InferenceOptimizer(
        inference_eng=inference_eng, knowledge_graph=knowledge_graph,
        meta_optimizer=meta_optimizer, governance=governance)
    opt_explain = OptimizationExplainabilityEngine(
        meta_optimizer=meta_optimizer, multi_objective=multi_objective,
        profiling=profiling, governance=governance)

    v19_modules = {
        "meta_optimizer": meta_optimizer,
        "adaptive_heuristics": adaptive_heuristics,
        "pipeline_optimizer": pipeline_optimizer,
        "load_reducer": load_reducer,
        "multi_objective": multi_objective,
        "profiling": profiling,
        "plan_optimizer": plan_opt,
        "simulation_optimizer": sim_opt,
        "inference_optimizer": inf_opt,
        "optimization_explainability": opt_explain,
    }
    logger.info("EXO v19 cognitive optimization initialized (%d modules)",
                len(v19_modules))

    # ── v20 — Architecture modulaire ultra-scalable ──────────
    mcu = ModularCognitiveUnit(
        governance=governance, meta_memory=meta_memory)
    plug_and_play = PlugAndPlayAgentSystem(
        governance=governance, agent_registry=agent_registry)
    dist_orchestrator = DistributedOrchestrator(
        governance=governance, mcu=mcu)
    scalable_fabric = ScalableCognitiveFabric(
        governance=governance, mcu=mcu)
    cog_partitioning = CognitivePartitioningEngine(
        governance=governance, mcu=mcu, fabric=scalable_fabric)
    mod_compatibility = ModuleCompatibilityChecker(
        governance=governance, mcu=mcu)
    mod_lifecycle = ModuleLifecycleManager(
        governance=governance, mcu=mcu, compatibility_checker=mod_compatibility)
    hot_swap = HotSwapEngine(
        governance=governance, lifecycle=mod_lifecycle,
        compatibility=mod_compatibility)
    mod_explain = ModularExplainabilityEngine(
        governance=governance, mcu=mcu, orchestrator=dist_orchestrator,
        partitioning=cog_partitioning, hot_swap=hot_swap,
        lifecycle=mod_lifecycle)

    v20_modules = {
        "mcu": mcu,
        "plug_and_play": plug_and_play,
        "distributed_orchestrator": dist_orchestrator,
        "scalable_fabric": scalable_fabric,
        "partitioning": cog_partitioning,
        "lifecycle": mod_lifecycle,
        "hot_swap": hot_swap,
        "compatibility": mod_compatibility,
        "modular_explainability": mod_explain,
    }
    logger.info("EXO v20 modular architecture initialized (%d modules)",
                len(v20_modules))

    # ── v21 — Système expert étendu ──────────────────────
    rule_engine = AdvancedRuleEngine(governance=governance)
    causal_engine = CausalGraphEngine(governance=governance)
    deductive = DeductiveReasoner(governance=governance)
    inductive = InductiveReasoner(governance=governance)
    abductive = AbductiveReasoner(governance=governance)
    constraint_solver = ConstraintSolver(
        governance=governance, rule_engine=rule_engine)
    coherence = LogicalCoherenceEngine(
        rule_engine=rule_engine, deductive=deductive, governance=governance)
    kg_v2 = KnowledgeGraphV2(
        knowledge_graph=knowledge_graph, causal_engine=causal_engine,
        governance=governance)
    symbolic_explain_v2 = SymbolicExplainabilityEngineV2(
        deductive=deductive, inductive=inductive, abductive=abductive,
        causal_engine=causal_engine, governance=governance)

    v21_modules = {
        "rule_engine": rule_engine,
        "causal_engine": causal_engine,
        "deductive": deductive,
        "inductive": inductive,
        "abductive": abductive,
        "constraint_solver": constraint_solver,
        "coherence": coherence,
        "kg_v2": kg_v2,
        "symbolic_explain": symbolic_explain_v2,
    }
    logger.info("EXO v21 expert system initialized (%d modules)",
                len(v21_modules))

    # ── v22 — Planification stratégique ──────────────────────
    htn_plus = HTNPlusEngine(governance=governance, htn_planner=htn_planner)
    multi_obj_planner = MultiObjectivePlanner(governance=governance)
    constraint_aware = ConstraintAwarePlanner(
        governance=governance, constraint_solver=constraint_solver)
    scenario_planner = ScenarioPlanner(governance=governance)
    arbitration = StrategicArbitrationEngine(governance=governance)
    temporal = TemporalPlanningEngine(governance=governance)
    plan_coherence = PlanCoherenceEngine(
        governance=governance, coherence_engine=coherence)
    planning_explain = PlanningExplainabilityEngine(
        governance=governance, arbitration=arbitration,
        coherence=plan_coherence)
    strategic_planner = StrategicPlanner(
        governance=governance, htn=htn_plus,
        multi_obj=multi_obj_planner,
        constraint_planner=constraint_aware,
        scenario_planner=scenario_planner,
        temporal_planner=temporal,
        arbitration=arbitration)

    v22_modules = {
        "strategic_planner": strategic_planner,
        "htn_plus": htn_plus,
        "multi_objective": multi_obj_planner,
        "constraint_aware": constraint_aware,
        "scenario_planner": scenario_planner,
        "arbitration": arbitration,
        "temporal": temporal,
        "coherence": plan_coherence,
        "explainability": planning_explain,
    }
    logger.info("EXO v22 strategic planning initialized (%d modules)",
                len(v22_modules))

    # ── EXO v23: Contextual Simulation ─────────────────────
    sim_governance = SimulationGovernanceEngine(governance=v11_modules.get("governance"))
    sim_sandbox = ContextSimulationSandbox(governance=sim_governance)
    multi_scenario = MultiScenarioSimulationEngine(
        governance=sim_governance, sandbox=sim_sandbox)
    predictive = PredictiveModelingEngine(
        governance=sim_governance, sandbox=sim_sandbox)
    outcome_analysis = OutcomeAnalysisEngine(
        governance=sim_governance, sandbox=sim_sandbox)
    temporal_sim = TemporalSimulationEngine(
        governance=sim_governance, sandbox=sim_sandbox)
    sim_coherence = SimulationCoherenceEngine(
        governance=sim_governance, sandbox=sim_sandbox)
    sim_explain = SimulationExplainabilityEngine(
        governance=sim_governance, sandbox=sim_sandbox)

    v23_modules = {
        "sandbox": sim_sandbox,
        "multi_scenario": multi_scenario,
        "predictive": predictive,
        "outcome_analysis": outcome_analysis,
        "temporal_sim": temporal_sim,
        "coherence": sim_coherence,
        "governance": sim_governance,
        "explainability": sim_explain,
    }
    logger.info("EXO v23 contextual simulation initialized (%d modules)",
                len(v23_modules))

    # GUI server
    gui = GUIServer(sync, pipeline_mgr, agent_mgr, v11_modules, v12_modules,
                    v13_modules, v14_modules, v15_modules, v16_modules,
                    v17_modules, v18_modules, v19_modules, v20_modules,
                    v21_modules, v22_modules, v23_modules)
    sync.set_gui_broadcast(gui.broadcast)

    # Start GUI WS server
    gui_server = await websockets.serve(
        gui.handler, "localhost", 8765,
        ping_interval=None, ping_timeout=None,
    )
    logger.info("EXO GUI WebSocket server running on ws://localhost:8765")

    # Start Pipeline v8.2
    await pipeline_mgr.startup()

    # Start HA bridge in background
    ha_token = os.environ.get("HA_TOKEN", "")
    if ha_token:
        ha_task = asyncio.create_task(bridge.start())
        logger.info("Home Assistant bridge starting...")
    else:
        ha_task = None
        logger.warning("HA_TOKEN not set — Home Assistant integration disabled")

    # Idle loop
    stop = asyncio.Event()

    def _signal_handler() -> None:
        stop.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, _signal_handler)
        except NotImplementedError:
            pass  # Windows

    logger.info("EXO server ready. Press Ctrl+C to stop.")

    try:
        await stop.wait()
    except KeyboardInterrupt:
        pass
    finally:
        logger.info("Shutting down...")
        pipeline_mgr.shutdown()
        gui_server.close()
        await gui_server.wait_closed()
        await bridge.stop()
        if ha_task:
            ha_task.cancel()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
