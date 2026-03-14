"""
exo_server.py — EXO backend server.

Runs:
1. Home Assistant bridge (WebSocket + REST)
2. GUI WebSocket server on ws://localhost:8765
3. BrainEngine function-calling router

This is the main entry point for the Python side of EXO.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import signal
import sys
from pathlib import Path
from typing import Any

import websockets
import websockets.server

# Add project root to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from src.integrations.home_bridge import HomeBridge
from src.integrations.ha_entities import EntityManager
from src.integrations.ha_devices import DeviceManager
from src.integrations.ha_areas import AreaManager
from src.integrations.ha_actions import ActionDispatcher, TOOL_DEFINITIONS
from src.integrations.ha_sync import SyncManager

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("exo.server")

# ---------------------------------------------------------------------------
# Load .env
# ---------------------------------------------------------------------------

def _load_env() -> None:
    env_path = Path(__file__).resolve().parent.parent / ".env"
    if env_path.exists():
        for line in env_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, _, val = line.partition("=")
                os.environ.setdefault(key.strip(), val.strip())


# ---------------------------------------------------------------------------
# GUI WebSocket server
# ---------------------------------------------------------------------------

class GUIServer:
    """WebSocket server that the React GUI connects to (ws://localhost:8765)."""

    def __init__(self, sync: SyncManager) -> None:
        self._sync = sync
        self._clients: set[websockets.server.WebSocketServerProtocol] = set()
        self._state = "IDLE"
        self._volume = 0.0
        self._text = ""

    async def handler(self, ws: websockets.server.WebSocketServerProtocol) -> None:
        self._clients.add(ws)
        logger.info("GUI client connected (%d total)", len(self._clients))
        try:
            # Send initial snapshot
            snapshot = self._sync.build_full_snapshot()
            snapshot["state"] = self._state
            snapshot["volume"] = self._volume
            snapshot["text"] = self._text
            await ws.send(json.dumps(snapshot))

            async for raw in ws:
                await self._handle_client_message(ws, raw)
        finally:
            self._clients.discard(ws)
            logger.info("GUI client disconnected (%d remaining)", len(self._clients))

    async def _handle_client_message(self, ws: Any, raw: str) -> None:
        try:
            msg = json.loads(raw)
        except json.JSONDecodeError:
            return

        msg_type = msg.get("type")

        if msg_type == "plan_move":
            await self._sync.on_plan_move(
                device_id=msg.get("device_id", ""),
                x=msg.get("x", 0),
                y=msg.get("y", 0),
                room=msg.get("room", ""),
            )

        elif msg_type == "settings_update":
            logger.info("Settings update: %s = %s", msg.get("key"), msg.get("value"))

        elif msg_type == "network_scan":
            hosts = msg.get("hosts", [])
            await self._sync.sync_network_devices(hosts)

        elif msg_type == "transcript":
            text = msg.get("text", "")
            timestamp = msg.get("timestamp", 0)
            logger.info("Voice transcript: %s (ts=%s)", text, timestamp)
            await self.broadcast({"type": "transcript", "text": text})

        elif msg_type == "partial_transcript":
            text = msg.get("text", "")
            await self.broadcast({"type": "partial_transcript", "text": text})

        elif msg_type == "pipeline_state":
            state = msg.get("state", "idle")
            logger.info("Pipeline state: %s", state)
            await self.push_state(state)

        elif msg_type == "audio_level":
            rms = msg.get("rms", 0.0)
            vad = msg.get("vad_score", 0.0)
            is_speech = msg.get("is_speech", False)
            await self.broadcast({
                "type": "audio_level",
                "rms": rms,
                "vad_score": vad,
                "is_speech": is_speech,
            })

    async def broadcast(self, data: dict) -> None:
        if not self._clients:
            return
        payload = json.dumps(data)
        await asyncio.gather(
            *(c.send(payload) for c in self._clients),
            return_exceptions=True,
        )

    async def push_state(self, state: str, volume: float = 0.0, text: str = "") -> None:
        self._state = state
        if volume:
            self._volume = volume
        if text:
            self._text = text
        await self.broadcast({"state": state, "volume": self._volume, "text": text})


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

async def main() -> None:
    _load_env()

    # Initialize HA bridge + managers
    bridge = HomeBridge()
    entities = EntityManager(bridge)
    devices = DeviceManager(bridge)
    areas = AreaManager(bridge)
    actions = ActionDispatcher(bridge, entities, devices, areas)
    sync = SyncManager(bridge, entities, devices, areas)

    # GUI server
    gui = GUIServer(sync)
    sync.set_gui_broadcast(gui.broadcast)

    # Start GUI WS server
    gui_server = await websockets.serve(gui.handler, "localhost", 8765)
    logger.info("EXO GUI WebSocket server running on ws://localhost:8765")

    # Start HA bridge in background
    ha_token = os.environ.get("HA_TOKEN", "")
    if ha_token:
        ha_task = asyncio.create_task(bridge.start())
        logger.info("Home Assistant bridge starting...")
    else:
        ha_task = None
        logger.warning("HA_TOKEN not set — Home Assistant integration disabled")

    # Idle loop
    stop = asyncio.Event()

    def _signal_handler() -> None:
        stop.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, _signal_handler)
        except NotImplementedError:
            pass  # Windows

    logger.info("EXO server ready. Press Ctrl+C to stop.")

    try:
        await stop.wait()
    except KeyboardInterrupt:
        pass
    finally:
        logger.info("Shutting down...")
        gui_server.close()
        await gui_server.wait_closed()
        await bridge.stop()
        if ha_task:
            ha_task.cancel()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
