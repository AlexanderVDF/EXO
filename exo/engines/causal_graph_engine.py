"""
EXO Engine — CausalGraphEngine.

Moteur de graphe causal : nœuds causaux, propagation, analyse d'impact.
"""

import time
import uuid

from ..core.cognitive_kernel import CognitiveEngine


class CausalGraphEngine(CognitiveEngine):
    """Moteur de graphe causal cognitif."""

    def __init__(self):
        super().__init__("causal_graph_engine")
        self._nodes: dict[str, dict] = {}
        self._edges: list[dict] = []

    def add_cause(self, cause: str, effect: str,
                  strength: float = 1.0) -> None:
        for n in (cause, effect):
            if n not in self._nodes:
                self._nodes[n] = {"name": n}
        self._edges.append({"cause": cause, "effect": effect,
                            "strength": strength})

    def process(self, data: dict) -> dict:
        """Analyser la propagation causale depuis un nœud source."""
        self._stats["processed"] += 1
        source = data.get("source", "")
        visited = set()
        chain = self._propagate(source, visited)
        return {
            "id": f"cg_{uuid.uuid4().hex[:8]}",
            "source": source,
            "chain": chain,
            "depth": len(chain),
            "total_nodes": len(self._nodes),
            "total_edges": len(self._edges),
            "timestamp": time.time(),
        }

    def _propagate(self, node: str, visited: set) -> list[dict]:
        if node in visited:
            return []
        visited.add(node)
        effects = []
        for e in self._edges:
            if e["cause"] == node:
                effects.append({
                    "effect": e["effect"],
                    "strength": e["strength"],
                    "sub_effects": self._propagate(e["effect"], visited),
                })
        return effects

    def impact_analysis(self, node: str) -> dict:
        """Analyse d'impact : quels nœuds sont affectés."""
        visited: set[str] = set()
        self._collect_affected(node, visited)
        visited.discard(node)
        return {
            "source": node,
            "affected_nodes": sorted(visited),
            "affected_count": len(visited),
        }

    def _collect_affected(self, node: str, visited: set) -> None:
        if node in visited:
            return
        visited.add(node)
        for e in self._edges:
            if e["cause"] == node:
                self._collect_affected(e["effect"], visited)

    def root_cause_analysis(self, effect: str) -> list[str]:
        """Trouver les causes racines d'un effet."""
        roots: list[str] = []
        self._find_roots(effect, set(), roots)
        return roots

    def _find_roots(self, node: str, visited: set,
                    roots: list[str]) -> None:
        if node in visited:
            return
        visited.add(node)
        causes = [e["cause"] for e in self._edges if e["effect"] == node]
        if not causes:
            roots.append(node)
        else:
            for c in causes:
                self._find_roots(c, visited, roots)
