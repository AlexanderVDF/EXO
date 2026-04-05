"""
Tests — Gouvernance EXO (governance/).

Couvre : PermissionManager, MultiLevelValidator,
ComplianceChecker, AuditLogger.
"""

import pytest
from exo.governance import (
    PermissionManager,
    MultiLevelValidator,
    ComplianceChecker,
    AuditLogger,
)


# ── PermissionManager ───────────────────────────────────────

class TestPermissionManager:
    def test_grant_check(self):
        p = PermissionManager()
        p.grant("agent_a", "read")
        assert p.check("agent_a", "read") is True

    def test_denied(self):
        p = PermissionManager()
        assert p.check("agent_a", "write") is False

    def test_revoke(self):
        p = PermissionManager()
        p.grant("bot", "speak")
        p.revoke("bot", "speak")
        assert p.check("bot", "speak") is False

    def test_list(self):
        p = PermissionManager()
        p.grant("bot", "read")
        p.grant("bot", "write")
        assert p.list_permissions("bot") == ["read", "write"]

    def test_stats(self):
        p = PermissionManager()
        p.grant("a", "x")
        p.check("a", "x")
        p.check("a", "y")
        s = p.get_stats()
        assert s["grants"] == 1
        assert s["checks"] == 2
        assert s["denials"] == 1


# ── MultiLevelValidator ─────────────────────────────────────

class TestMultiLevelValidator:
    def test_valid(self):
        v = MultiLevelValidator()
        res = v.validate({"action": "greet"})
        assert res["valid"] is True
        assert all(res["levels"].values())

    def test_security_fail(self):
        v = MultiLevelValidator()
        res = v.validate({"action": "drop table users"})
        assert res["levels"]["security"] is False
        assert res["valid"] is False

    def test_custom_validator(self):
        v = MultiLevelValidator(custom_validators={
            "logic": lambda d: d.get("score", 0) > 0.5,
        })
        assert v.validate({"score": 0.8})["levels"]["logic"] is True
        assert v.validate({"score": 0.2})["levels"]["logic"] is False

    def test_stats(self):
        v = MultiLevelValidator()
        v.validate({"action": "ok"})
        v.validate({"action": "drop database"})
        s = v.get_stats()
        assert s["validated"] == 1
        assert s["rejected"] == 1


# ── ComplianceChecker ───────────────────────────────────────

class TestComplianceChecker:
    def test_no_policies(self):
        c = ComplianceChecker()
        res = c.check({"action": "anything"})
        assert res["compliant"] is True

    def test_policy_pass(self):
        c = ComplianceChecker()
        c.add_policy("rules", "not_empty", lambda d: bool(d.get("action")))
        res = c.check({"action": "greet"})
        assert res["compliant"] is True

    def test_policy_fail(self):
        c = ComplianceChecker()
        c.add_policy("rules", "must_have_reason", lambda d: "reason" in d)
        res = c.check({"action": "delete"})
        assert res["compliant"] is False
        assert len(res["violations"]) == 1

    def test_multiple_policies(self):
        c = ComplianceChecker()
        c.add_policy("rules", "p1", lambda d: True)
        c.add_policy("security", "p2", lambda d: False)
        res = c.check({})
        assert res["compliant"] is False

    def test_stats(self):
        c = ComplianceChecker()
        c.check({})
        s = c.get_stats()
        assert s["checks"] == 1


# ── AuditLogger ─────────────────────────────────────────────

class TestAuditLogger:
    def test_log(self):
        a = AuditLogger()
        entry = a.log("login", "user1")
        assert entry["action"] == "login"
        assert entry["entity"] == "user1"

    def test_query_action(self):
        a = AuditLogger()
        a.log("login", "u1")
        a.log("logout", "u1")
        a.log("login", "u2")
        res = a.query(action="login")
        assert len(res) == 2

    def test_query_entity(self):
        a = AuditLogger()
        a.log("login", "u1")
        a.log("login", "u2")
        res = a.query(entity="u1")
        assert len(res) == 1

    def test_export(self):
        a = AuditLogger()
        a.log("x", "y")
        assert len(a.export()) == 1

    def test_count(self):
        a = AuditLogger()
        a.log("a", "b")
        a.log("c", "d")
        assert a.count() == 2

    def test_max_entries(self):
        a = AuditLogger(max_entries=3)
        for i in range(5):
            a.log(f"action_{i}", "agent")
        assert a.count() == 3

    def test_stats(self):
        a = AuditLogger()
        a.log("x", "y")
        assert a.get_stats()["logged"] == 1
