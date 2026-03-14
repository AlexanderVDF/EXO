"""
tts_server.py — EXO TTS Streaming Server (Piper)

WebSocket server that receives text and returns synthesized audio
as PCM16 16kHz mono chunks.

Protocol:
  → JSON:   {"type": "synthesize", "text": "...", "voice": "fr_FR-siwis-medium",
             "rate": 1.0, "pitch": 1.0}
             {"type": "cancel"}
             {"type": "list_voices"}
  ← Binary: PCM16 audio chunks (streamed)
  ← JSON:   {"type": "start",  "text": "...", "estimated_duration": float}
             {"type": "end",    "duration": float}
             {"type": "voices", "available": [...]}
             {"type": "ready",  "voice": "...", "sample_rate": 16000}
             {"type": "error",  "message": "..."}

Dependencies:
  pip install piper-tts websockets numpy
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import sys
import time
from pathlib import Path
from typing import Optional

import numpy as np

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
DEFAULT_VOICE = "fr_FR-siwis-medium"
DEFAULT_SPEAKER_ID = 0
SAMPLE_RATE = 16000
CHUNK_SIZE = 4096  # bytes per WebSocket binary frame


# ---------------------------------------------------------------------------
# TTS Engine wrapper
# ---------------------------------------------------------------------------

class TTSEngine:
    """Wraps Piper TTS for streaming synthesis."""

    def __init__(self, voice: str = DEFAULT_VOICE) -> None:
        self.voice_name = voice
        self.voice = None
        self._loaded = False

    def load(self) -> None:
        """Load Piper voice model."""
        try:
            from piper import PiperVoice
        except ImportError:
            logger.error("piper-tts not installed. Run: pip install piper-tts")
            raise

        # Piper downloads voice models automatically or expects local path
        model_path = self._find_model()
        if model_path:
            logger.info("Loading Piper voice from: %s", model_path)
            self.voice = PiperVoice.load(str(model_path))
        else:
            logger.info("Loading Piper voice: %s (will download if needed)", self.voice_name)
            try:
                self.voice = PiperVoice.load(self.voice_name)
            except Exception:
                # Try with piper_phonemize + model download
                self.voice = self._download_and_load()

        self._loaded = True
        logger.info("Piper voice loaded: %s", self.voice_name)

    def _find_model(self) -> Optional[Path]:
        """Search for local Piper model files."""
        search_dirs = [
            Path("resources/piper"),
            Path("models/piper"),
            Path.home() / ".local/share/piper-voices",
            Path.home() / "piper_models",
        ]
        for d in search_dirs:
            if d.exists():
                for f in d.rglob("*.onnx"):
                    if self.voice_name.replace("-", "_") in f.stem or self.voice_name in f.stem:
                        return f
        return None

    def _download_and_load(self):
        """Download voice model from Piper GitHub releases and load it."""
        from piper import PiperVoice
        import urllib.request

        cache_dir = Path.home() / ".local/share/piper-voices"
        cache_dir.mkdir(parents=True, exist_ok=True)

        # Check cache first
        for f in cache_dir.rglob("*.onnx"):
            if self.voice_name.replace("-", "_") in f.stem or self.voice_name in f.stem:
                logger.info("Found cached voice: %s", f)
                json_f = f.with_suffix(".onnx.json")
                if json_f.exists():
                    return PiperVoice.load(str(f))

        # Download from Piper releases
        # Voice name format: lang_COUNTRY-name-quality  e.g. fr_FR-siwis-medium
        parts = self.voice_name.split("-")
        if len(parts) < 3:
            raise RuntimeError(f"Invalid voice name format: {self.voice_name}")

        lang_country = parts[0]   # fr_FR
        lang = lang_country.split("_")[0]  # fr
        name = parts[1]           # siwis
        quality = parts[2]        # medium

        base_url = (
            f"https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/"
            f"{lang}/{lang_country}/{name}/{quality}/"
        )
        onnx_filename = f"{self.voice_name}.onnx"
        json_filename = f"{self.voice_name}.onnx.json"

        voice_dir = cache_dir / lang / lang_country / name / quality
        voice_dir.mkdir(parents=True, exist_ok=True)

        for filename in (onnx_filename, json_filename):
            dest = voice_dir / filename
            if dest.exists():
                logger.info("Already cached: %s", dest)
                continue
            url = base_url + filename
            logger.info("Downloading %s ...", url)
            try:
                urllib.request.urlretrieve(url, str(dest))
                logger.info("Downloaded: %s (%.1f MB)", dest, dest.stat().st_size / 1e6)
            except Exception as e:
                raise RuntimeError(f"Failed to download {url}: {e}")

        model_path = voice_dir / onnx_filename
        return PiperVoice.load(str(model_path))

    def synthesize(self, text: str, rate: float = 1.0, pitch: float = 1.0) -> bytes:
        """
        Synthesize text to PCM16 audio.

        Returns: raw PCM16 bytes at SAMPLE_RATE Hz mono
        """
        if not self._loaded or self.voice is None:
            raise RuntimeError("Voice not loaded")

        if not text.strip():
            return b""

        t0 = time.monotonic()

        from piper.config import SynthesisConfig
        syn_config = SynthesisConfig(
            length_scale=1.0 / max(rate, 0.1),
        )

        # synthesize() returns an iterable of AudioChunk with audio_float_array
        pcm_parts = []
        for chunk in self.voice.synthesize(text, syn_config=syn_config):
            pcm_parts.append(chunk.audio_float_array)

        if not pcm_parts:
            return b""

        audio_array = np.concatenate(pcm_parts)
        src_rate = self.voice.config.sample_rate

        # Convert float32 [-1,1] to int16 if needed
        if audio_array.dtype == np.float32:
            audio_array = np.clip(audio_array * 32767, -32768, 32767).astype(np.int16)

        raw_pcm = audio_array.tobytes()

        # Resample if needed
        if src_rate != SAMPLE_RATE:
            raw_pcm = self._resample(raw_pcm, src_rate, SAMPLE_RATE)

        # Apply pitch shift if significantly different from 1.0
        if abs(pitch - 1.0) > 0.05:
            raw_pcm = self._pitch_shift(raw_pcm, pitch)

        dt = time.monotonic() - t0
        duration = len(raw_pcm) / (SAMPLE_RATE * 2)
        logger.info(
            "Synthesized %.1fs audio in %.2fs (RTF=%.2f): %s",
            duration, dt, dt / max(duration, 0.01), text[:60],
        )

        return raw_pcm

    @staticmethod
    def _resample(pcm_bytes: bytes, src_rate: int, dst_rate: int) -> bytes:
        """Simple linear interpolation resampling."""
        samples = np.frombuffer(pcm_bytes, dtype=np.int16).astype(np.float32)
        ratio = dst_rate / src_rate
        n_out = int(len(samples) * ratio)
        indices = np.arange(n_out) / ratio
        indices = np.clip(indices, 0, len(samples) - 1)
        idx_floor = indices.astype(np.int64)
        idx_ceil = np.minimum(idx_floor + 1, len(samples) - 1)
        frac = indices - idx_floor
        resampled = samples[idx_floor] * (1 - frac) + samples[idx_ceil] * frac
        return resampled.astype(np.int16).tobytes()

    @staticmethod
    def _pitch_shift(pcm_bytes: bytes, factor: float) -> bytes:
        """Simple pitch shift by resampling + speed correction."""
        samples = np.frombuffer(pcm_bytes, dtype=np.int16).astype(np.float32)
        # Resample to change pitch, then time-stretch back
        n_out = int(len(samples) / factor)
        if n_out < 1:
            return pcm_bytes
        indices = np.linspace(0, len(samples) - 1, n_out)
        idx_floor = indices.astype(np.int64)
        idx_ceil = np.minimum(idx_floor + 1, len(samples) - 1)
        frac = indices - idx_floor
        shifted = samples[idx_floor] * (1 - frac) + samples[idx_ceil] * frac
        return shifted.astype(np.int16).tobytes()


# ---------------------------------------------------------------------------
# WebSocket session handler
# ---------------------------------------------------------------------------

class TTSSession:
    """One WebSocket client session."""

    def __init__(self, engine: TTSEngine) -> None:
        self.engine = engine
        self._cancel_flag = False
        self._synth_task: Optional[asyncio.Task] = None

    async def handle(self, ws) -> None:
        """Handle a WebSocket connection."""
        logger.info("TTS client connected")

        await ws.send(json.dumps({
            "type": "ready",
            "voice": self.engine.voice_name,
            "sample_rate": SAMPLE_RATE,
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
            rate = float(msg.get("rate", 1.0))
            pitch = float(msg.get("pitch", 1.0))

            if not text.strip():
                await ws.send(json.dumps({"type": "error", "message": "Empty text"}))
                return

            self._cancel_flag = False
            await self._synthesize_and_stream(ws, text, rate, pitch)

        elif msg_type == "cancel":
            self._cancel_flag = True
            logger.debug("Synthesis cancelled")

        elif msg_type == "list_voices":
            await ws.send(json.dumps({
                "type": "voices",
                "available": [self.engine.voice_name],
            }))

    async def _synthesize_and_stream(
        self, ws, text: str, rate: float, pitch: float
    ) -> None:
        """Synthesize and stream audio in chunks."""
        try:
            # Notify start
            await ws.send(json.dumps({
                "type": "start",
                "text": text,
            }))

            # Run synthesis in executor (blocking call)
            loop = asyncio.get_event_loop()
            pcm_data = await loop.run_in_executor(
                None, lambda: self.engine.synthesize(text, rate, pitch)
            )

            if self._cancel_flag:
                return

            # Stream chunks
            duration = len(pcm_data) / (SAMPLE_RATE * 2)
            offset = 0
            while offset < len(pcm_data):
                if self._cancel_flag:
                    logger.debug("Streaming cancelled at offset %d", offset)
                    return

                chunk = pcm_data[offset:offset + CHUNK_SIZE]
                await ws.send(chunk)
                offset += CHUNK_SIZE

                # Small yield to allow cancel checks
                await asyncio.sleep(0)

            # Notify end
            await ws.send(json.dumps({
                "type": "end",
                "duration": round(duration, 2),
            }))

        except Exception as e:
            logger.error("Synthesis error: %s", e)
            await ws.send(json.dumps({
                "type": "error",
                "message": str(e),
            }))


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

async def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="EXO TTS Server (Piper)")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--voice", default=DEFAULT_VOICE,
                        help="Piper voice model name")
    args = parser.parse_args()

    engine = TTSEngine(voice=args.voice)
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
    logger.info("TTS server running on ws://%s:%d (voice=%s)",
                args.host, args.port, args.voice)

    try:
        await asyncio.Future()  # run forever
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
