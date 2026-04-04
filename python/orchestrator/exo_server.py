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
                 v14: dict | None = None) -> None:
        self._sync = sync
        self._pipeline = pipeline_mgr
        self._agent = agent_mgr
        self._v11 = v11 or {}
        self._v12 = v12 or {}
        self._v13 = v13 or {}
        self._v14 = v14 or {}
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

    # GUI server
    gui = GUIServer(sync, pipeline_mgr, agent_mgr, v11_modules, v12_modules,
                    v13_modules, v14_modules)
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
