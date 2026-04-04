#!/usr/bin/env python3
"""
EXO Domotique v1 — NetworkMapService (WebSocket) — Port 8790

Scanner réseau local : ARP, mDNS, SSDP/UPnP.
Détecte les appareils, attribue des noms via OUI lookup et mDNS.
Fournit une carte réseau avec nœuds et liens.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import socket
import struct
import subprocess
import sys
import time
from pathlib import Path

import websockets

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from shared.singleton_guard import ensure_single_instance
from shared.base_service import init_v9

log = logging.getLogger("network_map_service")
logging.basicConfig(level=logging.INFO,
                    format="%(asctime)s [%(name)s] %(levelname)s  %(message)s")

PORT = 8790

# OUI database path (optional — IEEE MA-L)
OUI_FILE = os.getenv(
    "EXO_OUI_FILE",
    str(Path(__file__).resolve().parent.parent.parent / "config" / "oui.txt"),
)


class NetworkMapService:
    """Scanner réseau local avec détection d'appareils."""

    def __init__(self) -> None:
        self._nodes: dict[str, dict] = {}   # keyed by MAC
        self._links: list[dict] = []
        self._oui: dict[str, str] = {}
        self._last_scan: float = 0
        self._gateway_ip: str = ""
        self._gateway_mac: str = ""
        self._load_oui()

    def _load_oui(self) -> None:
        """Load OUI vendor prefix database."""
        oui_path = Path(OUI_FILE)
        if not oui_path.exists():
            log.info("No OUI file at %s — vendor lookup disabled", oui_path)
            return
        try:
            with open(oui_path, encoding="utf-8", errors="ignore") as f:
                for line in f:
                    # Format: XX-XX-XX   (hex)   Vendor Name
                    m = re.match(r"^([0-9A-F]{2}-[0-9A-F]{2}-[0-9A-F]{2})\s+\(hex\)\s+(.+)$", line.strip())
                    if m:
                        prefix = m.group(1).replace("-", ":").upper()
                        self._oui[prefix] = m.group(2).strip()
            log.info("Loaded %d OUI entries", len(self._oui))
        except Exception as e:
            log.warning("Failed to load OUI: %s", e)

    def _vendor_lookup(self, mac: str) -> str:
        """Look up vendor from MAC prefix."""
        prefix = mac.upper()[:8]
        return self._oui.get(prefix, "")

    async def scan(self) -> dict:
        """Full network scan: ARP + mDNS + SSDP."""
        t0 = time.time()
        self._nodes.clear()
        self._links.clear()

        # Run ARP scan
        await self._scan_arp()

        # Try mDNS discovery
        await self._scan_mdns()

        # Try SSDP/UPnP discovery
        await self._scan_ssdp()

        # Build links (all nodes → gateway)
        self._build_links()

        self._last_scan = time.time()
        elapsed = time.time() - t0
        log.info("Scan complete: %d nodes, %d links (%.1fs)",
                 len(self._nodes), len(self._links), elapsed)

        return {
            "nodes": list(self._nodes.values()),
            "links": self._links,
            "scan_time_s": round(elapsed, 2),
        }

    async def _scan_arp(self) -> None:
        """Parse ARP table for local devices."""
        try:
            proc = await asyncio.create_subprocess_exec(
                "arp", "-a",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10)
            output = stdout.decode("utf-8", errors="ignore")

            for line in output.splitlines():
                # Windows: 192.168.1.1    00-1a-2b-3c-4d-5e    dynamic
                m = re.search(
                    r"(\d+\.\d+\.\d+\.\d+)\s+([0-9a-fA-F]{2}[:-][0-9a-fA-F]{2}[:-]"
                    r"[0-9a-fA-F]{2}[:-][0-9a-fA-F]{2}[:-][0-9a-fA-F]{2}[:-]"
                    r"[0-9a-fA-F]{2})",
                    line,
                )
                if not m:
                    continue
                ip = m.group(1)
                mac = m.group(2).replace("-", ":").upper()

                if mac == "FF:FF:FF:FF:FF:FF":
                    continue

                vendor = self._vendor_lookup(mac)

                # Detect gateway (usually .1 or .254)
                is_gateway = ip.endswith(".1") or ip.endswith(".254")
                if is_gateway and not self._gateway_mac:
                    self._gateway_ip = ip
                    self._gateway_mac = mac

                self._nodes[mac] = {
                    "mac": mac,
                    "ip": ip,
                    "vendor": vendor,
                    "name": "",
                    "type": "router" if is_gateway else "unknown",
                    "online": True,
                    "last_seen": time.time(),
                }
        except Exception as e:
            log.warning("ARP scan failed: %s", e)

    async def _scan_mdns(self) -> None:
        """Try mDNS/Bonjour resolution for known IPs."""
        for mac, node in list(self._nodes.items()):
            ip = node.get("ip", "")
            if not ip:
                continue
            try:
                hostname, _, _ = await asyncio.get_event_loop().run_in_executor(
                    None, socket.gethostbyaddr, ip
                )
                if hostname:
                    node["name"] = hostname
                    # Infer device type from hostname
                    hl = hostname.lower()
                    if "echo" in hl or "amazon" in hl:
                        node["type"] = "speaker"
                    elif "tv" in hl or "samsung" in hl or "lg" in hl:
                        node["type"] = "tv"
                    elif "phone" in hl or "iphone" in hl or "android" in hl:
                        node["type"] = "phone"
                    elif "pc" in hl or "desktop" in hl or "laptop" in hl:
                        node["type"] = "pc"
                    elif "nas" in hl or "synology" in hl:
                        node["type"] = "nas"
                    elif "cam" in hl or "ezviz" in hl:
                        node["type"] = "camera"
            except (socket.herror, socket.gaierror, OSError):
                pass
            except Exception:
                pass

    async def _scan_ssdp(self) -> None:
        """SSDP/UPnP M-SEARCH discovery."""
        try:
            msg = (
                "M-SEARCH * HTTP/1.1\r\n"
                "HOST: 239.255.255.250:1900\r\n"
                "MAN: \"ssdp:discover\"\r\n"
                "MX: 2\r\n"
                "ST: ssdp:all\r\n"
                "\r\n"
            )
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
            sock.settimeout(3)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sock.sendto(msg.encode(), ("239.255.255.250", 1900))

            while True:
                try:
                    data, addr = sock.recvfrom(4096)
                    ip = addr[0]
                    text = data.decode("utf-8", errors="ignore")

                    # Try to get server name
                    server = ""
                    for line in text.splitlines():
                        if line.upper().startswith("SERVER:"):
                            server = line.split(":", 1)[1].strip()
                            break

                    # Update existing node or add minimal entry
                    found = False
                    for mac, node in self._nodes.items():
                        if node.get("ip") == ip:
                            if server and not node.get("name"):
                                node["name"] = server
                            found = True
                            break
                    if not found:
                        self._nodes[f"ssdp:{ip}"] = {
                            "mac": "",
                            "ip": ip,
                            "vendor": "",
                            "name": server,
                            "type": "unknown",
                            "online": True,
                            "last_seen": time.time(),
                        }
                except socket.timeout:
                    break
            sock.close()
        except Exception as e:
            log.warning("SSDP scan failed: %s", e)

    def _build_links(self) -> None:
        """Build network links (each node → gateway)."""
        if not self._gateway_mac:
            return
        for mac, node in self._nodes.items():
            if mac == self._gateway_mac:
                continue
            link_type = "wifi"  # Default assumption
            vendor = node.get("vendor", "").lower()
            if "realtek" in vendor or "intel" in vendor:
                link_type = "eth"
            self._links.append({
                "from_id": mac,
                "to_id": self._gateway_mac,
                "type": link_type,
            })

    def list_nodes(self) -> list[dict]:
        return list(self._nodes.values())

    def list_links(self) -> list[dict]:
        return list(self._links)

    def get_node_details(self, identifier: str) -> dict | None:
        """Get node by MAC or IP."""
        for mac, node in self._nodes.items():
            if mac == identifier or node.get("ip") == identifier:
                return node
        return None


async def handle_client(ws, svc: NetworkMapService) -> None:
    await ws.send(json.dumps({
        "type": "ready", "service": "network_map", "version": "v1"
    }))
    try:
        async for raw in ws:
            if not isinstance(raw, str):
                continue
            msg = json.loads(raw)
            action = msg.get("action", msg.get("type", ""))
            params = msg.get("params", {})

            if action == "ping":
                await ws.send(json.dumps({"type": "pong"}))
                continue

            if action == "scan":
                result = await svc.scan()
                await ws.send(json.dumps({"ok": True, "data": result}))

            elif action == "list_nodes":
                nodes = svc.list_nodes()
                await ws.send(json.dumps({"ok": True, "data": {"nodes": nodes}}))

            elif action == "list_links":
                links = svc.list_links()
                await ws.send(json.dumps({"ok": True, "data": {"links": links}}))

            elif action == "get_node":
                node = svc.get_node_details(params.get("id", ""))
                if node:
                    await ws.send(json.dumps({"ok": True, "data": node}))
                else:
                    await ws.send(json.dumps({"ok": False, "error": "Not found"}))

            else:
                await ws.send(json.dumps({"ok": False, "error": f"Unknown: {action}"}))

    except websockets.exceptions.ConnectionClosed:
        pass
    except Exception as e:
        log.error("Handler error: %s", e)


async def main() -> None:
    import argparse
    parser = argparse.ArgumentParser(description="EXO Network Map Service")
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", type=int, default=PORT)
    args = parser.parse_args()

    ensure_single_instance(args.port, "network_map_service")
    _v9 = init_v9("network_map_service", args.port)

    svc = NetworkMapService()
    log.info("OUI entries: %d", len(svc._oui))

    server = await websockets.serve(
        lambda ws: handle_client(ws, svc),
        args.host, args.port,
        ping_interval=None, ping_timeout=None,
    )
    log.info("NetworkMapService on ws://%s:%d", args.host, args.port)
    await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
