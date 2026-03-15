"""
vad_server.py — EXO Silero VAD Server

WebSocket server that receives PCM16 audio chunks and returns
real-time voice activity detection scores using Silero VAD.

Protocol:
  → Binary: PCM16 audio chunks (16kHz mono)
  → JSON:   {"type": "config", "threshold": 0.5}
             {"type": "reset"}
  ← JSON:   {"type": "ready", "model": "silero_vad"}
             {"type": "vad", "score": 0.85, "is_speech": true}

Port: 8768 (default)

Dependencies:
  pip install websockets torch silero-vad
"""

from __future__ import annotations

import asyncio
import json
import logging
import struct
import sys
import time
from typing import Optional

import numpy as np
import torch

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [VAD] %(levelname)s %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("exo.vad")

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

DEFAULT_HOST = "localhost"
DEFAULT_PORT = 8768
SAMPLE_RATE = 16000
# Silero VAD expects chunks of 512 samples at 16kHz (32ms)
CHUNK_SAMPLES = 512


class SileroVAD:
    """Wrapper around Silero VAD model."""

    def __init__(self) -> None:
        self._model = None
        self._threshold = 0.5
        self._is_speech = False
        self._speech_frames = 0
        self._silence_frames = 0
        self._speech_start_frames = 2
        self._speech_hang_frames = 15  # ~480ms at 32ms chunks

    def load(self) -> None:
        """Load Silero VAD model."""
        t0 = time.monotonic()
        try:
            from silero_vad import load_silero_vad
            self._model = load_silero_vad()
            dt = time.monotonic() - t0
            logger.info("Silero VAD loaded in %.2fs", dt)
        except Exception as e:
            logger.error("Failed to load Silero VAD: %s", e)
            raise

    def reset(self) -> None:
        """Reset model state for new session."""
        if self._model is not None:
            self._model.reset_states()
        self._is_speech = False
        self._speech_frames = 0
        self._silence_frames = 0
        logger.info("VAD state reset")

    def process_chunk(self, pcm16: np.ndarray) -> tuple[float, bool]:
        """
        Process a chunk of PCM16 audio.

        Args:
            pcm16: int16 PCM array (should be CHUNK_SAMPLES long)

        Returns:
            (score, is_speech) tuple
        """
        if self._model is None:
            return 0.0, False

        # Convert to float32 tensor
        audio = torch.from_numpy(pcm16.astype(np.float32) / 32768.0)

        # Silero expects exactly 512 samples at 16kHz
        if len(audio) != CHUNK_SAMPLES:
            # Pad or truncate
            if len(audio) < CHUNK_SAMPLES:
                audio = torch.nn.functional.pad(audio, (0, CHUNK_SAMPLES - len(audio)))
            else:
                audio = audio[:CHUNK_SAMPLES]

        score = float(self._model(audio, SAMPLE_RATE))

        # Update speech state with hysteresis
        frame_is_speech = score >= self._threshold
        if frame_is_speech:
            self._speech_frames += 1
            self._silence_frames = 0
        else:
            self._silence_frames += 1

        if not self._is_speech:
            if self._speech_frames >= self._speech_start_frames:
                self._is_speech = True
        else:
            if self._silence_frames >= self._speech_hang_frames:
                self._is_speech = False
                self._speech_frames = 0

        return score, self._is_speech

    @property
    def threshold(self) -> float:
        return self._threshold

    @threshold.setter
    def threshold(self, value: float) -> None:
        self._threshold = max(0.01, min(0.99, value))


# ---------------------------------------------------------------------------
# WebSocket handler
# ---------------------------------------------------------------------------

class VADSession:
    """One WebSocket client session."""

    def __init__(self, vad: SileroVAD) -> None:
        self.vad = vad
        self._chunk_buffer = bytearray()

    async def handle(self, ws) -> None:
        """Handle a WebSocket connection."""
        logger.info("VAD client connected")

        # Reset state for new client
        self.vad.reset()

        # Send ready
        await ws.send(json.dumps({
            "type": "ready",
            "model": "silero_vad",
            "sample_rate": SAMPLE_RATE,
            "chunk_samples": CHUNK_SAMPLES,
        }))

        try:
            async for message in ws:
                if isinstance(message, bytes):
                    await self._on_audio(ws, message)
                elif isinstance(message, str):
                    await self._on_json(ws, message)
        except Exception as e:
            logger.error("VAD session error: %s", e)
        finally:
            logger.info("VAD client disconnected")

    async def _on_json(self, ws, raw: str) -> None:
        try:
            msg = json.loads(raw)
        except json.JSONDecodeError:
            return

        msg_type = msg.get("type", "")

        if msg_type == "config":
            if "threshold" in msg:
                self.vad.threshold = float(msg["threshold"])
                logger.info("VAD threshold: %.2f", self.vad.threshold)
        elif msg_type == "reset":
            self.vad.reset()

    async def _on_audio(self, ws, data: bytes) -> None:
        """Process incoming audio and return VAD score."""
        self._chunk_buffer.extend(data)

        # Process in CHUNK_SAMPLES-sized blocks
        chunk_bytes = CHUNK_SAMPLES * 2  # 2 bytes per int16 sample
        while len(self._chunk_buffer) >= chunk_bytes:
            chunk = self._chunk_buffer[:chunk_bytes]
            self._chunk_buffer = self._chunk_buffer[chunk_bytes:]

            pcm = np.frombuffer(bytes(chunk), dtype=np.int16)
            score, is_speech = self.vad.process_chunk(pcm)

            await ws.send(json.dumps({
                "type": "vad",
                "score": round(score, 4),
                "is_speech": is_speech,
            }))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

async def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="EXO Silero VAD Server")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--threshold", type=float, default=0.5,
                        help="VAD threshold (0.01-0.99)")
    args = parser.parse_args()

    vad = SileroVAD()
    vad.threshold = args.threshold
    vad.load()

    async def handler(ws):
        session = VADSession(vad)
        await session.handle(ws)

    try:
        import websockets
    except ImportError:
        logger.error("websockets not installed. Run: pip install websockets")
        return

    server = await websockets.serve(handler, args.host, args.port)
    logger.info("VAD server running on ws://%s:%d (threshold=%.2f)",
                args.host, args.port, vad.threshold)

    try:
        await asyncio.Future()
    except KeyboardInterrupt:
        pass
    finally:
        server.close()
        await server.wait_closed()
        logger.info("VAD server stopped")


if __name__ == "__main__":
    asyncio.run(main())
