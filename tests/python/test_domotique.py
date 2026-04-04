#!/usr/bin/env python3
"""Tests unitaires — HomeGraphManager (Domotique v1)."""

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
