"""
EXO Core — CognitiveKernel.

Classes de base abstraites : BaseAgent, MacroAgent, MicroAgent,
CognitiveEngine, CognitiveLayer, CognitivePipeline, CognitiveSupervisor.
"""

from __future__ import annotations

import time
import uuid
from abc import ABC, abstractmethod


# ═══════════════════════════════════════════════════════════
#  Agents
# ═══════════════════════════════════════════════════════════

class BaseAgent(ABC):
    """Agent cognitif de base."""

    def __init__(self, name: str):
        self.name = name
        self._id = uuid.uuid4().hex[:8]
        self._stats = {"executions": 0, "errors": 0}

    @abstractmethod
    def execute(self, context: dict) -> dict:
        """Exécuter la tâche de l'agent."""

    def report(self) -> dict:
        return {"agent": self.name, "id": self._id,
                "stats": dict(self._stats)}


class MacroAgent(BaseAgent):
    """Agent macro : orchestre des sous‑agents."""

    def __init__(self, name: str, sub_agents: list[BaseAgent] | None = None):
        super().__init__(name)
        self._sub_agents: list[BaseAgent] = list(sub_agents or [])

    def add_agent(self, agent: BaseAgent) -> None:
        self._sub_agents.append(agent)

    def execute(self, context: dict) -> dict:
        self._stats["executions"] += 1
        results = {}
        for agent in self._sub_agents:
            try:
                results[agent.name] = agent.execute(context)
            except Exception as exc:
                self._stats["errors"] += 1
                results[agent.name] = {"error": str(exc)}
        return {"agent": self.name, "sub_results": results,
                "timestamp": time.time()}


class MicroAgent(BaseAgent):
    """Agent micro : tâche unitaire spécialisée."""

    def execute(self, context: dict) -> dict:
        self._stats["executions"] += 1
        return {"agent": self.name, "status": "executed",
                "input_keys": list(context.keys()),
                "timestamp": time.time()}


# ═══════════════════════════════════════════════════════════
#  Engine
# ═══════════════════════════════════════════════════════════

class CognitiveEngine(ABC):
    """Moteur cognitif de base."""

    def __init__(self, name: str):
        self.name = name
        self._stats = {"processed": 0, "errors": 0}

    @abstractmethod
    def process(self, data: dict) -> dict:
        """Traiter une entrée et produire un résultat."""

    def health_check(self) -> dict:
        return {"engine": self.name, "status": "ok",
                "stats": dict(self._stats)}

    def restart(self) -> None:
        for k in self._stats:
            self._stats[k] = 0

    def get_stats(self) -> dict:
        return dict(self._stats)


# ═══════════════════════════════════════════════════════════
#  Layer
# ═══════════════════════════════════════════════════════════

class CognitiveLayer(ABC):
    """Couche cognitive dans un pipeline."""

    def __init__(self, name: str):
        self.name = name
        self._stats = {"processed": 0}

    @abstractmethod
    def process(self, data: dict) -> dict:
        """Traiter les données et passer au suivant."""

    def get_stats(self) -> dict:
        return dict(self._stats)


# ═══════════════════════════════════════════════════════════
#  Pipeline
# ═══════════════════════════════════════════════════════════

class CognitivePipeline(ABC):
    """Pipeline cognitif orchestrant des couches."""

    def __init__(self, name: str, layers: list[CognitiveLayer] | None = None):
        self.name = name
        self._layers: list[CognitiveLayer] = list(layers or [])
        self._traces: list[dict] = []
        self._stats = {"runs": 0, "errors": 0}

    def add_layer(self, layer: CognitiveLayer) -> None:
        self._layers.append(layer)

    @abstractmethod
    def run(self, input_data: dict) -> dict:
        """Exécuter le pipeline sur des données d'entrée."""

    def trace(self) -> list[dict]:
        return list(self._traces)

    def get_stats(self) -> dict:
        return dict(self._stats)


# ═══════════════════════════════════════════════════════════
#  Supervisor
# ═══════════════════════════════════════════════════════════

class CognitiveSupervisor:
    """Superviseur cognitif : monitoring, validation, enforcement."""

    def __init__(self):
        self._monitored: list[str] = []
        self._validations: list[dict] = []
        self._enforcements: list[dict] = []
        self._stats = {"monitored": 0, "validated": 0, "enforced": 0}

    def monitor(self, component_name: str, health: dict) -> dict:
        self._stats["monitored"] += 1
        status = health.get("status", "unknown")
        self._monitored.append(component_name)
        return {"component": component_name, "status": status,
                "timestamp": time.time()}

    def validate(self, decision: dict) -> dict:
        self._stats["validated"] += 1
        valid = bool(decision.get("action")) and bool(decision.get("reason"))
        record = {"decision": decision, "valid": valid,
                  "timestamp": time.time()}
        self._validations.append(record)
        return record

    def enforce(self, rule: dict) -> dict:
        self._stats["enforced"] += 1
        record = {"rule": rule, "enforced": True,
                  "timestamp": time.time()}
        self._enforcements.append(record)
        return record

    def get_stats(self) -> dict:
        return dict(self._stats)
