"""
stt_server.py — EXO STT Streaming Server (faster-whisper)

WebSocket server that receives audio chunks (PCM16 16kHz mono)
and returns streaming transcription results.

Protocol:
  → Binary: PCM16 audio chunks
  → JSON:   {"type": "config", "model": "large-v3", "language": "fr", ...}
             {"type": "start"}   — begin new utterance
             {"type": "end"}     — finalize utterance
             {"type": "cancel"}  — discard current utterance
  ← JSON:   {"type": "partial", "text": "..."}
             {"type": "final",   "text": "...", "segments": [...], "duration": float}
             {"type": "ready",   "model": "...", "device": "..."}
             {"type": "error",   "message": "..."}

Dependencies:
  pip install faster-whisper websockets numpy
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import struct
import sys
import time
from pathlib import Path
from typing import Optional

import numpy as np

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [STT] %(levelname)s %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("exo.stt")

# ---------------------------------------------------------------------------
# Configuration defaults
# ---------------------------------------------------------------------------

DEFAULT_HOST = "localhost"
DEFAULT_PORT = 8766
DEFAULT_MODEL = "large-v3"
DEFAULT_LANGUAGE = "fr"
DEFAULT_BEAM_SIZE = 5
DEFAULT_DEVICE = "auto"          # "cpu", "cuda", "auto"
DEFAULT_COMPUTE_TYPE = "float16"  # "float16", "int8", "float32"
SAMPLE_RATE = 16000


# ---------------------------------------------------------------------------
# STT Engine wrapper
# ---------------------------------------------------------------------------

class STTEngine:
    """Wraps faster-whisper for streaming transcription."""

    def __init__(
        self,
        model_size: str = DEFAULT_MODEL,
        device: str = DEFAULT_DEVICE,
        compute_type: str = DEFAULT_COMPUTE_TYPE,
        language: str = DEFAULT_LANGUAGE,
        beam_size: int = DEFAULT_BEAM_SIZE,
    ) -> None:
        self.model_size = model_size
        self.device = device
        self.compute_type = compute_type
        self.language = language
        self.beam_size = beam_size
        self.model = None
        self._actual_device = "unknown"

    def load(self) -> None:
        """Load the Whisper model (can be slow on first run)."""
        try:
            from faster_whisper import WhisperModel
        except ImportError:
            logger.error("faster-whisper not installed. Run: pip install faster-whisper")
            raise

        device = self.device
        compute = self.compute_type

        # Auto-detect best device
        if device == "auto":
            try:
                import torch
                device = "cuda" if torch.cuda.is_available() else "cpu"
            except ImportError:
                device = "cpu"

        if device == "cpu":
            compute = "float32"  # float16 not supported on CPU

        logger.info(
            "Loading Whisper model '%s' on %s (%s)...",
            self.model_size, device, compute,
        )
        t0 = time.monotonic()
        self.model = WhisperModel(
            self.model_size,
            device=device,
            compute_type=compute,
        )
        self._actual_device = device
        dt = time.monotonic() - t0
        logger.info("Model loaded in %.1fs", dt)

    def transcribe(
        self,
        audio_pcm16: np.ndarray,
        *,
        initial_prompt: str | None = None,
    ) -> dict:
        """
        Transcribe a complete utterance.

        Args:
            audio_pcm16: int16 PCM array at 16kHz mono

        Returns:
            {"text": str, "segments": list, "duration": float}
        """
        if self.model is None:
            raise RuntimeError("Model not loaded")

        # Convert int16 → float32 [-1, 1]
        audio_f32 = audio_pcm16.astype(np.float32) / 32768.0
        duration = len(audio_f32) / SAMPLE_RATE

        if duration < 0.1:
            return {"text": "", "segments": [], "duration": duration}

        t0 = time.monotonic()
        segments_gen, info = self.model.transcribe(
            audio_f32,
            language=self.language,
            beam_size=self.beam_size,
            word_timestamps=False,
            initial_prompt=initial_prompt,
            vad_filter=True,
            vad_parameters={
                "min_silence_duration_ms": 500,
                "speech_pad_ms": 200,
            },
        )

        segments = []
        full_text_parts = []
        for seg in segments_gen:
            segments.append({
                "start": round(seg.start, 2),
                "end": round(seg.end, 2),
                "text": seg.text.strip(),
            })
            full_text_parts.append(seg.text.strip())

        full_text = " ".join(full_text_parts).strip()
        dt = time.monotonic() - t0

        logger.info(
            "Transcribed %.1fs audio in %.2fs (RTF=%.2f): %s",
            duration, dt, dt / max(duration, 0.01), full_text[:80],
        )

        return {
            "text": full_text,
            "segments": segments,
            "duration": round(duration, 2),
        }

    @property
    def actual_device(self) -> str:
        return self._actual_device


# ---------------------------------------------------------------------------
# WebSocket session handler
# ---------------------------------------------------------------------------

class STTSession:
    """One WebSocket client session."""

    def __init__(self, engine: STTEngine) -> None:
        self.engine = engine
        self._audio_buffer = bytearray()
        self._recording = False
        self._partial_interval = 2.0  # seconds between partial results
        self._last_partial_time = 0.0

    async def handle(self, ws) -> None:
        """Handle a WebSocket connection."""
        logger.info("STT client connected")

        # Send ready message
        await ws.send(json.dumps({
            "type": "ready",
            "model": self.engine.model_size,
            "device": self.engine.actual_device,
        }))

        try:
            async for message in ws:
                if isinstance(message, bytes):
                    await self._on_audio(ws, message)
                elif isinstance(message, str):
                    await self._on_json(ws, message)
        except Exception as e:
            logger.error("Session error: %s", e)
        finally:
            logger.info("STT client disconnected")

    async def _on_json(self, ws, raw: str) -> None:
        try:
            msg = json.loads(raw)
        except json.JSONDecodeError:
            return

        msg_type = msg.get("type", "")

        if msg_type == "start":
            self._audio_buffer.clear()
            self._recording = True
            self._last_partial_time = time.monotonic()
            logger.debug("Recording started")

        elif msg_type == "end":
            self._recording = False
            await self._finalize(ws)

        elif msg_type == "cancel":
            self._recording = False
            self._audio_buffer.clear()
            logger.debug("Recording cancelled")

        elif msg_type == "config":
            # Dynamic configuration update
            if "language" in msg:
                self.engine.language = msg["language"]
            if "beam_size" in msg:
                self.engine.beam_size = int(msg["beam_size"])
            logger.info("Config updated: lang=%s beam=%d",
                        self.engine.language, self.engine.beam_size)

    async def _on_audio(self, ws, data: bytes) -> None:
        if not self._recording:
            return

        self._audio_buffer.extend(data)

        # Send partial transcription periodically
        now = time.monotonic()
        buf_duration = len(self._audio_buffer) / (SAMPLE_RATE * 2)  # 2 bytes per sample

        if (buf_duration >= 1.5
                and now - self._last_partial_time >= self._partial_interval):
            self._last_partial_time = now
            await self._send_partial(ws)

    async def _send_partial(self, ws) -> None:
        """Transcribe current buffer for partial result."""
        if not self._audio_buffer:
            return

        pcm = np.frombuffer(bytes(self._audio_buffer), dtype=np.int16)
        try:
            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(
                None, lambda: self.engine.transcribe(pcm)
            )
            if result["text"]:
                await ws.send(json.dumps({
                    "type": "partial",
                    "text": result["text"],
                }))
        except Exception as e:
            logger.warning("Partial transcription error: %s", e)

    async def _finalize(self, ws) -> None:
        """Transcribe final utterance."""
        if not self._audio_buffer:
            await ws.send(json.dumps({
                "type": "final",
                "text": "",
                "segments": [],
                "duration": 0.0,
            }))
            return

        pcm = np.frombuffer(bytes(self._audio_buffer), dtype=np.int16)
        self._audio_buffer.clear()

        try:
            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(
                None, lambda: self.engine.transcribe(pcm)
            )
            await ws.send(json.dumps({
                "type": "final",
                "text": result["text"],
                "segments": result["segments"],
                "duration": result["duration"],
            }))
        except Exception as e:
            logger.error("Final transcription error: %s", e)
            await ws.send(json.dumps({
                "type": "error",
                "message": str(e),
            }))


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

async def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="EXO STT Server (faster-whisper)")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--model", default=DEFAULT_MODEL,
                        help="Whisper model size (tiny, base, small, medium, large-v3)")
    parser.add_argument("--language", default=DEFAULT_LANGUAGE)
    parser.add_argument("--device", default=DEFAULT_DEVICE,
                        help="Compute device (cpu, cuda, auto)")
    parser.add_argument("--compute-type", default=DEFAULT_COMPUTE_TYPE)
    parser.add_argument("--beam-size", type=int, default=DEFAULT_BEAM_SIZE)
    args = parser.parse_args()

    engine = STTEngine(
        model_size=args.model,
        device=args.device,
        compute_type=args.compute_type,
        language=args.language,
        beam_size=args.beam_size,
    )
    engine.load()

    async def handler(ws):
        session = STTSession(engine)
        await session.handle(ws)

    try:
        import websockets
    except ImportError:
        logger.error("websockets not installed. Run: pip install websockets")
        return

    server = await websockets.serve(handler, args.host, args.port)
    logger.info("STT server running on ws://%s:%d (model=%s, device=%s)",
                args.host, args.port, args.model, engine.actual_device)

    try:
        await asyncio.Future()  # run forever
    except KeyboardInterrupt:
        pass
    finally:
        server.close()
        await server.wait_closed()
        logger.info("STT server stopped")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
