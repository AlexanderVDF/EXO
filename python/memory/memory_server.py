"""
memory_server.py — EXO Semantic Memory Server (FAISS + SentenceTransformers)

WebSocket server that provides semantic memory storage and retrieval
using FAISS vector index and SentenceTransformers embeddings.

Protocol:
  → JSON:
    {"type": "add", "text": "...", "importance": 0.8, "tags": [...], "category": "..."}
    {"type": "search", "query": "...", "top_k": 5}
    {"type": "remove", "id": "..."}
    {"type": "list", "max": 50}
    {"type": "clear"}
    {"type": "stats"}
  ← JSON:
    {"type": "ready", "model": "...", "memories": int}
    {"type": "added", "id": "...", "text": "..."}
    {"type": "results", "memories": [{id, text, score, importance, tags, category}]}
    {"type": "removed", "id": "...", "success": bool}
    {"type": "stats", "count": int, "model": str}
    {"type": "error", "message": "..."}

Port: 8771 (default)

Dependencies:
  pip install websockets faiss-cpu sentence-transformers numpy
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import sys
import time
import uuid
from pathlib import Path
from typing import Optional

import numpy as np

# Singleton guard — prevent duplicate instances
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from shared.singleton_guard import ensure_single_instance

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
DEFAULT_MODEL = "all-MiniLM-L6-v2"  # Fast, good quality, 384-dim
DEFAULT_DATA_DIR = os.environ.get(
    "EXO_FAISS_DIR",
    r"D:\EXO\faiss\semantic_memory",
)
MAX_MEMORIES = 10000


# ---------------------------------------------------------------------------
# Memory entry
# ---------------------------------------------------------------------------

class MemoryEntry:
    __slots__ = ("id", "text", "importance", "tags", "category",
                 "source", "timestamp")

    def __init__(self, text: str, importance: float = 0.5,
                 tags: list[str] | None = None,
                 category: str = "",
                 source: str = "user",
                 entry_id: str | None = None) -> None:
        self.id = entry_id or str(uuid.uuid4())
        self.text = text
        self.importance = max(0.0, min(1.0, importance))
        self.tags = tags or []
        self.category = category
        self.source = source
        self.timestamp = time.time()

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "text": self.text,
            "importance": self.importance,
            "tags": self.tags,
            "category": self.category,
            "source": self.source,
            "timestamp": self.timestamp,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "MemoryEntry":
        entry = cls(
            text=d["text"],
            importance=d.get("importance", 0.5),
            tags=d.get("tags", []),
            category=d.get("category", ""),
            source=d.get("source", "user"),
            entry_id=d.get("id"),
        )
        entry.timestamp = d.get("timestamp", time.time())
        return entry


# ---------------------------------------------------------------------------
# Semantic Memory Store (FAISS + SentenceTransformers)
# ---------------------------------------------------------------------------

class SemanticMemory:
    """FAISS-backed semantic memory with SentenceTransformer embeddings."""

    def __init__(self, model_name: str = DEFAULT_MODEL,
                 data_dir: str = DEFAULT_DATA_DIR,
                 max_memories: int = MAX_MEMORIES) -> None:
        self._model_name = model_name
        self._data_dir = Path(data_dir)
        self._max_memories = max_memories
        self._encoder = None
        self._index = None
        self._memories: list[MemoryEntry] = []
        self._dim = 0

    def load(self) -> None:
        """Load embedding model and existing data."""
        t0 = time.monotonic()

        # Load SentenceTransformer
        from sentence_transformers import SentenceTransformer
        self._encoder = SentenceTransformer(self._model_name)
        self._dim = self._encoder.get_sentence_embedding_dimension()

        # Initialize or load FAISS index
        import faiss
        self._data_dir.mkdir(parents=True, exist_ok=True)
        index_path = self._data_dir / "embeddings.faiss"
        meta_path = self._data_dir / "metadata.json"

        if index_path.exists() and meta_path.exists():
            self._index = faiss.read_index(str(index_path))
            with open(meta_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            self._memories = [MemoryEntry.from_dict(m) for m in data.get("memories", [])]
            logger.info("Loaded %d memories from disk", len(self._memories))
        else:
            self._index = faiss.IndexFlatIP(self._dim)  # Inner Product (cosine sim with normalized vectors)
            logger.info("Created new FAISS index (dim=%d)", self._dim)

        dt = time.monotonic() - t0
        logger.info("Semantic memory loaded in %.2fs (model=%s, dim=%d, count=%d)",
                     dt, self._model_name, self._dim, len(self._memories))

    def save(self) -> None:
        """Persist index and metadata to disk."""
        import faiss
        self._data_dir.mkdir(parents=True, exist_ok=True)

        faiss.write_index(self._index, str(self._data_dir / "embeddings.faiss"))
        with open(self._data_dir / "metadata.json", "w", encoding="utf-8") as f:
            json.dump(
                {"memories": [m.to_dict() for m in self._memories]},
                f, ensure_ascii=False, indent=2
            )
        logger.debug("Saved %d memories to disk", len(self._memories))

    def add(self, text: str, importance: float = 0.5,
            tags: list[str] | None = None,
            category: str = "",
            source: str = "user") -> MemoryEntry:
        """Add a new memory and index its embedding."""
        entry = MemoryEntry(text, importance, tags, category, source)

        # Encode and normalize
        embedding = self._encoder.encode([text], normalize_embeddings=True)
        self._index.add(embedding.astype(np.float32))
        self._memories.append(entry)

        # Evict oldest low-importance if at capacity
        if len(self._memories) > self._max_memories:
            self._evict_one()

        self.save()
        logger.info("Added memory [%s]: %s", category, text[:60])
        return entry

    def search(self, query: str, top_k: int = 5) -> list[dict]:
        """Semantic search. Returns memories ranked by relevance."""
        if not self._memories or self._index.ntotal == 0:
            return []

        query_emb = self._encoder.encode([query], normalize_embeddings=True)
        k = min(top_k, self._index.ntotal)
        scores, indices = self._index.search(query_emb.astype(np.float32), k)

        results = []
        for score, idx in zip(scores[0], indices[0]):
            if idx < 0 or idx >= len(self._memories):
                continue
            mem = self._memories[idx]
            result = mem.to_dict()
            result["score"] = float(score)
            results.append(result)

        return results

    def remove(self, memory_id: str) -> bool:
        """Remove a memory by ID. Rebuilds index."""
        idx = None
        for i, m in enumerate(self._memories):
            if m.id == memory_id:
                idx = i
                break

        if idx is None:
            return False

        self._memories.pop(idx)
        self._rebuild_index()
        self.save()
        return True

    def clear(self) -> None:
        """Clear all memories."""
        import faiss
        self._memories.clear()
        self._index = faiss.IndexFlatIP(self._dim)
        self.save()
        logger.info("All memories cleared")

    def stats(self) -> dict:
        return {
            "count": len(self._memories),
            "model": self._model_name,
            "dim": self._dim,
            "index_size": self._index.ntotal if self._index else 0,
        }

    def _evict_one(self) -> None:
        """Remove the least important / oldest memory."""
        if not self._memories:
            return
        # Score = importance * recency_factor
        now = time.time()
        worst_idx = 0
        worst_score = float("inf")
        for i, m in enumerate(self._memories):
            age_days = (now - m.timestamp) / 86400
            recency = 1.0 / (1.0 + age_days / 30.0)
            effective = m.importance * recency
            if effective < worst_score:
                worst_score = effective
                worst_idx = i

        self._memories.pop(worst_idx)
        self._rebuild_index()

    def _rebuild_index(self) -> None:
        """Rebuild FAISS index from current memories."""
        import faiss
        self._index = faiss.IndexFlatIP(self._dim)
        if self._memories:
            texts = [m.text for m in self._memories]
            embeddings = self._encoder.encode(texts, normalize_embeddings=True)
            self._index.add(embeddings.astype(np.float32))


# ---------------------------------------------------------------------------
# WebSocket handler
# ---------------------------------------------------------------------------

class MemorySession:
    """One WebSocket client session."""

    def __init__(self, memory: SemanticMemory) -> None:
        self.memory = memory

    async def handle(self, ws) -> None:
        logger.info("Memory client connected")

        await ws.send(json.dumps({
            "type": "ready",
            "model": self.memory._model_name,
            "memories": len(self.memory._memories),
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
        try:
            msg = json.loads(raw)
        except json.JSONDecodeError:
            return

        msg_type = msg.get("type", "")

        if msg_type == "ping":
            await ws.send(json.dumps({"type": "pong"}))
            return

        try:
            if msg_type == "add":
                entry = self.memory.add(
                    text=msg["text"],
                    importance=msg.get("importance", 0.5),
                    tags=msg.get("tags", []),
                    category=msg.get("category", ""),
                    source=msg.get("source", "user"),
                )
                await ws.send(json.dumps({
                    "type": "added",
                    "id": entry.id,
                    "text": entry.text,
                }))

            elif msg_type == "search":
                results = self.memory.search(
                    query=msg["query"],
                    top_k=msg.get("top_k", 5),
                )
                await ws.send(json.dumps({
                    "type": "results",
                    "query": msg["query"],
                    "memories": results,
                }))

            elif msg_type == "remove":
                success = self.memory.remove(msg["id"])
                await ws.send(json.dumps({
                    "type": "removed",
                    "id": msg["id"],
                    "success": success,
                }))

            elif msg_type == "list":
                max_items = msg.get("max", 50)
                memories = [m.to_dict() for m in self.memory._memories[-max_items:]]
                await ws.send(json.dumps({
                    "type": "results",
                    "memories": memories,
                }))

            elif msg_type == "clear":
                self.memory.clear()
                await ws.send(json.dumps({"type": "cleared"}))

            elif msg_type == "stats":
                await ws.send(json.dumps({
                    "type": "stats",
                    **self.memory.stats(),
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
    import argparse

    parser = argparse.ArgumentParser(description="EXO Semantic Memory Server")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--model", default=DEFAULT_MODEL,
                        help="SentenceTransformer model name")
    parser.add_argument("--data-dir", default=DEFAULT_DATA_DIR,
                        help="Directory to store FAISS index and metadata")
    args = parser.parse_args()

    # Prevent duplicate instances
    ensure_single_instance(args.port, "memory_server")

    memory = SemanticMemory(
        model_name=args.model,
        data_dir=args.data_dir,
    )
    memory.load()

    async def handler(ws):
        session = MemorySession(memory)
        await session.handle(ws)

    try:
        import websockets
    except ImportError:
        logger.error("websockets not installed. Run: pip install websockets")
        return

    server = await websockets.serve(
        handler, args.host, args.port,
        ping_interval=None, ping_timeout=None,
    )
    logger.info("Memory server running on ws://%s:%d (model=%s, memories=%d)",
                args.host, args.port, args.model, len(memory._memories))

    try:
        await asyncio.Future()
    except KeyboardInterrupt:
        pass
    finally:
        memory.save()
        server.close()
        await server.wait_closed()
        logger.info("Memory server stopped")


if __name__ == "__main__":
    asyncio.run(main())
