"""
EXO Engine — Governance Engines.

GovernancePermissionSystem, GovernanceMultiLevelValidation,
GovernanceComplianceEngine, GovernanceAuditEngine.
"""

import time
import uuid

from ..core.cognitive_kernel import CognitiveEngine


class GovernancePermissionSystem(CognitiveEngine):
    """Système de permissions de gouvernance."""

    def __init__(self):
        super().__init__("governance_permission_system")
        self._permissions: dict[str, set[str]] = {}

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        op = data.get("operation", "check")
        entity = data.get("entity", "")
        action = data.get("action", "")

        if op == "grant":
            self._permissions.setdefault(entity, set()).add(action)
            return {"id": f"gp_{uuid.uuid4().hex[:8]}", "operation": "grant",
                    "entity": entity, "action": action, "granted": True,
                    "timestamp": time.time()}

        if op == "revoke":
            revoked = False
            if entity in self._permissions:
                self._permissions[entity].discard(action)
                revoked = True
            return {"id": f"gp_{uuid.uuid4().hex[:8]}", "operation": "revoke",
                    "entity": entity, "action": action, "revoked": revoked,
                    "timestamp": time.time()}

        # check
        allowed = action in self._permissions.get(entity, set())
        return {"id": f"gp_{uuid.uuid4().hex[:8]}", "operation": "check",
                "entity": entity, "action": action, "allowed": allowed,
                "timestamp": time.time()}


class GovernanceMultiLevelValidation(CognitiveEngine):
    """Validation multi‑niveaux de gouvernance."""

    LEVELS = ("logic", "context", "security", "coherence", "temporal")

    def __init__(self):
        super().__init__("governance_multi_level_validation")
        self._validations: list[dict] = []

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        action = data.get("action", "")
        entity = data.get("entity", "")
        rationale = data.get("rationale", "")

        results = {}
        for level in self.LEVELS:
            results[level] = self._validate_level(level, data)

        all_valid = all(r["valid"] for r in results.values())
        failed = [l for l, r in results.items() if not r["valid"]]

        record = {
            "id": f"gv_{uuid.uuid4().hex[:8]}",
            "action": action, "entity": entity,
            "validated": all_valid, "levels": results,
            "failed_levels": failed,
            "timestamp": time.time(),
        }
        self._validations.append(record)
        if len(self._validations) > 5000:
            self._validations = self._validations[-2500:]
        return record

    def _validate_level(self, level: str, data: dict) -> dict:
        if level == "logic":
            ok = bool(data.get("action"))
            return {"valid": ok, "reason": "ok" if ok else "action required"}
        if level == "context":
            return {"valid": True, "reason": "ok"}
        if level == "security":
            sensitive = data.get("sensitive", False)
            authorized = data.get("authorized", True)
            ok = not sensitive or authorized
            return {"valid": ok,
                    "reason": "ok" if ok else "sensitive not authorized"}
        if level == "coherence":
            ok = bool(data.get("rationale", ""))
            return {"valid": ok,
                    "reason": "ok" if ok else "rationale required"}
        if level == "temporal":
            return {"valid": True, "reason": "ok"}
        return {"valid": True, "reason": "ok"}


class GovernanceComplianceEngine(CognitiveEngine):
    """Moteur de conformité de gouvernance."""

    DOMAINS = ("rules", "security", "permissions", "coherence")

    def __init__(self):
        super().__init__("governance_compliance_engine")
        self._checks: list[dict] = []

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        action = data.get("action", "")
        entity = data.get("entity", "")

        results = {}
        for domain in self.DOMAINS:
            results[domain] = self._check_domain(domain, data)

        compliant = all(r["compliant"] for r in results.values())
        violations = [d for d, r in results.items() if not r["compliant"]]

        record = {
            "id": f"gc_{uuid.uuid4().hex[:8]}",
            "action": action, "entity": entity,
            "compliant": compliant, "domains": results,
            "violations": violations,
            "timestamp": time.time(),
        }
        self._checks.append(record)
        if len(self._checks) > 5000:
            self._checks = self._checks[-2500:]
        return record

    def _check_domain(self, domain: str, data: dict) -> dict:
        if domain == "rules":
            ok = bool(data.get("action"))
            return {"compliant": ok,
                    "reason": "ok" if ok else "action required"}
        if domain == "security":
            return {"compliant": True, "reason": "ok"}
        if domain == "permissions":
            return {"compliant": True, "reason": "ok"}
        if domain == "coherence":
            ok = bool(data.get("entity"))
            return {"compliant": ok,
                    "reason": "ok" if ok else "entity required"}
        return {"compliant": True, "reason": "ok"}


class GovernanceAuditEngine(CognitiveEngine):
    """Moteur d'audit de gouvernance."""

    def __init__(self):
        super().__init__("governance_audit_engine")
        self._logs: list[dict] = []

    def process(self, data: dict) -> dict:
        self._stats["processed"] += 1
        record = {
            "id": f"ga_{uuid.uuid4().hex[:8]}",
            "category": data.get("category", "general"),
            "source": data.get("source", "unknown"),
            "action": data.get("action", "unknown"),
            "details": data.get("details", {}),
            "timestamp": time.time(),
        }
        self._logs.append(record)
        if len(self._logs) > 5000:
            self._logs = self._logs[-2500:]
        return {"logged": True, "total": len(self._logs), **record}

    def query(self, category: str | None = None,
              limit: int = 50) -> list[dict]:
        results = self._logs
        if category:
            results = [r for r in results if r["category"] == category]
        return results[-limit:]

    def export(self) -> dict:
        by_category: dict[str, int] = {}
        for r in self._logs:
            c = r["category"]
            by_category[c] = by_category.get(c, 0) + 1
        return {"total": len(self._logs), "by_category": by_category,
                "logs": self._logs[-100:]}
