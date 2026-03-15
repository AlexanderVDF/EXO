"""
tts_server.py — EXO TTS Streaming Server (XTTS v2)

WebSocket server using Coqui XTTS v2 for high-quality neural TTS.
Returns synthesized audio as PCM16 24kHz mono chunks.

Protocol:
  → JSON:   {"type": "synthesize", "text": "...", "voice": "Claribel Dervla",
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
  pip install TTS torch torchaudio websockets numpy soundfile
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import sys
import time
import hashlib
from pathlib import Path
from typing import Optional

import numpy as np

# ---------------------------------------------------------------------------
# PyTorch compat: Coqui TTS uses torch.inference_mode() internally, but
# PyTorch >= 2.4 raises "Cannot set version_counter for inference tensor".
# Monkey-patching inference_mode → no_grad fixes this.
# ---------------------------------------------------------------------------
import torch
torch.inference_mode = torch.no_grad  # type: ignore[assignment]

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
DEFAULT_VOICE = "Claribel Dervla"
DEFAULT_LANG = "fr"
XTTS_SAMPLE_RATE = 24000   # XTTS v2 native rate
OUTPUT_SAMPLE_RATE = 24000  # Send at native rate (C++ TTSManager expects 24kHz)
CHUNK_SIZE = 4096           # bytes per WebSocket binary frame

SUPPORTED_LANGUAGES = [
    "en", "es", "fr", "de", "it", "pt", "pl", "tr",
    "ru", "nl", "cs", "ar", "zh-cn", "hu", "ko", "ja", "hi",
]


# ---------------------------------------------------------------------------
# Short phrase cache
# ---------------------------------------------------------------------------

class PhraseCache:
    """LRU cache for short phrases to avoid re-synthesis."""

    def __init__(self, max_entries: int = 64) -> None:
        self._cache: dict[str, bytes] = {}
        self._order: list[str] = []
        self._max = max_entries

    def key(self, text: str, voice: str, lang: str) -> str:
        h = hashlib.md5(f"{text}|{voice}|{lang}".encode()).hexdigest()
        return h

    def get(self, text: str, voice: str, lang: str) -> Optional[bytes]:
        k = self.key(text, voice, lang)
        return self._cache.get(k)

    def put(self, text: str, voice: str, lang: str, pcm: bytes) -> None:
        if len(text) > 40:
            return
        k = self.key(text, voice, lang)
        if k in self._cache:
            return
        if len(self._cache) >= self._max:
            oldest = self._order.pop(0)
            self._cache.pop(oldest, None)
        self._cache[k] = pcm
        self._order.append(k)


# ---------------------------------------------------------------------------
# TTS Engine wrapper — XTTS v2
# ---------------------------------------------------------------------------

class XTTSEngine:
    """Wraps Coqui XTTS v2 for streaming synthesis."""

    def __init__(self, voice: str = DEFAULT_VOICE, lang: str = DEFAULT_LANG) -> None:
        self.voice_name = voice
        self.language = lang
        self.model = None
        self.speakers: dict = {}
        self.gpt_cond_latent = None
        self.speaker_embedding = None
        self._loaded = False
        self._cache = PhraseCache()
        self.device = "cpu"

    @staticmethod
    def _detect_device():
        """Detect best available device: CUDA > DirectML > CPU."""
        import torch
        if torch.cuda.is_available():
            name = torch.cuda.get_device_name(0)
            logger.info("GPU detected: CUDA — %s", name)
            return "cuda"
        try:
            import torch_directml
            if torch_directml.is_available():
                logger.info("GPU detected: DirectML — %s", torch_directml.device())
                return torch_directml.device()
        except ImportError:
            pass
        logger.info("No GPU detected, using CPU")
        return "cpu"

    def load(self) -> None:
        """Load XTTS v2 model and speaker embeddings."""
        import torch
        from TTS.api import TTS

        self.device = self._detect_device()

        logger.info("Loading XTTS v2 model on %s...", self.device)
        tts_api = TTS(
            model_name="tts_models/multilingual/multi-dataset/xtts_v2",
            progress_bar=False,
        )
        self.model = tts_api.synthesizer.tts_model

        # Move model to GPU
        if str(self.device) != "cpu":
            self.model = self.model.to(self.device)
            logger.info("XTTS model moved to %s", self.device)

        # Load speaker embeddings
        model_dir = os.environ.get(
            "EXO_XTTS_MODELS",
            r"D:\EXO\models\xtts",
        )
        spk_file = os.path.join(model_dir, "speakers_xtts.pth")
        if os.path.exists(spk_file):
            self.speakers = torch.load(spk_file, weights_only=False)
            # Move speaker embeddings to GPU
            if str(self.device) != "cpu":
                for name in self.speakers:
                    for key in self.speakers[name]:
                        if hasattr(self.speakers[name][key], "to"):
                            self.speakers[name][key] = self.speakers[name][key].to(self.device)
            logger.info("Loaded %d speakers from %s", len(self.speakers), spk_file)
        else:
            logger.warning("No speakers file found at %s", spk_file)

        # Set initial voice
        self.set_voice(self.voice_name)
        self._loaded = True
        logger.info(
            "XTTS v2 ready — device=%s, voice=%s, lang=%s, speakers=%d",
            self.device, self.voice_name, self.language, len(self.speakers),
        )

    def set_voice(self, voice: str) -> bool:
        """Switch to a different speaker. Returns True if found."""
        if voice in self.speakers:
            self.voice_name = voice
            self.gpt_cond_latent = self.speakers[voice]["gpt_cond_latent"]
            self.speaker_embedding = self.speakers[voice]["speaker_embedding"]
            logger.info("Voice set to: %s", voice)
            return True

        # Try case-insensitive match
        for name in self.speakers:
            if name.lower() == voice.lower():
                return self.set_voice(name)

        logger.warning("Speaker '%s' not found, keeping '%s'", voice, self.voice_name)
        return False

    def set_language(self, lang: str) -> None:
        """Set synthesis language."""
        if lang in SUPPORTED_LANGUAGES:
            self.language = lang
            logger.info("Language set to: %s", lang)
        else:
            logger.warning("Unsupported language: %s", lang)

    def list_voices(self) -> list[str]:
        """Return sorted list of available speaker names."""
        return sorted(self.speakers.keys())

    def synthesize(
        self,
        text: str,
        voice: Optional[str] = None,
        lang: Optional[str] = None,
        rate: float = 1.0,
        pitch: float = 1.0,
    ) -> bytes:
        """
        Synthesize text to PCM16 audio at OUTPUT_SAMPLE_RATE Hz mono.

        Returns: raw PCM16 bytes
        """
        if not self._loaded or self.model is None:
            raise RuntimeError("Model not loaded")
        if not text.strip():
            return b""

        # Strip emojis so TTS doesn't try to pronounce them
        text = re.sub(
            r"[\U0001F600-\U0001F64F"   # emoticons
            r"\U0001F300-\U0001F5FF"     # symbols & pictographs
            r"\U0001F680-\U0001F6FF"     # transport & map
            r"\U0001F1E0-\U0001F1FF"     # flags
            r"\U00002702-\U000027B0"     # dingbats
            r"\U000024C2-\U0001F251"     # misc
            r"\U0001F900-\U0001F9FF"     # supplemental symbols
            r"\U0001FA00-\U0001FA6F"     # chess symbols
            r"\U0001FA70-\U0001FAFF"     # symbols extended-A
            r"\U00002600-\U000026FF"     # misc symbols
            r"\U0000FE00-\U0000FE0F"     # variation selectors
            r"\U0000200D"               # zero-width joiner
            r"]+", "", text
        ).strip()
        if not text:
            return b""

        use_voice = voice if voice and voice in self.speakers else self.voice_name
        use_lang = lang if lang and lang in SUPPORTED_LANGUAGES else self.language

        # Check cache for short phrases
        cached = self._cache.get(text, use_voice, use_lang)
        if cached is not None:
            logger.info("Cache hit: %s", text[:40])
            return cached

        # Select speaker embeddings
        gpt_cond = self.speakers[use_voice]["gpt_cond_latent"]
        spk_emb = self.speakers[use_voice]["speaker_embedding"]

        t0 = time.monotonic()

        # XTTS v2 inference
        out = self.model.inference(
            text=text,
            language=use_lang,
            gpt_cond_latent=gpt_cond,
            speaker_embedding=spk_emb,
            speed=rate,
        )
        wav = out["wav"]

        # wav is a numpy-like tensor at 24kHz — convert to numpy
        if hasattr(wav, "cpu"):
            wav = wav.cpu()
        if hasattr(wav, "numpy"):
            wav = wav.numpy()
        wav = np.asarray(wav, dtype=np.float32)

        # Convert float32 wav at native rate to PCM16
        if XTTS_SAMPLE_RATE != OUTPUT_SAMPLE_RATE:
            pcm16k = self._resample(wav, XTTS_SAMPLE_RATE, OUTPUT_SAMPLE_RATE)
        else:
            pcm16k = wav  # No resampling needed

        # Apply pitch shift if requested
        if abs(pitch - 1.0) > 0.05:
            pcm16k = self._pitch_shift(pcm16k, pitch)

        # Convert float32 → int16 PCM
        pcm16k = np.clip(pcm16k * 32767, -32768, 32767).astype(np.int16)
        raw_pcm = pcm16k.tobytes()

        dt = time.monotonic() - t0
        duration = len(raw_pcm) / (OUTPUT_SAMPLE_RATE * 2)
        logger.info(
            "XTTS synthesized %.1fs audio in %.2fs (RTF=%.2f) voice=%s lang=%s: %s",
            duration, dt, dt / max(duration, 0.01), use_voice, use_lang, text[:60],
        )

        # Cache short phrases
        self._cache.put(text, use_voice, use_lang, raw_pcm)

        return raw_pcm

    @staticmethod
    def _resample(samples: np.ndarray, src_rate: int, dst_rate: int) -> np.ndarray:
        """Linear interpolation resampling."""
        if src_rate == dst_rate:
            return samples
        ratio = dst_rate / src_rate
        n_out = int(len(samples) * ratio)
        indices = np.arange(n_out) / ratio
        indices = np.clip(indices, 0, len(samples) - 1)
        idx_floor = indices.astype(np.int64)
        idx_ceil = np.minimum(idx_floor + 1, len(samples) - 1)
        frac = (indices - idx_floor).astype(np.float32)
        return samples[idx_floor] * (1 - frac) + samples[idx_ceil] * frac

    @staticmethod
    def _pitch_shift(samples: np.ndarray, factor: float) -> np.ndarray:
        """Simple pitch shift by resampling."""
        n_out = int(len(samples) / factor)
        if n_out < 1:
            return samples
        indices = np.linspace(0, len(samples) - 1, n_out)
        idx_floor = indices.astype(np.int64)
        idx_ceil = np.minimum(idx_floor + 1, len(samples) - 1)
        frac = (indices - idx_floor).astype(np.float32)
        return samples[idx_floor] * (1 - frac) + samples[idx_ceil] * frac


# ---------------------------------------------------------------------------
# WebSocket session handler
# ---------------------------------------------------------------------------

class TTSSession:
    """One WebSocket client session."""

    def __init__(self, engine: XTTSEngine) -> None:
        self.engine = engine
        self._cancel_flag = False

    async def handle(self, ws) -> None:
        """Handle a WebSocket connection."""
        logger.info("TTS client connected")

        await ws.send(json.dumps({
            "type": "ready",
            "voice": self.engine.voice_name,
            "sample_rate": OUTPUT_SAMPLE_RATE,
            "backend": "xtts_v2",
            "languages": SUPPORTED_LANGUAGES,
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
        try:
            msg = json.loads(raw)
        except json.JSONDecodeError:
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
        """Synthesize and stream audio in chunks."""
        try:
            await ws.send(json.dumps({
                "type": "start",
                "text": text,
            }))

            loop = asyncio.get_event_loop()
            t0 = time.monotonic()
            pcm_data = await loop.run_in_executor(
                None,
                lambda: self.engine.synthesize(text, voice, lang, rate, pitch),
            )
            synth_ms = (time.monotonic() - t0) * 1000

            if self._cancel_flag:
                return

            duration = len(pcm_data) / (OUTPUT_SAMPLE_RATE * 2)
            logger.info("[TTS] synthesized %.1fs audio in %.0fms text=%s",
                        duration, synth_ms, text[:60])
            offset = 0
            while offset < len(pcm_data):
                if self._cancel_flag:
                    logger.debug("Streaming cancelled at offset %d", offset)
                    return

                chunk = pcm_data[offset : offset + CHUNK_SIZE]
                await ws.send(chunk)
                offset += CHUNK_SIZE
                await asyncio.sleep(0)

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
    import argparse

    parser = argparse.ArgumentParser(description="EXO TTS Server (XTTS v2)")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--voice", default=DEFAULT_VOICE,
                        help="XTTS v2 speaker name (e.g. 'Claribel Dervla')")
    parser.add_argument("--lang", default=DEFAULT_LANG,
                        help="Default language (e.g. fr, en, de)")
    args = parser.parse_args()

    engine = XTTSEngine(voice=args.voice, lang=args.lang)
    engine.load()

    async def handler(ws):
        session = TTSSession(engine)
        await session.handle(ws)

    try:
        import websockets
    except ImportError:
        logger.error("websockets not installed. Run: pip install websockets")
        return

    server = await websockets.serve(handler, args.host, args.port)
    logger.info(
        "XTTS v2 TTS server running on ws://%s:%d (voice=%s, lang=%s, speakers=%d)",
        args.host, args.port, args.voice, args.lang, len(engine.speakers),
    )

    try:
        await asyncio.Future()
    except KeyboardInterrupt:
        pass
    finally:
        server.close()
        await server.wait_closed()
        logger.info("TTS server stopped")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
