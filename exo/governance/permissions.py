"""
EXO Governance — PermissionManager.

Gestion des permissions RBAC pour agents et actions.
"""

import time


class PermissionManager:
    """Gère les permissions des entités (agents, utilisateurs)."""

    def __init__(self):
        self._permissions: dict[str, set[str]] = {}
        self._stats = {"checks": 0, "grants": 0, "denials": 0}

    def grant(self, entity: str, action: str) -> None:
        self._permissions.setdefault(entity, set()).add(action)
        self._stats["grants"] += 1

    def revoke(self, entity: str, action: str) -> None:
        if entity in self._permissions:
            self._permissions[entity].discard(action)

    def check(self, entity: str, action: str) -> bool:
        self._stats["checks"] += 1
        allowed = action in self._permissions.get(entity, set())
        if not allowed:
            self._stats["denials"] += 1
        return allowed

    def list_permissions(self, entity: str) -> list[str]:
        return sorted(self._permissions.get(entity, set()))

    def get_stats(self) -> dict:
        return dict(self._stats)
