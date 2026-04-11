"""
memory_server.py — EXO Mémoire v2 Server

WebSocket server pour la mémoire sémantique EXO v2.
Délègue toute la logique au MemoryManager (architecture modulaire).

Modules v2 :
  - MemoryHierarchy : STM/MTM/LTM avec purge, TTL, capacité
  - VectorIndex : FAISS HNSW + SentenceTransformer
  - ConsolidationManager : promotion automatique, merge, purge
  - ContextEngine : contexte dynamique pour LLM
  - ConversationMemory : historique de session
  - FactualMemory : faits persistants

Protocole WS compatible v8 (backward compat) + extensions v2.

Port: 8771 (default)
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import sys
from pathlib import Path

# Singleton guard — prevent duplicate instances
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from shared.singleton_guard import ensure_single_instance
from shared.base_service import init_v9, json_loads, json_dumps

from memory.memory_manager import MemoryManager

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [MEM] %(levelname)s %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("exo.memory")

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

DEFAULT_HOST = "localhost"
DEFAULT_PORT = 8771
DEFAULT_MODEL = "all-MiniLM-L6-v2"
DEFAULT_DATA_DIR = os.environ.get(
    "EXO_FAISS_DIR",
    r"D:\EXO\faiss\semantic_memory",
)


# ---------------------------------------------------------------------------
# WebSocket handler
# ---------------------------------------------------------------------------

class MemorySession:
    """One WebSocket client session — delegates to MemoryManager."""

    def __init__(self, manager: MemoryManager) -> None:
        self.manager = manager

    async def handle(self, ws) -> None:
        logger.info("Memory client connected")

        st = self.manager.stats()
        tier_counts = {t: st["tiers"][t]["count"] for t in ("stm", "mtm", "ltm")}
        await ws.send(json.dumps({
            "type": "ready",
            "model": st["model"],
            "memories": st["count"],
            "tiers": tier_counts,
        }))

        try:
            async for message in ws:
                if isinstance(message, str):
                    await self._on_json(ws, message)
        except Exception as e:
            logger.error("Memory session error: %s", e)
        finally:
            logger.info("Memory client disconnected")

    async def _on_json(self, ws, raw: str) -> None:
        # v9.1: delegate standard protocol messages
        v9_resp = await _v9.handle_ws_message(ws, raw)
        if v9_resp is not None:
            await ws.send(v9_resp)
            return

        try:
            msg = json_loads(raw)
        except (ValueError, TypeError):
            return

        msg_type = msg.get("type", "")

        try:
            if msg_type == "add":
                entry = self.manager.add(
                    text=msg["text"],
                    importance=msg.get("importance", 0.5),
                    tags=msg.get("tags", []),
                    category=msg.get("category", ""),
                    source=msg.get("source", "user"),
                    ttl_days=msg.get("ttl_days", 0.0),
                    tier=msg.get("tier", "stm"),
                )
                if entry:
                    await ws.send(json.dumps({
                        "type": "added",
                        "id": entry.id,
                        "text": entry.text,
                        "tier": entry.tier,
                    }))
                else:
                    await ws.send(json.dumps({
                        "type": "duplicate",
                        "text": msg["text"][:80],
                    }))

            elif msg_type == "search":
                results = self.manager.search(
                    query=msg["query"],
                    top_k=msg.get("top_k", 5),
                    tiers=msg.get("tiers"),
                )
                await ws.send(json.dumps({
                    "type": "results",
                    "query": msg["query"],
                    "memories": results,
                }))

            elif msg_type == "remove":
                success = self.manager.remove(msg["id"])
                await ws.send(json.dumps({
                    "type": "removed",
                    "id": msg["id"],
                    "success": success,
                }))

            elif msg_type == "list":
                max_items = msg.get("max", 50)
                tier_filter = msg.get("tier", "all")
                if tier_filter == "all":
                    all_entries = self.manager.hierarchy.get_all()
                    memories = [e.to_dict() for e in all_entries[-max_items:]]
                else:
                    entries = self.manager.hierarchy.get_tier(tier_filter)
                    memories = [e.to_dict() for e in entries[-max_items:]]
                await ws.send(json.dumps({
                    "type": "results",
                    "memories": memories,
                }))

            elif msg_type == "clear":
                self.manager.clear()
                await ws.send(json.dumps({"type": "cleared"}))

            elif msg_type == "stats":
                await ws.send(json.dumps({
                    "type": "stats",
                    **self.manager.stats(),
                }))

            # ── Consolidation ────────────────────────

            elif msg_type == "consolidate":
                result = self.manager.consolidate()
                await ws.send(json.dumps({
                    "type": "consolidated",
                    **result,
                }))

            elif msg_type == "summarize":
                summaries = self.manager.summarize_text(msg["text"])
                await ws.send(json.dumps({
                    "type": "summary",
                    **summaries,
                }))

            elif msg_type == "reinforce":
                entry = self.manager.reinforce(
                    msg["id"], msg.get("boost", 0.1))
                if entry:
                    await ws.send(json.dumps({
                        "type": "reinforced",
                        "id": entry.id,
                        "importance": entry.importance,
                    }))
                else:
                    await ws.send(json.dumps({
                        "type": "error",
                        "message": f"Memory {msg['id']} not found",
                    }))

            elif msg_type == "weaken":
                entry = self.manager.weaken(
                    msg["id"], msg.get("decay", 0.1))
                if entry:
                    await ws.send(json.dumps({
                        "type": "weakened",
                        "id": entry.id,
                        "importance": entry.importance,
                    }))
                else:
                    await ws.send(json.dumps({
                        "type": "error",
                        "message": f"Memory {msg['id']} not found",
                    }))

            elif msg_type == "detect_contradictions":
                pairs = self.manager.detect_contradictions(msg["text"])
                await ws.send(json.dumps({
                    "type": "contradictions",
                    "pairs": pairs,
                }))

            # ── History & Promotion ──────────────────

            elif msg_type == "summarize_history":
                messages = msg.get("messages", [])
                result = self.manager.summarize_history(messages)
                await ws.send(json.dumps({
                    "type": "history_summary",
                    **result,
                }))

            elif msg_type == "promote":
                entry = self.manager.promote(
                    msg["id"], msg.get("target_tier", "mtm"))
                if entry:
                    await ws.send(json.dumps({
                        "type": "promoted",
                        "id": entry.id,
                        "tier": entry.tier,
                    }))
                else:
                    await ws.send(json.dumps({
                        "type": "error",
                        "message": f"Memory {msg['id']} not found or invalid tier",
                    }))

            elif msg_type == "tier_stats":
                ts = self.manager.tier_stats()
                await ws.send(json.dumps({
                    "type": "tier_stats",
                    **ts,
                }))

            # ── v2: Nouvelles opérations ─────────────

            elif msg_type == "build_context":
                context = self.manager.build_context(
                    query=msg["query"],
                    max_entries=msg.get("max_entries", 20),
                )
                await ws.send(json.dumps({
                    "type": "context",
                    "query": msg["query"],
                    "entries": context,
                }))

            elif msg_type == "add_fact":
                fact = self.manager.facts.add_fact(
                    key=msg["key"],
                    value=msg["value"],
                    category=msg.get("category", "general"),
                    source=msg.get("source", "user"),
                    confidence=msg.get("confidence", 1.0),
                )
                await ws.send(json.dumps({
                    "type": "fact_added",
                    **fact.to_dict(),
                }))

            elif msg_type == "get_fact":
                fact = self.manager.facts.get_fact(msg["key"])
                if fact:
                    await ws.send(json.dumps({
                        "type": "fact",
                        **fact.to_dict(),
                    }))
                else:
                    await ws.send(json.dumps({
                        "type": "error",
                        "message": f"Fact '{msg['key']}' not found",
                    }))

            elif msg_type == "conversation_turn":
                conv = self.manager.get_conversation(
                    msg.get("session_id", "default"))
                turn = conv.add_turn(
                    role=msg["role"],
                    text=msg["text"],
                    metadata=msg.get("metadata"),
                )
                await ws.send(json.dumps({
                    "type": "turn_added",
                    **turn.to_dict(),
                }))

            elif msg_type == "health":
                await ws.send(json.dumps({
                    "type": "health",
                    **self.manager.health_check(),
                }))

            elif msg_type == "metrics":
                await ws.send(json.dumps({
                    "type": "metrics",
                    **self.manager.metrics(),
                }))

        except Exception as e:
            logger.error("Memory operation error: %s", e)
            await ws.send(json.dumps({
                "type": "error",
                "message": str(e),
            }))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

async def main() -> None:
    global _v9

    import argparse

    parser = argparse.ArgumentParser(description="EXO Memory Server v2")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--model", default=DEFAULT_MODEL,
                        help="SentenceTransformer model name")
    parser.add_argument("--data-dir", default=DEFAULT_DATA_DIR,
                        help="Directory to store FAISS index and metadata")
    args = parser.parse_args()

    # Prevent duplicate instances
    ensure_single_instance(args.port, "memory_server")
    _v9 = init_v9("memory_server", args.port)

    manager = MemoryManager(
        model_name=args.model,
        data_dir=args.data_dir,
    )
    manager.load()

    async def handler(ws):
        session = MemorySession(manager)
        await session.handle(ws)

    try:
        import websockets
    except ImportError:
        logger.error("websockets not installed. Run: pip install websockets")
        return

    server = await websockets.serve(
        handler, args.host, args.port,
        **_v9.ws_serve_kwargs(),
    )
    total = len(manager.hierarchy.get_all())
    logger.info("Memory server v2 running on ws://%s:%d (model=%s, memories=%d)",
                args.host, args.port, args.model, total)

    try:
        await asyncio.Future()
    except KeyboardInterrupt:
        pass
    finally:
        manager.save()
        server.close()
        await server.wait_closed()
        logger.info("Memory server stopped")


if __name__ == "__main__":
    asyncio.run(main())
