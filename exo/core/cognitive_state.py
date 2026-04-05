"""
EXO Core — CognitiveState + KnowledgeGraph.

Gestion de l'état cognitif : faits, croyances, objectifs, graphe de connaissances.
"""

import time
import copy


class KnowledgeGraph:
    """Graphe de connaissances cognitif."""

    def __init__(self):
        self._nodes: dict[str, dict] = {}
        self._edges: list[dict] = []

    def add_node(self, node_id: str, data: dict | None = None) -> None:
        self._nodes[node_id] = data or {}

    def remove_node(self, node_id: str) -> bool:
        if node_id not in self._nodes:
            return False
        del self._nodes[node_id]
        self._edges = [e for e in self._edges
                       if e["source"] != node_id and e["target"] != node_id]
        return True

    def add_edge(self, source: str, target: str, relation: str) -> None:
        self._edges.append({"source": source, "target": target,
                            "relation": relation})

    def query(self, node_id: str) -> dict | None:
        return self._nodes.get(node_id)

    def get_neighbors(self, node_id: str) -> list[str]:
        neighbors = []
        for e in self._edges:
            if e["source"] == node_id:
                neighbors.append(e["target"])
            elif e["target"] == node_id:
                neighbors.append(e["source"])
        return neighbors

    def get_edges(self, node_id: str) -> list[dict]:
        return [e for e in self._edges
                if e["source"] == node_id or e["target"] == node_id]

    @property
    def node_count(self) -> int:
        return len(self._nodes)

    @property
    def edge_count(self) -> int:
        return len(self._edges)

    def to_dict(self) -> dict:
        return {"nodes": dict(self._nodes), "edges": list(self._edges)}


class CognitiveState:
    """État cognitif global : faits, croyances, objectifs, plans actifs."""

    def __init__(self):
        self._facts: dict[str, object] = {}
        self._beliefs: dict[str, dict] = {}
        self._goals: list[str] = []
        self._active_plans: list[str] = []
        self._knowledge = KnowledgeGraph()
        self._timestamp = time.time()

    def add_fact(self, key: str, value: object) -> None:
        self._facts[key] = value

    def get_fact(self, key: str, default=None) -> object:
        return self._facts.get(key, default)

    def add_belief(self, key: str, value: object,
                   confidence: float = 1.0) -> None:
        self._beliefs[key] = {"value": value, "confidence": confidence}

    def get_belief(self, key: str) -> dict | None:
        return self._beliefs.get(key)

    def set_goal(self, goal: str) -> None:
        if goal not in self._goals:
            self._goals.append(goal)

    def remove_goal(self, goal: str) -> bool:
        if goal in self._goals:
            self._goals.remove(goal)
            return True
        return False

    def add_active_plan(self, plan_name: str) -> None:
        if plan_name not in self._active_plans:
            self._active_plans.append(plan_name)

    @property
    def knowledge(self) -> KnowledgeGraph:
        return self._knowledge

    @property
    def facts(self) -> dict:
        return dict(self._facts)

    @property
    def goals(self) -> list[str]:
        return list(self._goals)

    def snapshot(self) -> dict:
        return {
            "facts": dict(self._facts),
            "beliefs": copy.deepcopy(self._beliefs),
            "goals": list(self._goals),
            "active_plans": list(self._active_plans),
            "knowledge": self._knowledge.to_dict(),
            "timestamp": self._timestamp,
        }

    def reset(self) -> None:
        self._facts.clear()
        self._beliefs.clear()
        self._goals.clear()
        self._active_plans.clear()
        self._knowledge = KnowledgeGraph()
        self._timestamp = time.time()
