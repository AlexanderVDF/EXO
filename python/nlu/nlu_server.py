#!/usr/bin/env python3
"""
EXO v4.2 — NLU Local Server (WebSocket)
Port 8772 — Compréhension locale des commandes simples

Modèles supportés (par ordre de recommandation) :
  1. Qwen2.5-1.5B-Instruct (excellent en français, léger)
  2. Phi-3-mini-4k-instruct (rapide, multi-langue)
  3. Fallback regex-based (toujours disponible)

Pipeline :
  transcript → NLU → { intent, entities, confidence }
  Si confidence > seuil → exécution directe (pas de Claude)
  Sinon → passage à Claude pour requêtes complexes

Protocol WebSocket :
  → JSON {"action":"classify","text":"allume la lumière du salon"}
  ← JSON {"type":"nlu_result","intent":"home_control","entities":{"device":"lumière","room":"salon","action":"on"},"confidence":0.92,"use_claude":false}
"""

import asyncio
import json
import logging
import re
import sys
import argparse
from pathlib import Path
from typing import Optional

try:
    import websockets
except ImportError:
    raise SystemExit("pip install websockets")

# Singleton guard — prevent duplicate instances
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from shared.singleton_guard import ensure_single_instance

logging.basicConfig(level=logging.INFO,
                    format="%(asctime)s [NLU] %(message)s")
log = logging.getLogger("nlu_server")

# ─────────────────────────────────────────────────────
#  Intent definitions — commandes locales reconnues
# ─────────────────────────────────────────────────────

INTENTS = {
    "weather": {
        "patterns": [
            r"(quel|quelle).*(temps|météo|température|meteo)",
            r"(il|va).*(pleuvoir|neiger|faire\s+(beau|chaud|froid))",
            r"(météo|meteo)\s+(à|au|en|de|du)",
            r"(prévisions?|forecast)",
        ],
        "entities": ["city", "date"],
    },
    "time": {
        "patterns": [
            r"(quelle\s+heure|l'heure|heure\s+(est|actuelle))",
            r"(quel\s+jour|quelle\s+date|date\s+(d'aujourd'hui|actuelle))",
        ],
        "entities": [],
    },
    "timer": {
        "patterns": [
            r"(mets?|lance|démarre?|start)\s+(un\s+)?(minuteur|timer|chrono)",
            r"(rappelle|réveille)[\s-]moi\s+(dans|en)\s+\d+",
        ],
        "entities": ["duration"],
    },
    "home_control": {
        "patterns": [
            r"(allume|éteins?|ouvre|ferme|monte|baisse|active|désactive)\s+(la|le|les|l'|l'|mon|ma|mes)\s+",
            r"(lumière|lampe|volet|store|chauffage|ventilateur|climatisation|clim)\s+(du|de la|des|de)\s+",
        ],
        "entities": ["device", "room", "action"],
    },
    "music": {
        "patterns": [
            r"(joue|mets?|lance|écoute)\s+(de\s+la\s+musique|une?\s+(chanson|morceau|playlist))",
            r"(spotify|musique|playlist|artiste|album)\s+",
            r"(volume)\s+(plus|moins|à|au)\s+",
            r"(pause|stop|suivant|précédent|reprend)",
        ],
        "entities": ["artist", "song", "action"],
    },
    "reminder": {
        "patterns": [
            r"(rappelle|n'oublie\s+pas|note|retiens)\s+",
            r"(ajoute|créer?|fais)\s+(une?\s+)?(rappel|note|tâche|todo)",
        ],
        "entities": ["text", "time"],
    },
    "greeting": {
        "patterns": [
            r"^(bonjour|salut|hey|coucou|bonsoir|hello|hi)\b",
            r"^(ça\s+va|comment\s+(ça\s+va|vas[\s-]tu|allez[\s-]vous))",
        ],
        "entities": [],
    },
    "goodbye": {
        "patterns": [
            r"(au\s+revoir|bonne\s+(nuit|soirée|journée)|à\s+(plus|bientôt|demain))",
            r"^(bye|ciao|tchao|salut)\b",
        ],
        "entities": [],
    },
}

# ─────────────────────────────────────────────────────
#  Regex-based NLU engine (always available fallback)
# ─────────────────────────────────────────────────────

class RegexNLU:
    """Lightweight regex-based intent classifier for common commands."""

    def __init__(self):
        self._compiled = {}
        for intent, data in INTENTS.items():
            self._compiled[intent] = [
                re.compile(p, re.IGNORECASE) for p in data["patterns"]
            ]

    def classify(self, text: str) -> dict:
        text_lower = text.lower().strip()
        best_intent = None
        best_score = 0.0

        for intent, patterns in self._compiled.items():
            for pat in patterns:
                m = pat.search(text_lower)
                if m:
                    # Score based on match length vs text length
                    match_len = m.end() - m.start()
                    score = min(0.95, 0.5 + 0.5 * match_len / max(len(text_lower), 1))
                    if score > best_score:
                        best_score = score
                        best_intent = intent

        if best_intent and best_score > 0.4:
            entities = self._extract_entities(text_lower, best_intent)
            return {
                "intent": best_intent,
                "entities": entities,
                "confidence": round(best_score, 3),
                "use_claude": best_score < 0.7,
                "engine": "regex",
            }

        return {
            "intent": "unknown",
            "entities": {},
            "confidence": 0.0,
            "use_claude": True,
            "engine": "regex",
        }

    def _extract_entities(self, text: str, intent: str) -> dict:
        entities = {}

        # Duration extraction (for timer/reminder)
        dur_match = re.search(r"(\d+)\s*(minute|min|seconde|sec|heure|h)\b", text)
        if dur_match:
            entities["duration_value"] = int(dur_match.group(1))
            entities["duration_unit"] = dur_match.group(2)

        # Room extraction for home_control
        rooms = ["salon", "chambre", "cuisine", "bureau", "salle de bain",
                 "garage", "jardin", "terrasse", "entrée", "couloir"]
        for room in rooms:
            if room in text:
                entities["room"] = room
                break

        # Device extraction for home_control
        devices = ["lumière", "lampe", "volet", "store", "chauffage",
                   "ventilateur", "climatisation", "clim", "télé", "tv"]
        for device in devices:
            if device in text:
                entities["device"] = device
                break

        # Action extraction
        if re.search(r"(allume|ouvre|monte|active|augmente)", text):
            entities["action"] = "on"
        elif re.search(r"(éteins?|ferme|baisse|désactive|diminue)", text):
            entities["action"] = "off"

        return entities


# ─────────────────────────────────────────────────────
#  Transformer-based NLU (optional, better accuracy)
# ─────────────────────────────────────────────────────

_transformer_nlu = None

def _try_load_transformer(model_name: str):
    """Try to load a small local LLM for NLU. Returns None if unavailable."""
    global _transformer_nlu
    try:
        from transformers import pipeline as hf_pipeline
        log.info(f"Loading local NLU model: {model_name}")
        _transformer_nlu = hf_pipeline(
            "text-classification",
            model=model_name,
            device="cpu",
            max_length=128,
            truncation=True,
        )
        log.info(f"Local NLU model loaded: {model_name}")
    except Exception as e:
        log.warning(f"Could not load transformer NLU ({model_name}): {e}")
        _transformer_nlu = None


# ─────────────────────────────────────────────────────
#  NLU Server — WebSocket handler
# ─────────────────────────────────────────────────────

regex_nlu = RegexNLU()
CONFIDENCE_THRESHOLD = 0.65  # above this → direct action (skip Claude)


async def handle_client(ws):
    remote = ws.remote_address
    log.info(f"Client connected: {remote}")
    try:
        async for raw in ws:
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                await ws.send(json.dumps({"type": "error", "message": "Invalid JSON"}))
                continue

            action = msg.get("action", "")

            if action == "classify":
                text = msg.get("text", "").strip()
                if not text:
                    await ws.send(json.dumps({"type": "error", "message": "Empty text"}))
                    continue

                result = regex_nlu.classify(text)
                result["type"] = "nlu_result"
                await ws.send(json.dumps(result, ensure_ascii=False))

            elif action == "ping":
                await ws.send(json.dumps({"type": "pong"}))

            elif action == "list_intents":
                intents = list(INTENTS.keys())
                await ws.send(json.dumps({"type": "intents", "intents": intents}))

            else:
                await ws.send(json.dumps({"type": "error", "message": f"Unknown action: {action}"}))

    except websockets.ConnectionClosed:
        pass
    finally:
        log.info(f"Client disconnected: {remote}")


async def main(host: str, port: int, model: Optional[str]):
    # Prevent duplicate instances
    ensure_single_instance(port, "nlu_server")

    if model:
        _try_load_transformer(model)

    log.info(f"NLU server starting on ws://{host}:{port}")
    async with websockets.serve(
        handle_client, host, port,
        ping_interval=None, ping_timeout=None,
    ):
        await asyncio.Future()  # run forever


if __name__ == "__main__":
    pa = argparse.ArgumentParser(description="EXO NLU Local Server")
    pa.add_argument("--host", default="localhost")
    pa.add_argument("--port", type=int, default=8772)
    pa.add_argument("--model", default=None,
                    help="HuggingFace model name for transformer NLU (optional)")
    args = pa.parse_args()
    asyncio.run(main(args.host, args.port, args.model))
