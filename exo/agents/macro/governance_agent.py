"""
EXO Macro Agent — GovernanceAgent.

Orchestre la gouvernance : permissions, validation, conformité, audit.
"""

from ...core.cognitive_kernel import MacroAgent


class GovernanceAgent(MacroAgent):
    """Agent macro de gouvernance : vérifie et audite les décisions."""

    def __init__(self, permission_mgr=None, validator=None,
                 compliance=None, audit=None):
        super().__init__("governance")
        self._permissions = permission_mgr
        self._validator = validator
        self._compliance = compliance
        self._audit = audit

    def execute(self, context: dict) -> dict:
        self._stats["executions"] += 1
        report = {"agent": self.name, "approved": True}

        entity = context.get("entity", "system")
        action = context.get("action", "unknown")

        # 1 — Permissions
        if self._permissions:
            allowed = self._permissions.check(entity, action)
            report["permission"] = allowed
            if not allowed:
                report["approved"] = False

        # 2 — Validation multi-niveaux
        if self._validator:
            val = self._validator.validate(context)
            report["validation"] = val
            if not val.get("valid", True):
                report["approved"] = False

        # 3 — Conformité
        if self._compliance:
            comp = self._compliance.check(context)
            report["compliance"] = comp
            if not comp.get("compliant", True):
                report["approved"] = False

        # 4 — Audit
        if self._audit:
            self._audit.log(action, entity, {"approved": report["approved"]})

        # Sous-agents
        for agent in self._sub_agents:
            try:
                r = agent.execute(context)
                report.update(r)
            except Exception:
                self._stats["errors"] += 1

        return report
