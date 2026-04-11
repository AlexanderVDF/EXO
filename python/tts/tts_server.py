"""
tts_server.py — EXO TTS Streaming Server (CosyVoice 2)

WebSocket server using CosyVoice2-0.5B for high-quality neural TTS.
Returns synthesized audio as PCM16 24kHz mono chunks.

Protocol:
  → JSON:   {"type": "synthesize", "text": "...", "voice": "exo_default",
             "lang": "fr", "rate": 1.0, "pitch": 1.0, "style": "neutral"}
             {"type": "cancel"}
             {"type": "list_voices"}
  ← Binary: PCM16 audio chunks (streamed)
  ← JSON:   {"type": "start",  "text": "...", "estimated_duration": float}
             {"type": "end",    "duration": float}
             {"type": "voices", "available": [...]}
             {"type": "ready",  "voice": "...", "sample_rate": 24000}
             {"type": "error",  "message": "..."}

Dependencies:
  pip install cosyvoice torch torchaudio websockets numpy soundfile
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import sys
import time
from pathlib import Path
from typing import Optional

import numpy as np

# Singleton guard — prevent duplicate instances
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from shared.singleton_guard import ensure_single_instance
from shared.base_service import init_v9, json_loads, json_dumps

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [TTS] %(levelname)s %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("exo.tts")

# ---------------------------------------------------------------------------
# Configuration defaults
# ---------------------------------------------------------------------------

DEFAULT_HOST = "localhost"
DEFAULT_PORT = 8767
DEFAULT_VOICE = "exo_default"
DEFAULT_LANG = "fr"
OUTPUT_SAMPLE_RATE = 24000  # C++ TTSManager expects 24kHz PCM16 mono
CHUNK_SIZE = 256            # 128 frames × 2 bytes — ~5.3ms @ 24kHz mono16

SUPPORTED_LANGUAGES = [
    "en", "es", "fr", "de", "it", "pt", "pl", "tr",
    "ru", "nl", "cs", "ar", "zh-cn", "hu", "ko", "ja", "hi",
]

# Regex to strip emojis before synthesis
_EMOJI_RE = re.compile(
    r"[\U0001F600-\U0001F64F"   # emoticons
    r"\U0001F300-\U0001F5FF"    # symbols & pictographs
    r"\U0001F680-\U0001F6FF"    # transport & map
    r"\U0001F1E0-\U0001F1FF"    # flags
    r"\U00002702-\U000027B0"    # dingbats
    r"\U000024C2-\U0001F251"    # misc
    r"\U0001F900-\U0001F9FF"    # supplemental symbols
    r"\U0001FA00-\U0001FA6F"    # chess symbols
    r"\U0001FA70-\U0001FAFF"    # symbols extended-A
    r"\U00002600-\U000026FF"    # misc symbols
    r"\U0000FE00-\U0000FE0F"   # variation selectors
    r"\U0000200D"               # zero-width joiner
    r"]+"
)

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from shared.cache import PhraseCache

# CosyVoice 2 engine
from cosyvoice_engine import CosyVoiceEngine


# ---------------------------------------------------------------------------
# Helpers (text cleaning, param resolution)
# ---------------------------------------------------------------------------

def _clean_text(text: str) -> str:
    """Strip emojis and whitespace from text."""
    return _EMOJI_RE.sub("", text).strip()


def _resolve_params(
    engine: CosyVoiceEngine, voice: Optional[str], lang: Optional[str],
):
    voices = engine.list_voices()
    use_voice = voice if voice and voice in voices else engine.voice_name
    use_lang = lang if lang and lang in SUPPORTED_LANGUAGES else engine.language
    return use_voice, use_lang


# ---------------------------------------------------------------------------
# WebSocket session handler
# ---------------------------------------------------------------------------

class TTSSession:
    """One WebSocket client session."""

    def __init__(self, engine: CosyVoiceEngine) -> None:
        self.engine = engine
        self._cancel_flag = False

    async def handle(self, ws) -> None:
        """Handle a WebSocket connection."""
        logger.info("TTS client connected")

        # Send current phase as ready message
        await ws.send(json.dumps({
            "type": "ready",
            "phase": self.engine.phase,
            "voice": self.engine.voice_name,
            "sample_rate": OUTPUT_SAMPLE_RATE,
            "backend": "cosyvoice2",
            "languages": SUPPORTED_LANGUAGES,
            "profile": self.engine._profile,
        }))

        try:
            async for message in ws:
                if isinstance(message, str):
                    await self._on_json(ws, message)
        except Exception as e:
            logger.error("Session error: %s", e)
        finally:
            logger.info("TTS client disconnected")

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

        if msg_type == "synthesize":
            text = msg.get("text", "")
            voice = msg.get("voice", None)
            lang = msg.get("lang", None)
            rate = float(msg.get("rate", 1.0))
            pitch = float(msg.get("pitch", 1.0))

            if not text.strip():
                await ws.send(json.dumps({"type": "error", "message": "Empty text"}))
                return

            self._cancel_flag = False
            await self._synthesize_and_stream(ws, text, voice, lang, rate, pitch)

        elif msg_type == "cancel":
            self._cancel_flag = True
            logger.debug("Synthesis cancelled")

        elif msg_type == "list_voices":
            await ws.send(json.dumps({
                "type": "voices",
                "available": self.engine.list_voices(),
            }))

        elif msg_type == "set_voice":
            voice = msg.get("voice", "")
            ok = self.engine.set_voice(voice)
            await ws.send(json.dumps({
                "type": "voice_changed",
                "voice": self.engine.voice_name,
                "success": ok,
            }))

        elif msg_type == "set_language":
            lang = msg.get("lang", "")
            self.engine.set_language(lang)
            await ws.send(json.dumps({
                "type": "language_changed",
                "lang": self.engine.language,
            }))

    async def _synthesize_and_stream(
        self, ws, text: str, voice: Optional[str],
        lang: Optional[str], rate: float, pitch: float,
    ) -> None:
        """Synthesize and stream audio — uses CosyVoice2 streaming for low latency."""
        try:
            # Clean text for cache lookup
            clean = _clean_text(text)
            if not clean:
                await ws.send(json.dumps({"type": "error", "message": "Empty text after cleaning"}))
                return

            use_voice, use_lang = _resolve_params(self.engine, voice, lang)

            # Check cache first — instant send if cached
            cached = self.engine._cache.get(clean, use_voice, use_lang)
            if cached is not None:
                logger.info("Cache hit: %s", clean[:40])
                chunk_sz = getattr(self.engine, "_ws_chunk_size", CHUNK_SIZE)
                await ws.send(json.dumps({"type": "start", "text": text}))
                offset = 0
                while offset < len(cached):
                    if self._cancel_flag:
                        return
                    chunk = cached[offset : offset + chunk_sz]
                    await ws.send(chunk)
                    offset += chunk_sz
                    await asyncio.sleep(0)
                duration = len(cached) / (OUTPUT_SAMPLE_RATE * 2)
                await ws.send(json.dumps({
                    "type": "end",
                    "duration": round(duration, 2),
                    "synth_ms": 0,
                    "cached": True,
                }))
                return

            # ── Streaming synthesis ──
            await ws.send(json.dumps({"type": "start", "text": text}))

            loop = asyncio.get_event_loop()
            queue: asyncio.Queue = asyncio.Queue()
            all_pcm = bytearray()  # Accumulate for cache

            def _stream_worker():
                """Run CosyVoice2 streaming synthesis in thread, push chunks to async queue."""
                chunk_sz = getattr(self.engine, "_ws_chunk_size", CHUNK_SIZE)
                try:
                    for pcm_chunk in self.engine.synthesize_stream(
                        text, voice, lang, rate
                    ):
                        if self._cancel_flag:
                            break
                        all_pcm.extend(pcm_chunk)
                        # Split into chunk_sz frames for WebSocket
                        off = 0
                        while off < len(pcm_chunk):
                            frame = pcm_chunk[off : off + chunk_sz]
                            loop.call_soon_threadsafe(queue.put_nowait, frame)
                            off += chunk_sz
                except Exception as e:
                    import traceback
                    logger.error("Stream worker error: %s\n%s", e, traceback.format_exc())
                finally:
                    loop.call_soon_threadsafe(queue.put_nowait, None)

            t0 = time.monotonic()
            fut = loop.run_in_executor(None, _stream_worker)

            total_bytes = 0
            first_ws_sent = False
            while True:
                chunk = await queue.get()
                if chunk is None:
                    break
                if self._cancel_flag:
                    break
                await ws.send(chunk)
                total_bytes += len(chunk)
                if not first_ws_sent:
                    first_ws_sent = True
                    fc_ms = (time.monotonic() - t0) * 1000
                    logger.info("[Latency] TTS first-chunk WS: %.0f ms", fc_ms)
                await asyncio.sleep(0)  # Yield to event loop

            await fut  # Ensure thread completed

            synth_ms = (time.monotonic() - t0) * 1000
            duration = total_bytes / (OUTPUT_SAMPLE_RATE * 2)
            logger.info(
                "[Latency] TTS: %.0f ms (audio=%.1fs, %d bytes) text=%s",
                synth_ms, duration, total_bytes, text[:60],
            )
            if synth_ms > 1200:
                logger.warning("[Latency] TTS exceeded target (%.0f ms > 1200 ms)", synth_ms)

            # Cache the result for future calls
            if all_pcm and not self._cancel_flag:
                self.engine._cache.put(clean, use_voice, use_lang, bytes(all_pcm))

            if not self._cancel_flag:
                await ws.send(json.dumps({
                    "type": "end",
                    "duration": round(duration, 2),
                    "synth_ms": round(synth_ms),
                }))

        except Exception as e:
            logger.error("Synthesis error: %s", e)
            try:
                await ws.send(json.dumps({
                    "type": "error",
                    "message": str(e),
                }))
            except Exception:
                pass


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

async def main() -> None:
    global _v9

    import argparse

    parser = argparse.ArgumentParser(description="EXO TTS Server (CosyVoice 2)")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--voice", default=DEFAULT_VOICE,
                        help="CosyVoice2 speaker or prompt name")
    parser.add_argument("--lang", default=DEFAULT_LANG,
                        help="Default language (e.g. fr, en, de)")
    parser.add_argument("--streaming", action="store_true",
                        help="Enable streaming mode (default behavior)")
    parser.add_argument("--chunk-size", type=int, default=CHUNK_SIZE,
                        help="Audio chunk size in bytes for WS frames")
    parser.add_argument("--max-chunk-length", type=int, default=4096,
                        help="Max text char length per single inference call")
    parser.add_argument("--latency-optimized", action="store_true",
                        help="Low-latency mode: merge sentences, larger chunks")
    args = parser.parse_args()

    # Prevent duplicate instances
    ensure_single_instance(args.port, "tts_server")
    _v9 = init_v9("tts_server", args.port)

    logger.info("[Latency] TTS target: < 1200 ms")
    logger.info("[Latency] Pipeline vocal complet target: < 2500 ms")

    # Track connected clients for phase broadcast
    connected_clients: set = set()

    engine = CosyVoiceEngine(voice=args.voice, lang=args.lang)
    engine._cache = PhraseCache()
    engine.latency_optimized = getattr(args, "latency_optimized", False)
    engine.max_chunk_length = getattr(args, "max_chunk_length", 4096)

    # Use --chunk-size for WS frame size (replaces global CHUNK_SIZE)
    ws_chunk_size = getattr(args, "chunk_size", CHUNK_SIZE)

    logger.info(
        "TTS CONFIG: voice=%s lang=%s streaming=%s chunk_size=%d "
        "max_chunk_length=%d latency_optimized=%s",
        args.voice, args.lang, getattr(args, "streaming", False),
        ws_chunk_size, engine.max_chunk_length, engine.latency_optimized,
    )

    # Store WS chunk size on engine so TTSSession can access it
    engine._ws_chunk_size = ws_chunk_size

    # Get event loop reference for thread-safe phase broadcasts
    _event_loop = asyncio.get_running_loop()

    # Phase broadcast callback — pushes phase changes to all connected WS clients
    # MUST be thread-safe: engine.load() runs in an executor thread
    def _broadcast_phase(phase: str):
        msg = json.dumps({
            "type": "ready",
            "phase": phase,
            "profile": engine._profile,
        })

        async def _do_send():
            for ws in list(connected_clients):
                try:
                    await ws.send(msg)
                except Exception:
                    connected_clients.discard(ws)

        # run_coroutine_threadsafe works from both event loop and executor threads
        asyncio.run_coroutine_threadsafe(_do_send(), _event_loop)

    engine._phase_callback = _broadcast_phase

    # Start server BEFORE loading model so supervisor can connect immediately
    try:
        import websockets
    except ImportError:
        logger.error("websockets not installed. Run: pip install websockets")
        return

    async def handler(ws):
        connected_clients.add(ws)
        try:
            session = TTSSession(engine)
            await session.handle(ws)
        finally:
            connected_clients.discard(ws)

    server = await websockets.serve(
        handler, args.host, args.port,
        **_v9.ws_serve_kwargs(),
    )
    logger.info(
        "TTS WS server listening on ws://%s:%d — loading CosyVoice2 model…",
        args.host, args.port,
    )

    # Load model in executor to keep event loop responsive for WS connections
    loop = asyncio.get_event_loop()
    t_load = time.monotonic()
    await loop.run_in_executor(None, engine.load)
    load_ms = (time.monotonic() - t_load) * 1000
    logger.info("[Latency] Preload TTS: OK (%.0f ms)", load_ms)

    # Broadcast READY_ONLINE to any already-connected clients
    _broadcast_phase(CosyVoiceEngine.PHASE_ONLINE)

    logger.info(
        "CosyVoice2 TTS server ready on ws://%s:%d (voice=%s, lang=%s, speakers=%d)",
        args.host, args.port, args.voice, args.lang, len(engine.list_voices()),
    )
    logger.info("[Latency] Streaming: OK — ready for low-latency synthesis")

    # CUDA keepalive — prevent GPU clock downclocking during idle periods.
    # Runs a mini-inference every 30s if no synthesis happened recently.
    async def _cuda_keepalive():
        if str(engine.device) == "cpu":
            return
        while True:
            await asyncio.sleep(30)
            idle_s = time.monotonic() - engine._last_synth_time
            if idle_s > 20 and engine._loaded:
                try:
                    for _ in engine._inference_internal("ok", stream=True):
                        break  # first chunk enough
                    engine._last_synth_time = time.monotonic()
                except Exception:
                    pass

    keepalive_task = asyncio.create_task(_cuda_keepalive())

    try:
        await asyncio.Future()
    except KeyboardInterrupt:
        pass
    finally:
        keepalive_task.cancel()
        server.close()
        await server.wait_closed()
        logger.info("TTS server stopped")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
