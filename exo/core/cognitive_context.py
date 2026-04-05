"""
EXO Core — CognitiveContext + classes de données.

Classes de données : Rule, Plan, Scenario, SimulationResult,
GovernanceDecision, Metric, TraceSpan.
"""

import time
import uuid


class Rule:
    """Règle cognitive : condition → action."""

    def __init__(self, name: str, condition: str, action: str,
                 priority: int = 0):
        self.name = name
        self.condition = condition
        self.action = action
        self.priority = priority

    def matches(self, facts: dict) -> bool:
        """Évaluer la condition sur un ensemble de faits."""
        key = self.condition
        return facts.get(key, False) is True

    def to_dict(self) -> dict:
        return {"name": self.name, "condition": self.condition,
                "action": self.action, "priority": self.priority}


class Plan:
    """Plan cognitif : séquence d'étapes vers un objectif."""

    def __init__(self, name: str, steps: list[str], goal: str,
                 constraints: list[str] | None = None):
        self.name = name
        self.steps = list(steps)
        self.goal = goal
        self.constraints = constraints or []

    def to_dict(self) -> dict:
        return {"name": self.name, "steps": self.steps,
                "goal": self.goal, "constraints": self.constraints}


class Scenario:
    """Scénario de simulation."""

    def __init__(self, name: str, parameters: dict,
                 conditions: list[str] | None = None):
        self.name = name
        self.parameters = dict(parameters)
        self.conditions = conditions or []

    def to_dict(self) -> dict:
        return {"name": self.name, "parameters": self.parameters,
                "conditions": self.conditions}


class SimulationResult:
    """Résultat d'une simulation."""

    def __init__(self, scenario: str, outcome: str,
                 metrics: dict | None = None):
        self.scenario = scenario
        self.outcome = outcome
        self.metrics = metrics or {}
        self.timestamp = time.time()

    def to_dict(self) -> dict:
        return {"scenario": self.scenario, "outcome": self.outcome,
                "metrics": self.metrics, "timestamp": self.timestamp}


class GovernanceDecision:
    """Décision de gouvernance."""

    def __init__(self, action: str, decision: str, reason: str,
                 validated: bool = False):
        self.action = action
        self.decision = decision
        self.reason = reason
        self.validated = validated
        self.timestamp = time.time()

    def to_dict(self) -> dict:
        return {"action": self.action, "decision": self.decision,
                "reason": self.reason, "validated": self.validated,
                "timestamp": self.timestamp}


class Metric:
    """Métrique cognitive."""

    def __init__(self, name: str, value: float,
                 tags: dict | None = None):
        self.name = name
        self.value = value
        self.tags = tags or {}
        self.timestamp = time.time()

    def to_dict(self) -> dict:
        return {"name": self.name, "value": self.value,
                "tags": self.tags, "timestamp": self.timestamp}


class TraceSpan:
    """Span de traçage structuré."""

    def __init__(self, operation: str, trace_id: str | None = None,
                 span_id: str | None = None):
        self.trace_id = trace_id or uuid.uuid4().hex[:16]
        self.span_id = span_id or uuid.uuid4().hex[:8]
        self.operation = operation
        self.start_time = time.time()
        self.end_time: float | None = None
        self.tags: dict = {}
        self.status = "open"

    def finish(self, status: str = "ok") -> None:
        self.end_time = time.time()
        self.status = status

    @property
    def duration(self) -> float:
        end = self.end_time or time.time()
        return end - self.start_time

    def to_dict(self) -> dict:
        return {"trace_id": self.trace_id, "span_id": self.span_id,
                "operation": self.operation, "start": self.start_time,
                "end": self.end_time, "duration": self.duration,
                "status": self.status, "tags": self.tags}


class CognitiveContext:
    """Contexte cognitif pour un cycle de traitement."""

    def __init__(self, input_data: dict | None = None):
        self.id = uuid.uuid4().hex[:12]
        self.input_data = input_data or {}
        self.results: dict[str, dict] = {}
        self.traces: list[TraceSpan] = []
        self.metrics: list[Metric] = []
        self.timestamp = time.time()

    def set_result(self, layer: str, result: dict) -> None:
        self.results[layer] = result

    def get_result(self, layer: str) -> dict:
        return self.results.get(layer, {})

    def add_trace(self, span: TraceSpan) -> None:
        self.traces.append(span)

    def add_metric(self, metric: Metric) -> None:
        self.metrics.append(metric)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "input": self.input_data,
            "results": self.results,
            "traces": [t.to_dict() for t in self.traces],
            "metrics": [m.to_dict() for m in self.metrics],
            "timestamp": self.timestamp,
        }
