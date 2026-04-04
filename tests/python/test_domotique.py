#!/usr/bin/env python3
"""Tests unitaires — HomeGraphManager + Domotique v2."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "python"))

from domotique.models import Device, Room, Link, DeviceSource, DeviceType, Capability, LinkType


# ═══════════════════════════════════════════════════════
#  Tests Models
# ═══════════════════════════════════════════════════════

class TestDevice:
    def test_to_dict_basic(self):
        d = Device(
            id_exo="light_1",
            id_origin="hue:123",
            source=DeviceSource.HUE,
            type=DeviceType.LIGHT,
            name="Lampe salon",
            capabilities=[Capability.ON_OFF, Capability.BRIGHTNESS],
        )
        out = d.to_dict()
        assert out["id_exo"] == "light_1"
        assert out["source"] == "hue"
        assert out["type"] == "light"
        assert "on_off" in out["capabilities"]
        assert "brightness" in out["capabilities"]

    def test_to_dict_with_state(self):
        d = Device(
            id_exo="tv_1",
            id_origin="samsung:456",
            source=DeviceSource.SAMSUNG,
            type=DeviceType.TV,
            name="TV Salon",
            state={"on": True, "volume": 30},
        )
        out = d.to_dict()
        assert out["state"]["on"] is True
        assert out["state"]["volume"] == 30

    def test_default_values(self):
        d = Device(
            id_exo="x",
            id_origin="y",
            source=DeviceSource.OTHER,
            type=DeviceType.UNKNOWN,
            name="Test",
        )
        assert d.room_id == ""
        assert d.capabilities == set()
        assert d.state == {}
        assert d.online is True


class TestRoom:
    def test_to_dict(self):
        r = Room(id="salon", name="Salon", device_ids=["light_1", "tv_1"])
        out = r.to_dict()
        assert out["id"] == "salon"
        assert out["name"] == "Salon"
        assert len(out["device_ids"]) == 2


class TestLink:
    def test_to_dict(self):
        lk = Link(from_id="device_a", to_id="router", type=LinkType.WIFI)
        out = lk.to_dict()
        assert out["from_id"] == "device_a"
        assert out["to_id"] == "router"
        assert out["type"] == "wifi"


# ═══════════════════════════════════════════════════════
#  Tests HomeGraphManager
# ═══════════════════════════════════════════════════════

from domotique.homegraph_server import HomeGraphManager


class TestHomeGraphManager:
    def setup_method(self):
        self.hg = HomeGraphManager()

    def test_merge_devices(self):
        devices = [
            {
                "id_origin": "hue:1",
                "source": "hue",
                "type": "light",
                "name": "Lampe bureau",
                "capabilities": ["on_off", "brightness"],
                "state": {"on": True},
            },
            {
                "id_origin": "tapo:2",
                "source": "tapo",
                "type": "plug",
                "name": "Prise salon",
                "capabilities": ["on_off"],
                "state": {"on": False},
            },
        ]
        self.hg.merge_devices("hue", devices[:1])
        self.hg.merge_devices("tapo", devices[1:])
        assert len(self.hg.list_devices()) == 2

    def test_merge_rooms(self):
        rooms = [
            {"id": "salon", "name": "Salon"},
            {"id": "bureau", "name": "Bureau"},
        ]
        self.hg.merge_rooms(rooms)
        assert len(self.hg.list_rooms()) == 2

    def test_assign_device_to_room(self):
        self.hg.merge_devices("hue", [
            {"id_origin": "hue:1", "source": "hue", "type": "light",
             "name": "L1", "capabilities": [], "state": {}},
        ])
        self.hg.add_room("salon", "Salon")
        devs = self.hg.list_devices()
        assert len(devs) == 1
        dev_id = devs[0]["id_exo"]
        self.hg.assign_device_to_room(dev_id, "salon")
        rooms = self.hg.list_rooms()
        assert dev_id in rooms[0]["device_ids"]

    def test_find_device_by_name(self):
        self.hg.merge_devices("samsung", [
            {"id_origin": "samsung:tv1", "source": "samsung", "type": "tv",
             "name": "TV Salon", "capabilities": ["on_off"], "state": {}},
        ])
        result = self.hg.find_device_by_name("tv salon")
        assert isinstance(result, list)
        assert len(result) >= 1
        assert result[0]["name"] == "TV Salon"

    def test_find_device_by_name_not_found(self):
        result = self.hg.find_device_by_name("inexistant")
        assert result == []

    def test_find_devices_by_type(self):
        self.hg.merge_devices("hue", [
            {"id_origin": "hue:1", "source": "hue", "type": "light",
             "name": "L1", "capabilities": [], "state": {}},
            {"id_origin": "hue:2", "source": "hue", "type": "light",
             "name": "L2", "capabilities": [], "state": {}},
        ])
        self.hg.merge_devices("samsung", [
            {"id_origin": "samsung:tv1", "source": "samsung", "type": "tv",
             "name": "TV", "capabilities": [], "state": {}},
        ])
        lights = self.hg.find_devices_by_type("light")
        assert len(lights) == 2

    def test_update_device_state(self):
        self.hg.merge_devices("hue", [
            {"id_origin": "hue:1", "source": "hue", "type": "light",
             "name": "L1", "capabilities": [], "state": {"on": False}},
        ])
        devs = self.hg.list_devices()
        dev_id = devs[0]["id_exo"]
        ok = self.hg.update_device_state(dev_id, {"on": True, "brightness": 80})
        assert ok is True
        dev = self.hg.get_device(dev_id)
        assert dev["state"]["on"] is True
        assert dev["state"]["brightness"] == 80

    def test_update_device_state_not_found(self):
        ok = self.hg.update_device_state("nonexistent", {"on": True})
        assert ok is False

    def test_list_devices_by_room(self):
        self.hg.merge_devices("hue", [
            {"id_origin": "hue:1", "source": "hue", "type": "light",
             "name": "L1", "capabilities": [], "state": {}},
            {"id_origin": "hue:2", "source": "hue", "type": "light",
             "name": "L2", "capabilities": [], "state": {}},
        ])
        self.hg.add_room("salon", "Salon")
        devs = self.hg.list_devices()
        self.hg.assign_device_to_room(devs[0]["id_exo"], "salon")
        salon_devs = self.hg.list_devices_by_room("salon")
        assert len(salon_devs) == 1

    def test_merge_links(self):
        links = [
            {"from_id": "dev1", "to_id": "router", "type": "wifi"},
            {"from_id": "dev2", "to_id": "router", "type": "eth"},
        ]
        self.hg.merge_links(links)
        net = self.hg.get_network_links()
        assert len(net) == 2


# ═══════════════════════════════════════════════════════
#  Tests SamsungService
# ═══════════════════════════════════════════════════════

from domotique.samsung_service import SamsungService


class TestSamsungService:
    def setup_method(self):
        self.svc = SamsungService()

    def test_not_configured(self):
        assert self.svc.configured is False

    @pytest.mark.asyncio
    async def test_list_devices_empty(self):
        devices = await self.svc.list_devices()
        assert isinstance(devices, list)


# ═══════════════════════════════════════════════════════
#  Tests VoltalisService
# ═══════════════════════════════════════════════════════

from domotique.voltalis_service import VoltalisService


class TestVoltalisService:
    def setup_method(self):
        self.svc = VoltalisService()

    def test_not_configured(self):
        assert self.svc.configured is False

    @pytest.mark.asyncio
    async def test_list_devices_empty(self):
        devices = await self.svc.list_devices()
        assert isinstance(devices, list)


# ═══════════════════════════════════════════════════════
#  Tests EchoService
# ═══════════════════════════════════════════════════════

from domotique.echo_service import EchoService


class TestEchoService:
    def setup_method(self):
        self.svc = EchoService()

    def test_list_devices_empty(self):
        devices = self.svc.list_devices()
        assert isinstance(devices, list)

    @pytest.mark.asyncio
    async def test_get_state_not_found(self):
        state = await self.svc.get_state("nonexistent")
        assert state is None

    @pytest.mark.asyncio
    async def test_apply_command_unknown(self):
        result = await self.svc.apply_command("echo:x", "unknown_cmd")
        assert result["ok"] is False


# ═══════════════════════════════════════════════════════
#  Tests NetworkMapService
# ═══════════════════════════════════════════════════════

from network.network_map_service import NetworkMapService


class TestNetworkMapService:
    def setup_method(self):
        self.svc = NetworkMapService()

    def test_list_nodes_empty(self):
        nodes = self.svc.list_nodes()
        assert isinstance(nodes, list)
        assert len(nodes) == 0

    def test_list_links_empty(self):
        links = self.svc.list_links()
        assert isinstance(links, list)

    def test_get_node_not_found(self):
        node = self.svc.get_node_details("FF:FF:FF:FF:FF:FF")
        assert node is None

    def test_vendor_lookup_no_oui(self):
        vendor = self.svc._vendor_lookup("AA:BB:CC:DD:EE:FF")
        assert vendor == ""


# ═══════════════════════════════════════════════════════
#  Tests v2 — DomoticCache
# ═══════════════════════════════════════════════════════

from domotique.domotic_cache import DomoticCache


class TestDomoticCache:
    def setup_method(self):
        self.cache = DomoticCache(default_ttl=30.0)

    def test_set_and_get(self):
        self.cache.set_state("dev1", {"on": True, "brightness": 80})
        state = self.cache.get_state("dev1")
        assert state is not None
        assert state["on"] is True
        assert state["brightness"] == 80

    def test_get_miss(self):
        state = self.cache.get_state("nonexistent")
        assert state is None

    def test_invalidate(self):
        self.cache.set_state("dev1", {"on": True})
        self.cache.invalidate("dev1")
        state = self.cache.get_state("dev1")
        assert state is None

    def test_invalidate_all(self):
        self.cache.set_state("dev1", {"on": True})
        self.cache.set_state("dev2", {"on": False})
        self.cache.invalidate_all()
        assert self.cache.get_state("dev1") is None
        assert self.cache.get_state("dev2") is None

    def test_has(self):
        self.cache.set_state("dev1", {"on": True})
        assert self.cache.has("dev1") is True
        assert self.cache.has("nonexistent") is False

    def test_stats(self):
        self.cache.set_state("dev1", {"on": True})
        self.cache.get_state("dev1")  # hit
        self.cache.get_state("miss")  # miss
        stats = self.cache.stats()
        assert stats["entries"] >= 1
        assert stats["hits"] >= 1
        assert stats["misses"] >= 1

    def test_expired_entry(self):
        self.cache.set_state("dev1", {"on": True}, ttl=0.0)
        import time
        time.sleep(0.01)
        state = self.cache.get_state("dev1")
        assert state is None

    def test_all_states(self):
        self.cache.set_state("dev1", {"on": True})
        self.cache.set_state("dev2", {"on": False})
        states = self.cache.all_states()
        assert "dev1" in states
        assert "dev2" in states


# ═══════════════════════════════════════════════════════
#  Tests v2 — EventManager
# ═══════════════════════════════════════════════════════

from domotique.event_manager import EventManager


class TestEventManager:
    def setup_method(self):
        self.em = EventManager()
        self.events_received = []

    async def _callback(self, device_id, old_state, new_state):
        self.events_received.append((device_id, old_state, new_state))

    @pytest.mark.asyncio
    async def test_subscribe_and_emit(self):
        self.em.subscribe("dev1", self._callback)
        await self.em.on_event("dev1", {"on": True})
        assert len(self.events_received) == 1
        assert self.events_received[0][0] == "dev1"

    @pytest.mark.asyncio
    async def test_wildcard_subscribe(self):
        self.em.subscribe_all(self._callback)
        await self.em.on_event("dev1", {"on": True})
        await self.em.on_event("dev2", {"on": False})
        assert len(self.events_received) == 2

    @pytest.mark.asyncio
    async def test_no_event_on_same_state(self):
        self.em.subscribe("dev1", self._callback)
        await self.em.on_event("dev1", {"on": True})
        await self.em.on_event("dev1", {"on": True})
        # Second call same state → no new event
        assert len(self.events_received) == 1

    @pytest.mark.asyncio
    async def test_unsubscribe(self):
        self.em.subscribe("dev1", self._callback)
        self.em.unsubscribe("dev1", self._callback)
        await self.em.on_event("dev1", {"on": True})
        assert len(self.events_received) == 0

    def test_stats(self):
        stats = self.em.stats()
        assert "subscriptions" in stats
        assert "total_events" in stats

    @pytest.mark.asyncio
    async def test_recent_events(self):
        self.em.subscribe("dev1", self._callback)
        await self.em.on_event("dev1", {"on": True})
        events = self.em.recent_events(10)
        assert len(events) >= 1

    @pytest.mark.asyncio
    async def test_device_state(self):
        await self.em.on_event("dev1", {"on": True, "brightness": 80})
        state = self.em.device_state("dev1")
        assert state is not None
        assert state["on"] is True


# ═══════════════════════════════════════════════════════
#  Tests v2 — ScenarioManager
# ═══════════════════════════════════════════════════════

from domotique.scenario_manager import ScenarioManager, StepType, ScenarioStep


class TestScenarioManager:
    def setup_method(self):
        self.sm = ScenarioManager()
        self.commands_executed = []

    async def _executor(self, device_id, command, params=None):
        self.commands_executed.append((device_id, command, params))
        return {"ok": True}

    def test_list_builtin_scenarios(self):
        scenarios = self.sm.list_scenarios()
        assert len(scenarios) >= 6
        names = [s["name"] for s in scenarios]
        assert "cinema" in names
        assert "nuit" in names
        assert "absence" in names
        assert "reveil" in names
        assert "securite" in names
        assert "eco" in names

    def test_get_scenario(self):
        s = self.sm.get_scenario("cinema")
        assert s is not None
        assert s["name"] == "cinema"
        assert s["builtin"] is True

    def test_get_scenario_not_found(self):
        s = self.sm.get_scenario("nonexistent")
        assert s is None

    def test_add_custom_scenario(self):
        steps = [{"type": "action", "target": "*light*", "command": "turn_on"}]
        self.sm.add_scenario("test_custom", steps, description="Test")
        s = self.sm.get_scenario("test_custom")
        assert s is not None
        assert s["builtin"] is False

    def test_remove_custom_scenario(self):
        steps = [{"type": "action", "target": "*light*", "command": "turn_on"}]
        self.sm.add_scenario("toremove", steps)
        ok = self.sm.remove_scenario("toremove")
        assert ok is True
        assert self.sm.get_scenario("toremove") is None

    def test_cannot_remove_builtin(self):
        ok = self.sm.remove_scenario("cinema")
        assert ok is False

    @pytest.mark.asyncio
    async def test_run_scenario(self):
        self.sm.set_executor(self._executor)
        devices = [
            {"id_exo": "light_1", "type": "light", "name": "Lampe salon"},
            {"id_exo": "tv_1", "type": "tv", "name": "TV Salon"},
        ]
        result = await self.sm.run_scenario("cinema", devices)
        assert result is not None
        assert len(self.commands_executed) > 0


# ═══════════════════════════════════════════════════════
#  Tests v2 — Models v2 extensions
# ═══════════════════════════════════════════════════════

from domotique.models import Protocol, Connectivity, DeviceEvent


class TestModelsV2:
    def test_protocol_enum(self):
        assert Protocol.HUE == "hue"
        assert Protocol.TAPO == "tapo"
        assert Protocol.SAMSUNG == "samsung"

    def test_connectivity_enum(self):
        assert Connectivity.WIFI == "wifi"
        assert Connectivity.ETH == "eth"

    def test_device_event(self):
        evt = DeviceEvent(
            timestamp=1234567890.0,
            event_type="state_change",
            data={"on": True},
        )
        assert evt.timestamp == 1234567890.0
        assert evt.event_type == "state_change"

    def test_device_v2_fields(self):
        d = Device(
            id_exo="light_1",
            id_origin="hue:123",
            source=DeviceSource.HUE,
            type=DeviceType.LIGHT,
            name="Lampe salon",
            protocol=Protocol.HUE,
            connectivity=Connectivity.WIFI,
            tags=["salon", "ambiance"],
        )
        out = d.to_dict()
        assert out["protocol"] == "hue"
        assert out["connectivity"] == "wifi"
        assert "salon" in out["tags"]

    def test_device_v2_defaults(self):
        d = Device(
            id_exo="x",
            id_origin="y",
            source=DeviceSource.OTHER,
            type=DeviceType.UNKNOWN,
            name="Test",
        )
        assert d.tags == []
        assert d.energy == {}


# ═══════════════════════════════════════════════════════
#  Tests v2 — HomeGraph v2 API
# ═══════════════════════════════════════════════════════

class TestHomeGraphV2:
    def setup_method(self):
        self.hg = HomeGraphManager()

    def test_capabilities(self):
        caps = self.hg.capabilities()
        assert isinstance(caps, list)
        assert "list_devices" in caps
        assert "list_scenarios" in caps
        assert "refresh_device" in caps
        assert "discovery" in caps

    def test_metadata(self):
        meta = self.hg.metadata()
        assert meta["name"] == "homegraph"
        assert meta["version"] == "v2"
        assert "devices_count" in meta
        assert "cache" in meta

    def test_get_capabilities_for_device(self):
        self.hg.merge_devices("hue", [
            {"id_origin": "hue:1", "source": "hue", "type": "light",
             "name": "L1", "capabilities": ["on_off", "brightness"], "state": {}},
        ])
        devs = self.hg.list_devices()
        caps = self.hg.get_capabilities(devs[0]["id_exo"])
        assert "on_off" in caps

    def test_get_vendor(self):
        self.hg.merge_devices("hue", [
            {"id_origin": "hue:1", "source": "hue", "type": "light",
             "name": "L1", "capabilities": [], "state": {}, "vendor": "Philips"},
        ])
        devs = self.hg.list_devices()
        vendor = self.hg.get_vendor(devs[0]["id_exo"])
        assert vendor == "Philips"

    def test_cache_stats(self):
        stats = self.hg.get_cache_stats()
        assert "entries" in stats
        assert "hits" in stats

    def test_event_stats(self):
        stats = self.hg.get_event_stats()
        assert isinstance(stats, dict)

    def test_list_scenarios(self):
        scenarios = self.hg.list_scenarios()
        assert len(scenarios) >= 6

    def test_list_devices_by_type(self):
        self.hg.merge_devices("hue", [
            {"id_origin": "hue:1", "source": "hue", "type": "light",
             "name": "L1", "capabilities": [], "state": {}},
        ])
        lights = self.hg.list_devices_by_type("light")
        assert len(lights) >= 1


# ═══════════════════════════════════════════════════════
#  Tests v2 — Service capabilities/metadata
# ═══════════════════════════════════════════════════════

class TestServiceV2Capabilities:
    def test_samsung_capabilities(self):
        svc = SamsungService()
        caps = svc.capabilities()
        assert "list_devices" in caps
        assert "capabilities" in caps
        assert "metadata" in caps

    def test_samsung_metadata(self):
        svc = SamsungService()
        meta = svc.metadata()
        assert meta["name"] == "samsung"
        assert meta["version"] == "v2"

    def test_voltalis_capabilities(self):
        svc = VoltalisService()
        caps = svc.capabilities()
        assert "list_devices" in caps
        assert "get_consumption" in caps

    def test_voltalis_metadata(self):
        svc = VoltalisService()
        meta = svc.metadata()
        assert meta["name"] == "voltalis"
        assert meta["version"] == "v2"

    def test_echo_capabilities(self):
        svc = EchoService()
        caps = svc.capabilities()
        assert "send_tts" in caps
        assert "set_volume" in caps

    def test_echo_metadata(self):
        svc = EchoService()
        meta = svc.metadata()
        assert meta["name"] == "echo"
        assert meta["version"] == "v2"

    def test_networkmap_capabilities(self):
        svc = NetworkMapService()
        caps = svc.capabilities()
        assert "scan" in caps

    def test_networkmap_metadata(self):
        svc = NetworkMapService()
        meta = svc.metadata()
        assert meta["name"] == "network_map"
        assert meta["version"] == "v2"
