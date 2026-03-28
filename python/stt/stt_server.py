"""
stt_server.py — EXO STT Streaming Server (dual backend: whisper.cpp GPU / faster-whisper CPU)

WebSocket server that receives audio chunks (PCM16 16kHz mono)
and returns streaming transcription results.

Backends:
  - whispercpp: Whisper.cpp + Vulkan GPU (default, fast)
  - faster_whisper: faster-whisper CPU (fallback)

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
  pip install websockets numpy
  (faster-whisper only needed when backend=faster_whisper)
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

# Singleton guard — prevent duplicate instances
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from shared.singleton_guard import ensure_single_instance

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [STT] %(levelname)s %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("exo.stt")

# ---------------------------------------------------------------------------
# Noise reduction (optional)
# ---------------------------------------------------------------------------

_noisereduce_available = False
try:
    import noisereduce as nr
    _noisereduce_available = True
except ImportError:
    pass


def _apply_noise_reduction(pcm16: np.ndarray, sr: int = 16000,
                           strength: float = 0.7) -> np.ndarray:
    """Apply spectral-gating noise reduction to PCM16 audio."""
    if not _noisereduce_available or strength <= 0:
        return pcm16

    audio_f32 = pcm16.astype(np.float32) / 32768.0
    try:
        cleaned = nr.reduce_noise(
            y=audio_f32,
            sr=sr,
            prop_decrease=strength,
            stationary=True,
            n_fft=512,
            hop_length=128,
        )
        return (cleaned * 32768.0).clip(-32768, 32767).astype(np.int16)
    except Exception as e:
        logger.warning("Noise reduction failed: %s", e)
        return pcm16

# ---------------------------------------------------------------------------
# Configuration defaults
# ---------------------------------------------------------------------------

DEFAULT_HOST = "localhost"
DEFAULT_PORT = 8766
DEFAULT_MODEL = "medium"        # medium = 700MB RAM, good quality — was large-v3 (~2GB)
DEFAULT_LANGUAGE = "fr"
DEFAULT_BEAM_SIZE = 3
DEFAULT_DEVICE = "auto"          # "cpu", "cuda", "auto"
DEFAULT_COMPUTE_TYPE = "int8"    # int8 = fast CPU, float16 = CUDA
DEFAULT_BACKEND = "whispercpp"   # "whispercpp" (Vulkan GPU) or "faster_whisper" (CPU) or "whispercpp_cpu"
SAMPLE_RATE = 16000
NOISE_REDUCTION_STRENGTH = 0.7   # 0.0 = off, 1.0 = max

# ---------------------------------------------------------------------------
# Hallucination filter
# ---------------------------------------------------------------------------

_HALLUCINATION_PATTERNS = [
    "sous-titres", "sous-titrage", "amara.org", "amara org",
    "merci d'avoir regardé", "merci de regarder",
    "n'hésitez pas à", "abonnez-vous", "likez",
    "copyright", "tous droits réservés", "bonne vidéo",
    "à bientôt", "à la prochaine",
    "transcrit par", "traduit par", "sous-titré par",
    "www.", "http", ".com", ".org", ".fr",
    "musique", "♪", "♫",
    "merci à tous", "merci beaucoup pour",
    "si vous avez aimé", "partagez cette vidéo",
]


def _is_hallucination(text: str) -> bool:
    """Reject common Whisper hallucinations (subtitle credits, etc.)."""
    if not text:
        return False
    lower = text.lower().strip()
    if len(lower) < 2:
        return True
    # Reject repeated short words (e.g., "Merci. Merci. Merci.")
    words = lower.split()
    if len(words) >= 3 and len(set(words)) == 1:
        return True
    for pat in _HALLUCINATION_PATTERNS:
        if pat in lower:
            return True
    return False


# ---------------------------------------------------------------------------
# STT Engine wrapper (dual backend)
# ---------------------------------------------------------------------------

class STTEngine:
    """Wraps either whisper.cpp (Vulkan GPU) or faster-whisper (CPU)."""

    def __init__(
        self,
        model_size: str = DEFAULT_MODEL,
        device: str = DEFAULT_DEVICE,
        compute_type: str = DEFAULT_COMPUTE_TYPE,
        language: str = DEFAULT_LANGUAGE,
        beam_size: int = DEFAULT_BEAM_SIZE,
        backend: str = DEFAULT_BACKEND,
    ) -> None:
        self.model_size = model_size
        self.device = device
        self.compute_type = compute_type
        self.language = language
        self.beam_size = beam_size
        self.backend = backend
        self._engine = None        # underlying engine (WhisperCppEngine or WhisperModel)
        self._actual_device = "unknown"
        self._active_backend = "unknown"

    def load(self) -> None:
        """Load the STT backend."""
        if self.backend == "whispercpp":
            self._load_whispercpp()
        elif self.backend == "whispercpp_cpu":
            self._load_whispercpp(use_gpu=False)
        elif self.backend == "faster_whisper":
            self._load_faster_whisper()
        else:
            logger.warning("Unknown backend '%s', trying whispercpp then faster_whisper", self.backend)
            try:
                self._load_whispercpp()
            except Exception as e:
                logger.warning("whispercpp failed (%s), falling back to faster_whisper", e)
                self._load_faster_whisper()

    def _load_whispercpp(self, use_gpu: bool = True) -> None:
        """Load whisper.cpp backend (Vulkan GPU or CPU)."""
        from whisper_cpp import WhisperCppEngine

        # Resolve model path for whisper.cpp ggml format
        model_map = {
            "tiny": "ggml-tiny.bin",
            "base": "ggml-base.bin",
            "small": "ggml-small.bin",
            "medium": "ggml-medium.bin",
            "large-v3": "ggml-large-v3.bin",
            "large": "ggml-large-v3.bin",
        }
        model_file = model_map.get(self.model_size, f"ggml-{self.model_size}.bin")
        model_dir = Path(os.environ.get("EXO_WHISPER_MODELS", r"D:\EXO\models\whisper"))
        model_path = str(model_dir / model_file)

        if not os.path.isfile(model_path):
            raise FileNotFoundError(
                f"Whisper.cpp model not found: {model_path}. "
                f"Download it from https://huggingface.co/ggerganov/whisper.cpp"
            )

        self._engine = WhisperCppEngine(
            model_path=model_path,
            language=self.language,
            beam_size=self.beam_size,
        )
        self._engine.load()
        self._actual_device = "vulkan" if use_gpu else "cpu"
        self._active_backend = "whispercpp" if use_gpu else "whispercpp_cpu"
        model_size_mb = os.path.getsize(model_path) / (1024 * 1024)
        logger.info("STT model: %s (%.0fMB) — device: %s — beam_size: %d",
                     self.model_size, model_size_mb, self._actual_device, self.beam_size)

    def _load_faster_whisper(self) -> None:
        """Load faster-whisper CPU backend."""
        try:
            from faster_whisper import WhisperModel
        except ImportError:
            logger.error("faster-whisper not installed. Run: pip install faster-whisper")
            raise

        device = self.device
        compute = self.compute_type

        if device == "auto":
            try:
                import torch
                device = "cuda" if torch.cuda.is_available() else "cpu"
            except ImportError:
                device = "cpu"

        if device == "cpu":
            compute = "int8"

        logger.info(
            "Loading faster-whisper model '%s' on %s (%s)...",
            self.model_size, device, compute,
        )
        t0 = time.monotonic()
        self._engine = WhisperModel(
            self.model_size,
            device=device,
            compute_type=compute,
        )
        self._actual_device = device
        self._active_backend = "faster_whisper"
        dt = time.monotonic() - t0
        logger.info("Model loaded in %.1fs (backend: faster-whisper, device: %s)", dt, device)

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
        if self._engine is None:
            raise RuntimeError("Engine not loaded")

        if self._active_backend == "whispercpp":
            result = self._engine.transcribe(audio_pcm16)
        else:
            result = self._transcribe_faster_whisper(audio_pcm16, initial_prompt)

        # Filter hallucinations regardless of backend
        if result["text"] and _is_hallucination(result["text"]):
            logger.info("Hallucination filtered: %s", result["text"][:60])
            result["text"] = ""
            result["segments"] = []

        return result

    def _transcribe_faster_whisper(
        self,
        audio_pcm16: np.ndarray,
        initial_prompt: str | None = None,
    ) -> dict:
        """Transcribe using faster-whisper backend."""
        audio_f32 = audio_pcm16.astype(np.float32) / 32768.0
        duration = len(audio_f32) / SAMPLE_RATE

        if duration < 0.3:
            logger.warning("Audio %.2fs < 0.3s threshold — ignoré", duration)
            return {"text": "", "segments": [], "duration": duration}

        t0 = time.monotonic()
        prompt = initial_prompt or "EXO est un assistant vocal domotique français. Jarvis, allume, éteins, météo, température, lumière."
        segments_gen, info = self._engine.transcribe(
            audio_f32,
            language=self.language,
            beam_size=self.beam_size,
            word_timestamps=False,
            initial_prompt=prompt,
            condition_on_previous_text=False,
            no_speech_threshold=0.4,
            log_prob_threshold=-1.0,
            vad_filter=True,
            vad_parameters={
                "min_silence_duration_ms": 600,
                "speech_pad_ms": 300,
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

    def close(self) -> None:
        """Clean up resources."""
        if self._active_backend == "whispercpp" and self._engine:
            self._engine.close()
            self._engine = None


# ---------------------------------------------------------------------------
# WebSocket session handler
# ---------------------------------------------------------------------------

MAX_CONSECUTIVE_HALLUCINATIONS = 3   # stop partials after N hallucinations in a row


class STTSession:
    """One WebSocket client session."""

    def __init__(self, engine: STTEngine) -> None:
        self.engine = engine
        self._audio_buffer = bytearray()
        self._recording = False
        self._partial_interval = 2.0  # seconds between partial results
        self._last_partial_time = 0.0
        self._consecutive_hallucinations = 0

    async def handle(self, ws) -> None:
        """Handle a WebSocket connection."""
        logger.info("STT client connected")

        # Send ready message
        await ws.send(json.dumps({
            "type": "ready",
            "model": self.engine.model_size,
            "device": self.engine.actual_device,
            "backend": self.engine._active_backend,
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
            self._consecutive_hallucinations = 0
            logger.debug("Recording started")

        elif msg_type == "end":
            self._recording = False
            await self._finalize(ws)

        elif msg_type == "cancel":
            self._recording = False
            self._audio_buffer.clear()
            logger.debug("Recording cancelled")

        elif msg_type == "ping":
            await ws.send(json.dumps({"type": "pong"}))

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

        # Stop partial loop after too many consecutive hallucinations
        if self._consecutive_hallucinations >= MAX_CONSECUTIVE_HALLUCINATIONS:
            return

        pcm = np.frombuffer(bytes(self._audio_buffer), dtype=np.int16)
        try:
            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(
                None, lambda: self.engine.transcribe(pcm)
            )
            if result["text"]:
                self._consecutive_hallucinations = 0
                await ws.send(json.dumps({
                    "type": "partial",
                    "text": result["text"],
                }))
            else:
                # Hallucination was filtered (text="") — count it
                self._consecutive_hallucinations += 1
                if self._consecutive_hallucinations >= MAX_CONSECUTIVE_HALLUCINATIONS:
                    logger.warning(
                        "Stopped partials after %d consecutive hallucinations",
                        self._consecutive_hallucinations,
                    )
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

        # ── DSP: Noise reduction ──
        pcm = _apply_noise_reduction(pcm, SAMPLE_RATE, NOISE_REDUCTION_STRENGTH)

        # ── Gain normalization: boost quiet audio to ~80% peak ──
        peak = int(np.max(np.abs(pcm)))
        if peak > 0:
            target_peak = int(32768 * 0.8)  # -2 dBFS
            if peak < target_peak:
                gain = target_peak / peak
                gain = min(gain, 40.0)  # cap at ~32 dB boost
                pcm = np.clip(pcm.astype(np.float64) * gain, -32768, 32767).astype(np.int16)

        # ── DEBUG: PCM statistics ──
        rms = np.sqrt(np.mean(pcm.astype(np.float64) ** 2))
        peak = int(np.max(np.abs(pcm)))
        dur = len(pcm) / SAMPLE_RATE
        logger.info("PCM stats: samples=%d dur=%.2fs rms=%.1f peak=%d (%.1f dBFS)",
                     len(pcm), dur, rms, peak,
                     20 * np.log10(max(peak, 1) / 32768))
        try:
            loop = asyncio.get_event_loop()
            t0 = time.monotonic()
            result = await asyncio.wait_for(
                loop.run_in_executor(
                    None, lambda: self.engine.transcribe(pcm)
                ),
                timeout=20.0
            )
            transcribe_ms = (time.monotonic() - t0) * 1000
            logger.info("[STT] transcribe_done dur=%.0fms text_len=%d result=%s",
                        transcribe_ms, len(result["text"]), result["text"][:60])
            await ws.send(json.dumps({
                "type": "final",
                "text": result["text"],
                "segments": result["segments"],
                "duration": result["duration"],
                "transcribe_ms": round(transcribe_ms),
            }))
        except asyncio.TimeoutError:
            logger.error("Final transcription timeout after 20s")
            await ws.send(json.dumps({
                "type": "error",
                "message": "Transcription timeout (20s)",
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
    global NOISE_REDUCTION_STRENGTH

    import argparse

    parser = argparse.ArgumentParser(description="EXO STT Server (whisper.cpp GPU / faster-whisper CPU)")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--model", default=DEFAULT_MODEL,
                        help="Whisper model size (tiny, base, small, medium, large-v3)")
    parser.add_argument("--language", default=DEFAULT_LANGUAGE)
    parser.add_argument("--device", default=DEFAULT_DEVICE,
                        help="Compute device (cpu, cuda, auto) — only for faster_whisper backend")
    parser.add_argument("--compute-type", default=DEFAULT_COMPUTE_TYPE)
    parser.add_argument("--beam-size", type=int, default=DEFAULT_BEAM_SIZE)
    parser.add_argument("--backend", default=DEFAULT_BACKEND,
                        choices=["whispercpp", "faster_whisper", "whispercpp_cpu", "auto"],
                        help="STT backend: whispercpp (Vulkan GPU), whispercpp_cpu (CPU), faster_whisper (CPU), auto")
    parser.add_argument("--noise-reduction", type=float, default=NOISE_REDUCTION_STRENGTH,
                        help="Noise reduction strength (0.0=off, 1.0=max)")
    args = parser.parse_args()

    # Prevent duplicate instances
    ensure_single_instance(args.port, "stt_server")

    # Apply noise reduction config
    nr_strength = args.noise_reduction
    NOISE_REDUCTION_STRENGTH = nr_strength
    if _noisereduce_available and nr_strength > 0:
        logger.info("Noise reduction enabled (strength=%.2f)", NOISE_REDUCTION_STRENGTH)
    elif not _noisereduce_available:
        logger.info("Noise reduction unavailable (pip install noisereduce)")

    engine = STTEngine(
        model_size=args.model,
        device=args.device,
        compute_type=args.compute_type,
        language=args.language,
        beam_size=args.beam_size,
        backend=args.backend,
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

    server = await websockets.serve(
        handler, args.host, args.port,
        ping_interval=None, ping_timeout=None,    # localhost — no keepalive needed
        max_size=10 * 1024 * 1024,                # 10 MB max message
    )
    logger.info("STT server running on ws://%s:%d (model=%s, device=%s, backend=%s)",
                args.host, args.port, args.model, engine.actual_device, engine._active_backend)

    try:
        await asyncio.Future()  # run forever
    except KeyboardInterrupt:
        pass
    finally:
        server.close()
        await server.wait_closed()
        engine.close()
        logger.info("STT server stopped")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
