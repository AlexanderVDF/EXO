"""
EXO Governance — ComplianceChecker.

Vérification de conformité aux politiques définies.
"""

import time


class ComplianceChecker:
    """Vérifie la conformité des décisions aux politiques."""

    DOMAINS = ("rules", "security", "permissions", "coherence")

    def __init__(self, policies: dict | None = None):
        self._policies = policies or {}
        self._stats = {"checks": 0, "compliant": 0, "violations": 0}

    def add_policy(self, domain: str, name: str, check_fn) -> None:
        self._policies.setdefault(domain, {})[name] = check_fn

    def check(self, data: dict) -> dict:
        self._stats["checks"] += 1
        violations = []

        for domain in self.DOMAINS:
            policies = self._policies.get(domain, {})
            for name, fn in policies.items():
                try:
                    if not fn(data):
                        violations.append({"domain": domain, "policy": name})
                except Exception as exc:
                    violations.append({
                        "domain": domain, "policy": name,
                        "error": str(exc),
                    })

        compliant = len(violations) == 0
        if compliant:
            self._stats["compliant"] += 1
        else:
            self._stats["violations"] += len(violations)

        return {
            "compliant": compliant,
            "violations": violations,
            "timestamp": time.time(),
        }

    def get_stats(self) -> dict:
        return dict(self._stats)
