#!/usr/bin/env python3
"""
tts_gpu_server.py — EXO TTS GPU Server (XTTS v2 on ROCm / AMD GPU via WSL2)

WebSocket server using Coqui XTTS v2 running on AMD GPU via ROCm.
Returns synthesized audio as PCM16 24kHz mono chunks.
100% compatible with EXO C++ TTSManager protocol.

Protocol (identical to tts_server.py):
  → JSON:   {"type": "synthesize", "text": "...", "voice": "Claribel Dervla",
             "lang": "fr", "rate": 1.0, "pitch": 1.0}
             {"type": "cancel"}
             {"type": "list_voices"}
  ← Binary: PCM16 audio chunks (streamed)
  ← JSON:   {"type": "start",  "text": "..."}
             {"type": "end",    "duration": float, "synth_ms": int}
             {"type": "voices", "available": [...]}
             {"type": "ready",  "voice": "...", "sample_rate": 24000, "backend": "xtts_v2_rocm"}
             {"type": "error",  "message": "..."}

Usage (WSL2):
  source ~/exo_tts_venv/bin/activate
  python3 ~/exo_tts_server/tts_gpu_server.py --voice "Claribel Dervla" --lang fr
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import os
import re
import sys
import time
from pathlib import Path
from typing import Optional

import numpy as np

# ---------------------------------------------------------------------------
# PyTorch compat: Coqui TTS uses torch.inference_mode() internally, but
# certain PyTorch builds raise errors with inference_mode.
# Monkey-patching inference_mode → no_grad fixes this.
# ---------------------------------------------------------------------------
import torch

torch.inference_mode = torch.no_grad  # type: ignore[assignment]

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [TTS-GPU] %(levelname)s %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("exo.tts.gpu")

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

DEFAULT_HOST = "0.0.0.0"  # Listen on all interfaces (accessible from Windows)
DEFAULT_PORT = 8767
DEFAULT_VOICE = "Claribel Dervla"
DEFAULT_LANG = "fr"
XTTS_SAMPLE_RATE = 24000
OUTPUT_SAMPLE_RATE = 24000
CHUNK_SIZE = 4096  # bytes per WebSocket binary frame

# Model paths in WSL2
DEFAULT_MODEL_DIR = os.path.expanduser("~/exo_tts_models")
DEFAULT_SPEAKERS_FILE = os.path.join(DEFAULT_MODEL_DIR, "speakers_xtts.pth")

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
        return hashlib.md5(f"{text}|{voice}|{lang}".encode()).hexdigest()

    def get(self, text: str, voice: str, lang: str) -> Optional[bytes]:
        return self._cache.get(self.key(text, voice, lang))

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
# GPU Detection — ROCm (HIP) → CUDA → CPU
# ---------------------------------------------------------------------------

def detect_gpu_device() -> str:
    """
    Detect best GPU:
      1) ROCm/HIP (torch.cuda on ROCm build → AMD GPU)
      2) CUDA (NVIDIA)
      3) CPU fallback
    """
    if torch.cuda.is_available():
        name = torch.cuda.get_device_name(0)
        hip_version = getattr(torch.version, "hip", None)
        if hip_version:
            logger.info("GPU detected: ROCm/HIP %s — %s", hip_version, name)
        else:
            logger.info("GPU detected: CUDA — %s", name)
        return "cuda"

    # Try DirectML as fallback
    try:
        import torch_directml
        if torch_directml.is_available():
            dev = torch_directml.device()
            logger.info("GPU detected: DirectML — %s", dev)
            return str(dev)
    except ImportError:
        pass

    logger.warning("No GPU detected — falling back to CPU (slow)")
    return "cpu"


# ---------------------------------------------------------------------------
# TTS Engine — XTTS v2 on GPU
# ---------------------------------------------------------------------------

class XTTSGPUEngine:
    """Wraps Coqui XTTS v2 for GPU-accelerated synthesis."""

    def __init__(self, voice: str = DEFAULT_VOICE, lang: str = DEFAULT_LANG,
                 model_dir: str = DEFAULT_MODEL_DIR) -> None:
        self.voice_name = voice
        self.language = lang
        self.model_dir = model_dir
        self.model = None
        self.speakers: dict = {}
        self.gpt_cond_latent = None
        self.speaker_embedding = None
        self._loaded = False
        self._cache = PhraseCache()
        self.device = "cpu"

    def load(self) -> None:
        """Load XTTS v2 model and speaker embeddings on GPU."""
        self.device = detect_gpu_device()

        # For AMD consumer GPUs on ROCm, may need architecture override
        if self.device == "cuda" and getattr(torch.version, "hip", None):
            gfx_override = os.environ.get("HSA_OVERRIDE_GFX_VERSION", "")
            if gfx_override:
                logger.info("HSA_OVERRIDE_GFX_VERSION=%s", gfx_override)

        logger.info("Loading XTTS v2 model on %s...", self.device)
        t0 = time.monotonic()

        # Check for local model first
        local_model = os.path.join(self.model_dir, "model.pth")
        if os.path.exists(local_model):
            logger.info("Loading local XTTS model from %s", self.model_dir)
            # Use direct XTTS loading for local models (more reliable)
            from TTS.tts.configs.xtts_config import XttsConfig
            from TTS.tts.models.xtts import Xtts

            config = XttsConfig()
            config.load_json(os.path.join(self.model_dir, "config.json"))
            self.model = Xtts.init_from_config(config)
            self.model.load_checkpoint(
                config,
                checkpoint_dir=self.model_dir,
                eval=True,
            )
        else:
            logger.info("Downloading/loading XTTS v2 from HuggingFace...")
            from TTS.api import TTS
            tts_api = TTS(
                model_name="tts_models/multilingual/multi-dataset/xtts_v2",
                progress_bar=True,
            )
            self.model = tts_api.synthesizer.tts_model

        # Move model to GPU
        if self.device != "cpu":
            self.model = self.model.to(self.device)
            logger.info("XTTS model moved to %s", self.device)

        load_time = time.monotonic() - t0
        logger.info("XTTS v2 model loaded in %.1fs", load_time)

        # Load speaker embeddings
        spk_file = os.environ.get("EXO_SPEAKERS_FILE", DEFAULT_SPEAKERS_FILE)
        if os.path.exists(spk_file):
            self.speakers = torch.load(spk_file, weights_only=False)
            # Move speaker embeddings to GPU
            if self.device != "cpu":
                for name in self.speakers:
                    for key in self.speakers[name]:
                        if hasattr(self.speakers[name][key], "to"):
                            self.speakers[name][key] = self.speakers[name][key].to(
                                self.device
                            )
            logger.info("Loaded %d speakers from %s", len(self.speakers), spk_file)
        else:
            logger.warning("No speakers file at %s — will use default voice", spk_file)

        self.set_voice(self.voice_name)
        self._loaded = True
        logger.info(
            "TTS GPU READY — device=%s, voice=%s, lang=%s, speakers=%d",
            self.device, self.voice_name, self.language, len(self.speakers),
        )

    def set_voice(self, voice: str) -> bool:
        if voice in self.speakers:
            self.voice_name = voice
            self.gpt_cond_latent = self.speakers[voice]["gpt_cond_latent"]
            self.speaker_embedding = self.speakers[voice]["speaker_embedding"]
            logger.info("Voice set to: %s", voice)
            return True
        for name in self.speakers:
            if name.lower() == voice.lower():
                return self.set_voice(name)
        logger.warning("Speaker '%s' not found, keeping '%s'", voice, self.voice_name)
        return False

    def set_language(self, lang: str) -> None:
        if lang in SUPPORTED_LANGUAGES:
            self.language = lang
            logger.info("Language set to: %s", lang)
        else:
            logger.warning("Unsupported language: %s", lang)

    def list_voices(self) -> list[str]:
        return sorted(self.speakers.keys())

    def synthesize(
        self,
        text: str,
        voice: Optional[str] = None,
        lang: Optional[str] = None,
        rate: float = 1.0,
        pitch: float = 1.0,
    ) -> bytes:
        if not self._loaded or self.model is None:
            raise RuntimeError("Model not loaded")
        if not text.strip():
            return b""

        # Strip emojis
        text = re.sub(
            r"[\U0001F600-\U0001F64F\U0001F300-\U0001F5FF\U0001F680-\U0001F6FF"
            r"\U0001F1E0-\U0001F1FF\U00002702-\U000027B0\U000024C2-\U0001F251"
            r"\U0001F900-\U0001F9FF\U0001FA00-\U0001FA6F\U0001FA70-\U0001FAFF"
            r"\U00002600-\U000026FF\U0000FE00-\U0000FE0F\U0000200D]+",
            "", text,
        ).strip()
        if not text:
            return b""

        use_voice = voice if voice and voice in self.speakers else self.voice_name
        use_lang = lang if lang and lang in SUPPORTED_LANGUAGES else self.language

        # Cache check
        cached = self._cache.get(text, use_voice, use_lang)
        if cached is not None:
            logger.info("Cache hit: %s", text[:40])
            return cached

        gpt_cond = self.speakers[use_voice]["gpt_cond_latent"]
        spk_emb = self.speakers[use_voice]["speaker_embedding"]

        t0 = time.monotonic()

        out = self.model.inference(
            text=text,
            language=use_lang,
            gpt_cond_latent=gpt_cond,
            speaker_embedding=spk_emb,
            speed=rate,
        )
        wav = out["wav"]

        if hasattr(wav, "cpu"):
            wav = wav.cpu()
        if hasattr(wav, "numpy"):
            wav = wav.numpy()
        wav = np.asarray(wav, dtype=np.float32)

        if abs(pitch - 1.0) > 0.05:
            wav = self._pitch_shift(wav, pitch)

        pcm16 = np.clip(wav * 32767, -32768, 32767).astype(np.int16)
        raw_pcm = pcm16.tobytes()

        dt = time.monotonic() - t0
        duration = len(raw_pcm) / (OUTPUT_SAMPLE_RATE * 2)
        logger.info(
            "synthesized %.1fs audio in %.0fms (RTF=%.2f) voice=%s: %s",
            duration, dt * 1000, dt / max(duration, 0.01), use_voice, text[:60],
        )

        self._cache.put(text, use_voice, use_lang, raw_pcm)
        return raw_pcm

    @staticmethod
    def _pitch_shift(samples: np.ndarray, factor: float) -> np.ndarray:
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
    def __init__(self, engine: XTTSGPUEngine) -> None:
        self.engine = engine
        self._cancel_flag = False

    async def handle(self, ws) -> None:
        logger.info("TTS client connected from %s", ws.remote_address)
        await ws.send(json.dumps({
            "type": "ready",
            "voice": self.engine.voice_name,
            "sample_rate": OUTPUT_SAMPLE_RATE,
            "backend": "xtts_v2_rocm",
            "device": self.engine.device,
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
            voice = msg.get("voice")
            lang = msg.get("lang")
            rate = float(msg.get("rate", 1.0))
            pitch = float(msg.get("pitch", 1.0))
            if not text.strip():
                await ws.send(json.dumps({"type": "error", "message": "Empty text"}))
                return
            self._cancel_flag = False
            await self._synthesize_and_stream(ws, text, voice, lang, rate, pitch)

        elif msg_type == "cancel":
            self._cancel_flag = True

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
        try:
            await ws.send(json.dumps({"type": "start", "text": text}))

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
            offset = 0
            while offset < len(pcm_data):
                if self._cancel_flag:
                    return
                chunk = pcm_data[offset:offset + CHUNK_SIZE]
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
                await ws.send(json.dumps({"type": "error", "message": str(e)}))
            except Exception:
                pass


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

async def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="EXO TTS GPU Server (XTTS v2 ROCm)")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--voice", default=DEFAULT_VOICE)
    parser.add_argument("--lang", default=DEFAULT_LANG)
    parser.add_argument("--model-dir", default=DEFAULT_MODEL_DIR,
                        help="Path to XTTS v2 model directory")
    args = parser.parse_args()

    engine = XTTSGPUEngine(voice=args.voice, lang=args.lang, model_dir=args.model_dir)
    engine.load()

    async def handler(ws):
        session = TTSSession(engine)
        await session.handle(ws)

    try:
        import websockets
    except ImportError:
        logger.error("websockets not installed! pip install websockets")
        return

    server = await websockets.serve(handler, args.host, args.port)
    logger.info(
        "TTS GPU READY — ws://%s:%d (device=%s, voice=%s, lang=%s, speakers=%d)",
        args.host, args.port, engine.device, args.voice, args.lang,
        len(engine.speakers),
    )

    try:
        await asyncio.Future()
    except KeyboardInterrupt:
        pass
    finally:
        server.close()
        await server.wait_closed()
        logger.info("TTS GPU server stopped")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
