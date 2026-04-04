"""
memory_server.py — EXO v8 Semantic Memory Server (FAISS + SentenceTransformers)

WebSocket server that provides semantic memory storage and retrieval
using FAISS vector index and SentenceTransformers embeddings.

v8 additions (MemoryHierarchy):
  - 3-tier memory: STM (short-term buffer), MTM (medium-term), LTM (long-term)
  - HNSW index for faster searches on large collections
  - Automatic promotion: STM → MTM (after reinforcement) → LTM (after consolidation)
  - Tier-aware search with weighted fusion across all tiers
  - Summarize history: multi-turn conversation → facts for LTM
  - Scheduled consolidation with tier promotion

v7 features (kept):
  - TTL intelligent (expiration progressive)
  - Duplicate detection (cosine similarity threshold)
  - Memory fusion (merge similar memories)
  - Dynamic scoring (relevance × recency × importance)
  - Consolidation (batch cleanup)
  - Conversation summarization (hierarchical)

Protocol:
  → JSON:
    {"type": "add", "text": "...", "importance": 0.8, "tags": [...], "category": "...",
     "tier": "stm|mtm|ltm"}
    {"type": "search", "query": "...", "top_k": 5, "tiers": ["stm","mtm","ltm"]}
    {"type": "remove", "id": "..."}
    {"type": "list", "max": 50, "tier": "stm|mtm|ltm|all"}
    {"type": "clear"}
    {"type": "stats"}
    {"type": "consolidate"}
    {"type": "summarize", "text": "...", "level": "short|medium|long"}
    {"type": "summarize_history", "messages": [...]}
    {"type": "reinforce", "id": "...", "boost": 0.1}
    {"type": "weaken", "id": "...", "decay": 0.1}
    {"type": "detect_contradictions", "text": "..."}
    {"type": "promote", "id": "...", "target_tier": "mtm|ltm"}
    {"type": "tier_stats"}
  ← JSON:
    {"type": "ready", "model": "...", "memories": int, "tiers": {...}}
    {"type": "added", "id": "...", "text": "...", "tier": "..."}
    {"type": "results", "memories": [{id, text, score, importance, tags, category, tier}]}
    {"type": "removed", "id": "...", "success": bool}
    {"type": "stats", "count": int, "model": str, "tiers": {...}}
    {"type": "consolidated", "merged": int, "expired": int, "promoted": int, "total": int}
    {"type": "summary", "short": "...", "medium": "...", "long": "..."}
    {"type": "history_summary", "facts": [...], "stored": int}
    {"type": "reinforced", "id": "...", "importance": float}
    {"type": "weakened", "id": "...", "importance": float}
    {"type": "contradictions", "pairs": [...]}
    {"type": "promoted", "id": "...", "from_tier": "...", "to_tier": "..."}
    {"type": "tier_stats", "stm": {...}, "mtm": {...}, "ltm": {...}}
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
from shared.base_service import init_v9

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

# v8: Tier capacities
STM_MAX = 200    # Short-term buffer — recent, volatile
MTM_MAX = 2000   # Medium-term — reinforced, summarized
LTM_MAX = 10000  # Long-term — stable, consolidated facts

# v8: Promotion thresholds
STM_TO_MTM_REINFORCEMENTS = 2   # Promote after 2 reinforcements
MTM_TO_LTM_IMPORTANCE = 0.7     # Promote when importance >= 0.7
MTM_TO_LTM_AGE_DAYS = 7         # And age >= 7 days


# ---------------------------------------------------------------------------
# Memory entry
# ---------------------------------------------------------------------------

class MemoryEntry:
    __slots__ = ("id", "text", "importance", "tags", "category",
                 "source", "timestamp", "ttl_days", "access_count",
                 "last_accessed", "reinforcements", "tier")

    def __init__(self, text: str, importance: float = 0.5,
                 tags: list[str] | None = None,
                 category: str = "",
                 source: str = "user",
                 entry_id: str | None = None,
                 ttl_days: float = 0.0,
                 tier: str = "stm") -> None:
        self.id = entry_id or str(uuid.uuid4())
        self.text = text
        self.importance = max(0.0, min(1.0, importance))
        self.tags = tags or []
        self.category = category
        self.source = source
        self.timestamp = time.time()
        self.ttl_days = ttl_days  # 0 = no expiry
        self.access_count = 0
        self.last_accessed = self.timestamp
        self.reinforcements = 0
        self.tier = tier  # v8: stm, mtm, ltm

    def is_expired(self) -> bool:
        if self.ttl_days <= 0:
            return False
        age_days = (time.time() - self.timestamp) / 86400
        return age_days > self.ttl_days

    def touch(self) -> None:
        self.access_count += 1
        self.last_accessed = time.time()

    def reinforce(self, boost: float = 0.1) -> None:
        self.importance = min(1.0, self.importance + boost)
        self.reinforcements += 1
        self.touch()

    def weaken(self, decay: float = 0.1) -> None:
        self.importance = max(0.0, self.importance - decay)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "text": self.text,
            "importance": self.importance,
            "tags": self.tags,
            "category": self.category,
            "source": self.source,
            "timestamp": self.timestamp,
            "ttl_days": self.ttl_days,
            "access_count": self.access_count,
            "last_accessed": self.last_accessed,
            "reinforcements": self.reinforcements,
            "tier": self.tier,
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
            ttl_days=d.get("ttl_days", 0.0),
            tier=d.get("tier", "ltm"),
        )
        entry.timestamp = d.get("timestamp", time.time())
        entry.access_count = d.get("access_count", 0)
        entry.last_accessed = d.get("last_accessed", entry.timestamp)
        entry.reinforcements = d.get("reinforcements", 0)
        return entry


# ---------------------------------------------------------------------------
# Semantic Memory Store (FAISS + SentenceTransformers)
# ---------------------------------------------------------------------------

class SemanticMemory:
    """FAISS-backed semantic memory with 3-tier hierarchy (v8).

    Tiers:
      - STM (short-term): Recent memories, volatile, auto-expire
      - MTM (medium-term): Reinforced memories, summarized conversations
      - LTM (long-term): Stable facts, high-importance, consolidated
    """

    DUPLICATE_THRESHOLD = 0.92
    FUSION_THRESHOLD = 0.85

    def __init__(self, model_name: str = DEFAULT_MODEL,
                 data_dir: str = DEFAULT_DATA_DIR,
                 max_memories: int = MAX_MEMORIES) -> None:
        self._model_name = model_name
        self._data_dir = Path(data_dir)
        self._max_memories = max_memories
        self._encoder = None
        self._dim = 0
        # v8: Per-tier FAISS indices and memory lists
        self._tiers = ("stm", "mtm", "ltm")
        self._indices: dict[str, object] = {}      # tier → FAISS index
        self._memories: dict[str, list[MemoryEntry]] = {
            "stm": [], "mtm": [], "ltm": [],
        }
        # Legacy compat: flat list property
        self._index = None

    def load(self) -> None:
        """Load embedding model and existing data (v8: per-tier)."""
        t0 = time.monotonic()

        from sentence_transformers import SentenceTransformer
        import torch
        device = "cpu"
        if torch.cuda.is_available():
            n_gpus = torch.cuda.device_count()
            if n_gpus >= 2:
                device = "cuda:1"
                logger.info("GPU secondaire détecté: %s → embeddings sur cuda:1",
                            torch.cuda.get_device_name(1))
            else:
                device = "cuda:0"
                logger.info("GPU unique: %s → embeddings sur cuda:0",
                            torch.cuda.get_device_name(0))
        else:
            logger.info("Pas de GPU CUDA, embeddings sur CPU")
        self._encoder = SentenceTransformer(self._model_name, device=device)
        self._dim = self._encoder.get_sentence_embedding_dimension()
        logger.info("GPU Memory (embeddings): %s", device)

        import faiss
        self._data_dir.mkdir(parents=True, exist_ok=True)

        # v8: Try loading per-tier data, with migration from v7 flat format
        meta_v8 = self._data_dir / "metadata_v8.json"
        meta_v7 = self._data_dir / "metadata.json"

        if meta_v8.exists():
            # v8 format: per-tier indices and metadata
            with open(meta_v8, "r", encoding="utf-8") as f:
                data = json.load(f)
            for tier in self._tiers:
                tier_idx_path = self._data_dir / f"embeddings_{tier}.faiss"
                mems = [MemoryEntry.from_dict(m) for m in data.get(tier, [])]
                self._memories[tier] = mems
                if tier_idx_path.exists() and mems:
                    self._indices[tier] = faiss.read_index(str(tier_idx_path))
                else:
                    self._indices[tier] = self._create_index()
                    if mems:
                        self._rebuild_tier_index(tier)
            total = sum(len(m) for m in self._memories.values())
            logger.info("Loaded v8 memories: STM=%d MTM=%d LTM=%d (total=%d)",
                         len(self._memories["stm"]),
                         len(self._memories["mtm"]),
                         len(self._memories["ltm"]), total)
        elif meta_v7.exists():
            # Migrate v7 flat format → all memories go to LTM
            index_path = self._data_dir / "embeddings.faiss"
            with open(meta_v7, "r", encoding="utf-8") as f:
                data = json.load(f)
            old_mems = [MemoryEntry.from_dict(m) for m in data.get("memories", [])]
            for m in old_mems:
                m.tier = "ltm"
            self._memories["ltm"] = old_mems
            for tier in self._tiers:
                self._indices[tier] = self._create_index()
            if old_mems:
                self._rebuild_tier_index("ltm")
            self._memories["stm"] = []
            self._memories["mtm"] = []
            logger.info("Migrated %d v7 memories to LTM tier", len(old_mems))
            self.save()
        else:
            for tier in self._tiers:
                self._indices[tier] = self._create_index()
            logger.info("Created new v8 FAISS indices (dim=%d)", self._dim)

        # Legacy compat
        self._index = self._indices.get("ltm")

        dt = time.monotonic() - t0
        total = sum(len(m) for m in self._memories.values())
        logger.info("Semantic memory loaded in %.2fs (model=%s, dim=%d, total=%d)",
                     dt, self._model_name, self._dim, total)

    def _create_index(self):
        """Create a new FAISS HNSW+IP index for v8."""
        import faiss
        # Use HNSW for fast approximate search on larger collections
        # M=32 neighbors, efConstruction=200 for quality
        index = faiss.IndexHNSWFlat(self._dim, 32, faiss.METRIC_INNER_PRODUCT)
        index.hnsw.efConstruction = 200
        index.hnsw.efSearch = 64
        return index

    def save(self) -> None:
        """Persist per-tier indices and metadata to disk (v8)."""
        import faiss
        self._data_dir.mkdir(parents=True, exist_ok=True)

        # Save per-tier FAISS indices
        for tier in self._tiers:
            idx = self._indices.get(tier)
            if idx and idx.ntotal > 0:
                faiss.write_index(idx, str(self._data_dir / f"embeddings_{tier}.faiss"))

        # Save unified metadata with tier organization
        meta = {}
        for tier in self._tiers:
            meta[tier] = [m.to_dict() for m in self._memories[tier]]
        with open(self._data_dir / "metadata_v8.json", "w", encoding="utf-8") as f:
            json.dump(meta, f, ensure_ascii=False, indent=2)

        total = sum(len(m) for m in self._memories.values())
        logger.debug("Saved %d memories to disk (STM=%d MTM=%d LTM=%d)",
                      total, len(self._memories["stm"]),
                      len(self._memories["mtm"]), len(self._memories["ltm"]))

    def add(self, text: str, importance: float = 0.5,
            tags: list[str] | None = None,
            category: str = "",
            source: str = "user",
            ttl_days: float = 0.0,
            tier: str = "stm") -> MemoryEntry | None:
        """Add a new memory to the specified tier. Returns None if duplicate."""
        # v7: Duplicate detection (across all tiers)
        if self._is_duplicate(text):
            logger.info("Duplicate detected, skipping: %s", text[:60])
            return None

        # Validate tier
        if tier not in self._tiers:
            tier = "stm"

        entry = MemoryEntry(text, importance, tags, category, source,
                            ttl_days=ttl_days, tier=tier)

        # Encode and normalize
        embedding = self._encoder.encode([text], normalize_embeddings=True)
        self._indices[tier].add(embedding.astype(np.float32))
        self._memories[tier].append(entry)

        # Evict if tier is over capacity
        tier_max = {"stm": STM_MAX, "mtm": MTM_MAX, "ltm": LTM_MAX}
        while len(self._memories[tier]) > tier_max[tier]:
            self._evict_one_from(tier)

        self.save()
        logger.info("Added memory [%s/%s]: %s", tier, category, text[:60])
        return entry

    def search(self, query: str, top_k: int = 5,
               tiers: list[str] | None = None) -> list[dict]:
        """Semantic search with dynamic scoring across tiers (v8)."""
        search_tiers = tiers or list(self._tiers)
        query_emb = self._encoder.encode([query], normalize_embeddings=True)

        now = time.time()
        results = []

        # Tier weight: LTM memories are slightly boosted (more stable)
        tier_weight = {"stm": 0.9, "mtm": 1.0, "ltm": 1.1}

        for tier in search_tiers:
            mems = self._memories.get(tier, [])
            idx = self._indices.get(tier)
            if not mems or idx is None or idx.ntotal == 0:
                continue

            k = min(top_k * 3, idx.ntotal)
            scores, indices = idx.search(query_emb.astype(np.float32), k)

            for score, mem_idx in zip(scores[0], indices[0]):
                if mem_idx < 0 or mem_idx >= len(mems):
                    continue
                mem = mems[mem_idx]
                if mem.is_expired():
                    continue
                age_days = (now - mem.timestamp) / 86400
                recency = 1.0 / (1.0 + age_days / 30.0)
                access_boost = min(0.1, mem.access_count * 0.01)
                tw = tier_weight.get(tier, 1.0)
                dynamic_score = (float(score)
                                 * (0.5 + 0.3 * mem.importance + 0.2 * recency + access_boost)
                                 * tw)
                mem.touch()
                result = mem.to_dict()
                result["score"] = dynamic_score
                result["raw_similarity"] = float(score)
                results.append(result)

        results.sort(key=lambda r: r["score"], reverse=True)
        return results[:top_k]

    def remove(self, memory_id: str) -> bool:
        """Remove a memory by ID from any tier. Rebuilds tier index."""
        for tier in self._tiers:
            for i, m in enumerate(self._memories[tier]):
                if m.id == memory_id:
                    self._memories[tier].pop(i)
                    self._rebuild_tier_index(tier)
                    self.save()
                    return True
        return False

    def clear(self) -> None:
        """Clear all memories across all tiers."""
        for tier in self._tiers:
            self._memories[tier].clear()
            self._indices[tier] = self._create_index()
        self.save()
        logger.info("All memories cleared")

    def stats(self) -> dict:
        total = sum(len(m) for m in self._memories.values())
        tier_stats = {}
        for tier in self._tiers:
            idx = self._indices.get(tier)
            tier_stats[tier] = {
                "count": len(self._memories[tier]),
                "index_size": idx.ntotal if idx else 0,
            }
        return {
            "count": total,
            "model": self._model_name,
            "dim": self._dim,
            "tiers": tier_stats,
        }

    def _evict_one_from(self, tier: str) -> None:
        """Remove the least important / oldest memory from a tier."""
        mems = self._memories.get(tier, [])
        if not mems:
            return
        now = time.time()
        worst_idx = 0
        worst_score = float("inf")
        for i, m in enumerate(mems):
            age_days = (now - m.timestamp) / 86400
            recency = 1.0 / (1.0 + age_days / 30.0)
            effective = m.importance * recency
            if effective < worst_score:
                worst_score = effective
                worst_idx = i
        mems.pop(worst_idx)
        self._rebuild_tier_index(tier)

    def _rebuild_tier_index(self, tier: str) -> None:
        """Rebuild FAISS index for a specific tier."""
        self._indices[tier] = self._create_index()
        mems = self._memories.get(tier, [])
        if mems:
            texts = [m.text for m in mems]
            embeddings = self._encoder.encode(texts, normalize_embeddings=True)
            self._indices[tier].add(embeddings.astype(np.float32))

    def _rebuild_index(self) -> None:
        """Rebuild all tier indices (legacy compat + full rebuild)."""
        for tier in self._tiers:
            self._rebuild_tier_index(tier)

    # ── v7: Duplicate Detection ──────────────────────

    def _is_duplicate(self, text: str) -> bool:
        """Check if a very similar memory already exists in any tier."""
        emb = self._encoder.encode([text], normalize_embeddings=True)
        for tier in self._tiers:
            idx = self._indices.get(tier)
            if idx and idx.ntotal > 0:
                scores, _ = idx.search(emb.astype(np.float32), 1)
                if float(scores[0][0]) >= self.DUPLICATE_THRESHOLD:
                    return True
        return False

    # ── v7: Memory Reinforcement / Weakening ─────────

    def reinforce(self, memory_id: str, boost: float = 0.1) -> Optional[MemoryEntry]:
        """Reinforce a memory. Auto-promote STM→MTM after threshold."""
        for tier in self._tiers:
            for m in self._memories[tier]:
                if m.id == memory_id:
                    m.reinforce(boost)
                    # v8: Auto-promote STM → MTM after enough reinforcements
                    if (tier == "stm"
                            and m.reinforcements >= STM_TO_MTM_REINFORCEMENTS):
                        self._promote(m, "stm", "mtm")
                    self.save()
                    return m
        return None

    def weaken(self, memory_id: str, decay: float = 0.1) -> Optional[MemoryEntry]:
        """Weaken a less-useful memory."""
        for tier in self._tiers:
            for m in self._memories[tier]:
                if m.id == memory_id:
                    m.weaken(decay)
                    self.save()
                    return m
        return None

    # ── v8: Tier Promotion ───────────────────────────

    def _promote(self, entry: MemoryEntry, from_tier: str, to_tier: str) -> None:
        """Move a memory entry from one tier to another."""
        if entry in self._memories[from_tier]:
            self._memories[from_tier].remove(entry)
            entry.tier = to_tier
            embedding = self._encoder.encode([entry.text], normalize_embeddings=True)
            self._indices[to_tier].add(embedding.astype(np.float32))
            self._memories[to_tier].append(entry)
            self._rebuild_tier_index(from_tier)
            logger.info("Promoted memory %s: %s → %s", entry.id[:8], from_tier, to_tier)

    def promote(self, memory_id: str, target_tier: str) -> Optional[MemoryEntry]:
        """Manually promote a memory to a target tier."""
        if target_tier not in self._tiers:
            return None
        for tier in self._tiers:
            for m in self._memories[tier]:
                if m.id == memory_id:
                    if tier == target_tier:
                        return m  # already there
                    self._promote(m, tier, target_tier)
                    self.save()
                    return m
        return None

    # ── v7: Consolidation ────────────────────────────

    def consolidate(self) -> dict:
        """Consolidate memory: expire, merge similar, promote across tiers (v8)."""
        expired = 0
        merged = 0
        promoted = 0

        # 1. Remove expired memories from all tiers
        for tier in self._tiers:
            before = len(self._memories[tier])
            self._memories[tier] = [m for m in self._memories[tier] if not m.is_expired()]
            expired += before - len(self._memories[tier])

        # 2. Merge highly similar within each tier
        for tier in self._tiers:
            if len(self._memories[tier]) > 1:
                merged += self._merge_similar_in_tier(tier)

        # 3. v8: Auto-promote eligible memories
        #    MTM → LTM: high importance + old enough
        now = time.time()
        to_promote_ltm = []
        for m in self._memories["mtm"]:
            age_days = (now - m.timestamp) / 86400
            if m.importance >= MTM_TO_LTM_IMPORTANCE and age_days >= MTM_TO_LTM_AGE_DAYS:
                to_promote_ltm.append(m)
        for m in to_promote_ltm:
            self._promote(m, "mtm", "ltm")
            promoted += 1

        #    STM → MTM: enough reinforcements (already handled in reinforce())
        to_promote_mtm = []
        for m in self._memories["stm"]:
            if m.reinforcements >= STM_TO_MTM_REINFORCEMENTS:
                to_promote_mtm.append(m)
        for m in to_promote_mtm:
            self._promote(m, "stm", "mtm")
            promoted += 1

        # 4. Rebuild indices for any modified tiers
        if expired > 0 or merged > 0 or promoted > 0:
            self._rebuild_index()
            self.save()

        total = sum(len(m) for m in self._memories.values())
        logger.info("Consolidation: expired=%d, merged=%d, promoted=%d, total=%d",
                     expired, merged, promoted, total)
        return {"expired": expired, "merged": merged, "promoted": promoted, "total": total}

    def _merge_similar_in_tier(self, tier: str) -> int:
        """Merge memories with similarity > FUSION_THRESHOLD within a tier."""
        mems = self._memories[tier]
        if len(mems) < 2:
            return 0

        texts = [m.text for m in mems]
        embeddings = self._encoder.encode(texts, normalize_embeddings=True)

        merged_ids: set[int] = set()
        merge_count = 0

        for i in range(len(mems)):
            if i in merged_ids:
                continue
            for j in range(i + 1, len(mems)):
                if j in merged_ids:
                    continue
                sim = float(np.dot(embeddings[i], embeddings[j]))
                if sim >= self.FUSION_THRESHOLD:
                    mi, mj = mems[i], mems[j]
                    mi.importance = max(mi.importance, mj.importance)
                    mi.tags = list(set(mi.tags + mj.tags))
                    mi.access_count += mj.access_count
                    if len(mj.text) > len(mi.text):
                        mi.text = mj.text
                    merged_ids.add(j)
                    merge_count += 1

        if merged_ids:
            self._memories[tier] = [m for i, m in enumerate(mems) if i not in merged_ids]

        return merge_count

    # ── v7: Contradiction Detection ──────────────────

    def detect_contradictions(self, text: str) -> list[dict]:
        """Find memories that might contradict the given text (all tiers)."""
        emb = self._encoder.encode([text], normalize_embeddings=True)
        pairs = []

        for tier in self._tiers:
            mems = self._memories[tier]
            idx = self._indices.get(tier)
            if not mems or idx is None or idx.ntotal == 0:
                continue
            k = min(10, idx.ntotal)
            scores, indices = idx.search(emb.astype(np.float32), k)
            for score, mem_idx in zip(scores[0], indices[0]):
                if mem_idx < 0 or mem_idx >= len(mems):
                    continue
                sim = float(score)
                if 0.4 <= sim <= 0.75:
                    mem = mems[mem_idx]
                    pairs.append({
                        "id": mem.id,
                        "text": mem.text,
                        "similarity": sim,
                        "importance": mem.importance,
                        "tier": tier,
                    })

        return pairs

    # ── v7: Conversation Summarization ───────────────

    def summarize_text(self, text: str) -> dict:
        """Generate hierarchical summaries using embedding-based extraction."""
        sentences = [s.strip() for s in text.replace("\n", ". ").split(".")
                     if s.strip() and len(s.strip()) > 10]

        if not sentences:
            return {"short": text[:100], "medium": text[:500], "long": text}

        # Encode all sentences
        embs = self._encoder.encode(sentences, normalize_embeddings=True)
        # Compute centroid
        centroid = embs.mean(axis=0, keepdims=True)
        centroid = centroid / (np.linalg.norm(centroid) + 1e-8)
        # Rank by similarity to centroid (most representative)
        sims = (embs @ centroid.T).flatten()
        ranked = sorted(range(len(sentences)), key=lambda i: sims[i], reverse=True)

        # Short: top 1-2 sentences
        short_sents = [sentences[i] for i in sorted(ranked[:2])]
        short = ". ".join(short_sents) + "."

        # Medium: top 5-6 sentences
        n_med = min(6, len(ranked))
        med_sents = [sentences[i] for i in sorted(ranked[:n_med])]
        medium = ". ".join(med_sents) + "."

        # Long: top 12 or all
        n_long = min(12, len(ranked))
        long_sents = [sentences[i] for i in sorted(ranked[:n_long])]
        long_text = ". ".join(long_sents) + "."

        return {"short": short, "medium": medium, "long": long_text}

    # ── v8: Conversation History → Facts ─────────────

    def summarize_history(self, messages: list[dict]) -> dict:
        """Extract key facts from a conversation and store them in MTM.

        Each message: {"role": "user"|"assistant", "content": "..."}
        Returns extracted facts and how many were stored.
        """
        if not messages:
            return {"facts": [], "stored": 0}

        # Build a single text from the conversation
        lines = []
        for msg in messages:
            role = msg.get("role", "user")
            content = msg.get("content", "")
            lines.append(f"{role}: {content}")
        full_text = "\n".join(lines)

        # Use extractive summarization to find key sentences
        sentences = [s.strip() for s in full_text.replace("\n", ". ").split(".")
                     if s.strip() and len(s.strip()) > 15]

        if not sentences:
            return {"facts": [], "stored": 0}

        embs = self._encoder.encode(sentences, normalize_embeddings=True)
        centroid = embs.mean(axis=0, keepdims=True)
        centroid = centroid / (np.linalg.norm(centroid) + 1e-8)
        sims = (embs @ centroid.T).flatten()

        # Extract top facts (most representative sentences)
        n_facts = min(8, len(sentences))
        ranked = sorted(range(len(sentences)), key=lambda i: sims[i], reverse=True)
        facts = [sentences[i] for i in sorted(ranked[:n_facts])]

        # Store each fact as MTM memory
        stored = 0
        for fact in facts:
            # Clean up role prefixes
            clean = fact
            for prefix in ("user:", "assistant:"):
                if clean.lower().startswith(prefix):
                    clean = clean[len(prefix):].strip()
            if len(clean) < 10:
                continue
            entry = self.add(
                text=clean,
                importance=0.6,
                tags=["conversation_fact", "auto_extracted"],
                category="conversation",
                source="summarizer",
                tier="mtm",
            )
            if entry:
                stored += 1

        logger.info("History summarization: %d facts extracted, %d stored in MTM",
                     len(facts), stored)
        return {"facts": facts, "stored": stored}


# ---------------------------------------------------------------------------
# WebSocket handler
# ---------------------------------------------------------------------------

class MemorySession:
    """One WebSocket client session."""

    def __init__(self, memory: SemanticMemory) -> None:
        self.memory = memory

    async def handle(self, ws) -> None:
        logger.info("Memory client connected")

        total = sum(len(m) for m in self.memory._memories.values())
        tier_stats = {t: len(self.memory._memories[t]) for t in self.memory._tiers}
        await ws.send(json.dumps({
            "type": "ready",
            "model": self.memory._model_name,
            "memories": total,
            "tiers": tier_stats,
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
                results = self.memory.search(
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
                success = self.memory.remove(msg["id"])
                await ws.send(json.dumps({
                    "type": "removed",
                    "id": msg["id"],
                    "success": success,
                }))

            elif msg_type == "list":
                max_items = msg.get("max", 50)
                tier_filter = msg.get("tier", "all")
                if tier_filter == "all":
                    all_mems = []
                    for t in self.memory._tiers:
                        all_mems.extend(self.memory._memories[t])
                    memories = [m.to_dict() for m in all_mems[-max_items:]]
                else:
                    mems = self.memory._memories.get(tier_filter, [])
                    memories = [m.to_dict() for m in mems[-max_items:]]
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

            # ── v7: New operations ───────────────────

            elif msg_type == "consolidate":
                result = self.memory.consolidate()
                await ws.send(json.dumps({
                    "type": "consolidated",
                    **result,
                }))

            elif msg_type == "summarize":
                summaries = self.memory.summarize_text(msg["text"])
                await ws.send(json.dumps({
                    "type": "summary",
                    **summaries,
                }))

            elif msg_type == "reinforce":
                entry = self.memory.reinforce(
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
                entry = self.memory.weaken(
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
                pairs = self.memory.detect_contradictions(msg["text"])
                await ws.send(json.dumps({
                    "type": "contradictions",
                    "pairs": pairs,
                }))

            # ── v8: New operations ───────────────────

            elif msg_type == "summarize_history":
                messages = msg.get("messages", [])
                result = self.memory.summarize_history(messages)
                await ws.send(json.dumps({
                    "type": "history_summary",
                    **result,
                }))

            elif msg_type == "promote":
                entry = self.memory.promote(
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
                tier_data = {}
                for t in self.memory._tiers:
                    mems = self.memory._memories[t]
                    idx = self.memory._indices.get(t)
                    tier_data[t] = {
                        "count": len(mems),
                        "index_size": idx.ntotal if idx else 0,
                        "avg_importance": (
                            sum(m.importance for m in mems) / len(mems)
                            if mems else 0.0
                        ),
                    }
                await ws.send(json.dumps({
                    "type": "tier_stats",
                    **tier_data,
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
    _v9 = init_v9("memory_server", args.port)

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
