"""
tts_server_directml.py — EXO TTS Server (XTTS v2 + ONNX Runtime DirectML)

GPU-accelerated TTS for Windows with AMD GPU (RX 6750 XT).
No ROCm, no CUDA, no WSL2 — PyTorch CPU + ONNX Runtime DirectML.

Architecture:
  - Text → GPT latent codes:  PyTorch CPU  (autoregressive, cannot be ONNX'd)
  - Latent codes → Audio:     ONNX Runtime DirectML  (HiFi-GAN vocoder on GPU)
  - Fallback:                 CPU PyTorch if DirectML unavailable

WebSocket (ws://0.0.0.0:8767) protocol — identical to tts_server.py:
  → JSON:   {"type": "synthesize", "text": "...", "voice": "...", "lang": "..."}
             {"type": "cancel"}
             {"type": "list_voices"}
  ← Binary: PCM16 24kHz mono chunks (streamed)
  ← JSON:   {"type": "start",  "text": "..."}
             {"type": "end",    "duration": float}
             {"type": "voices", "available": [...]}
             {"type": "ready",  "voice": "...", "sample_rate": 24000}
             {"type": "error",  "message": "..."}

Installation:
  pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu
  pip install TTS websockets numpy
  pip uninstall onnxruntime -y
  pip install onnxruntime-directml onnx

Usage:
  python python/tts/tts_server_directml.py --voice "Claribel Dervla" --lang fr
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import time
from pathlib import Path
from typing import Optional

import numpy as np
import torch

# ---------------------------------------------------------------------------
# PyTorch >= 2.4 compat: Coqui TTS uses torch.inference_mode() internally,
# but recent PyTorch raises "Cannot set version_counter for inference tensor".
# ---------------------------------------------------------------------------
torch.inference_mode = torch.no_grad  # type: ignore[assignment]

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [TTS-DML] %(levelname)s %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("exo.tts.directml")

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

DEFAULT_HOST = "0.0.0.0"
DEFAULT_PORT = 8767
DEFAULT_VOICE = "Claribel Dervla"
DEFAULT_LANG = "fr"
XTTS_SAMPLE_RATE = 24000
OUTPUT_SAMPLE_RATE = 24000
CHUNK_SIZE = 4096

SUPPORTED_LANGUAGES = [
    "en", "es", "fr", "de", "it", "pt", "pl", "tr",
    "ru", "nl", "cs", "ar", "zh-cn", "hu", "ko", "ja", "hi",
]


import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from shared.cache import PhraseCache


# ---------------------------------------------------------------------------
# ONNX export helper — wraps HiFi-GAN for clean positional-arg export
# ---------------------------------------------------------------------------

class _HiFiGanForExport(torch.nn.Module):
    """Converts keyword arg ``g=`` to positional for torch.onnx.export."""

    def __init__(self, decoder: torch.nn.Module):
        super().__init__()
        self.decoder = decoder

    def forward(
        self, latents: torch.Tensor, speaker_embedding: torch.Tensor
    ) -> torch.Tensor:
        return self.decoder(latents, g=speaker_embedding)


# ---------------------------------------------------------------------------
# DirectML-accelerated vocoder
# ---------------------------------------------------------------------------

class DirectMLVocoder(torch.nn.Module):
    """
    Replaces the PyTorch HiFi-GAN decoder with an ONNX Runtime DirectML
    session for GPU-accelerated audio generation.

    Workflow:
      1. Export HiFi-GAN to ONNX (once, cached on disk)
      2. Load ONNX model with DmlExecutionProvider → AMD GPU
      3. forward() runs vocoder on GPU, returns torch.Tensor
      4. Falls back to original PyTorch decoder on any failure
    """

    def __init__(
        self,
        decoder: torch.nn.Module,
        cache_dir: str,
        latent_dim: int = 1024,
        speaker_dim: int = 512,
    ):
        super().__init__()
        self._fallback = decoder
        self._session = None
        self.active_backend = "cpu_pytorch"

        onnx_path = os.path.join(cache_dir, "hifigan_directml.onnx")
        os.makedirs(cache_dir, exist_ok=True)

        try:
            self._export(decoder, onnx_path, latent_dim, speaker_dim)
            self._load_session(onnx_path)
        except Exception as e:
            logger.warning("DirectML vocoder setup failed: %s", e)
            logger.info("Falling back to CPU PyTorch vocoder")

    # -- ONNX export -------------------------------------------------------

    def _export(
        self, decoder: torch.nn.Module, path: str,
        latent_dim: int, speaker_dim: int,
    ) -> None:
        if os.path.exists(path):
            sz = os.path.getsize(path) / (1024 * 1024)
            logger.info("Cached ONNX vocoder (%.1f MB): %s", sz, path)
            return

        logger.info("Exporting HiFi-GAN to ONNX (latent=%d, spk=%d)...",
                     latent_dim, speaker_dim)

        wrapper = _HiFiGanForExport(decoder)
        wrapper.eval()

        # Dummy inputs — HifiDecoder expects latents [B, T, 1024], g [B, 512, 1]
        dummy_latents = torch.randn(1, 50, latent_dim)
        dummy_g = torch.randn(1, speaker_dim, 1)

        with torch.no_grad():
            torch.onnx.export(
                wrapper,
                (dummy_latents, dummy_g),
                path,
                input_names=["latents", "speaker_embedding"],
                output_names=["audio"],
                dynamic_axes={
                    "latents": {0: "batch", 1: "time"},
                    "speaker_embedding": {0: "batch"},
                    "audio": {0: "batch", 2: "audio_length"},
                },
                opset_version=17,
                do_constant_folding=True,
            )

        sz = os.path.getsize(path) / (1024 * 1024)
        logger.info("ONNX vocoder exported (%.1f MB): %s", sz, path)

    # -- ONNX Runtime session -----------------------------------------------

    def _load_session(self, path: str) -> None:
        import onnxruntime as ort

        available = ort.get_available_providers()
        logger.info("ORT providers available: %s", available)

        if "DmlExecutionProvider" in available:
            providers = ["DmlExecutionProvider", "CPUExecutionProvider"]
        else:
            providers = ["CPUExecutionProvider"]
            logger.warning(
                "DmlExecutionProvider absent — "
                "run: pip install onnxruntime-directml"
            )

        self._session = ort.InferenceSession(path, providers=providers)
        active = self._session.get_providers()

        if "DmlExecutionProvider" in active:
            self.active_backend = "directml_gpu"
            logger.info("HiFi-GAN vocoder: DirectML GPU (AMD)")
        else:
            self.active_backend = "onnx_cpu"
            logger.info("HiFi-GAN vocoder: ONNX CPU")

    # -- Inference -----------------------------------------------------------

    def forward(self, latents: torch.Tensor, g=None) -> torch.Tensor:
        if self._session is None:
            return self._fallback(latents, g=g)

        try:
            lat_np = latents.detach().cpu().numpy().astype(np.float32)
            feeds: dict[str, np.ndarray] = {"latents": lat_np}
            if g is not None:
                feeds["speaker_embedding"] = (
                    g.detach().cpu().numpy().astype(np.float32)
                )

            result = self._session.run(None, feeds)
            return torch.from_numpy(result[0])
        except Exception as e:
            logger.warning("DirectML inference failed, CPU fallback: %s", e)
            return self._fallback(latents, g=g)


# ---------------------------------------------------------------------------
# XTTS v2 Engine with DirectML vocoder
# ---------------------------------------------------------------------------

class XTTSDirectMLEngine:
    """XTTS v2 with DirectML-accelerated HiFi-GAN vocoder."""

    _EMOJI_RE = re.compile(
        "[\U0001F600-\U0001F64F\U0001F300-\U0001F5FF\U0001F680-\U0001F6FF"
        "\U0001F1E0-\U0001F1FF\U00002702-\U000027B0\U000024C2-\U0001F251"
        "\U0001F900-\U0001F9FF\U0001FA00-\U0001FA6F\U0001FA70-\U0001FAFF"
        "\U00002600-\U000026FF\U0000FE00-\U0000FE0F\U0000200D]+"
    )

    def __init__(self, voice: str = DEFAULT_VOICE, lang: str = DEFAULT_LANG):
        self.voice_name = voice
        self.language = lang
        self.model = None
        self.speakers: dict = {}
        self._loaded = False
        self._cache = PhraseCache()
        self.vocoder_backend = "not_loaded"

    def load(self) -> None:
        from TTS.api import TTS

        model_dir = os.environ.get("EXO_XTTS_MODELS", r"D:\EXO\models\xtts")

        # -- Load XTTS v2 on CPU -------------------------------------------
        logger.info("Loading XTTS v2 model on CPU...")
        t0 = time.monotonic()

        tts_api = TTS(
            model_name="tts_models/multilingual/multi-dataset/xtts_v2",
            progress_bar=False,
        )
        self.model = tts_api.synthesizer.tts_model
        self.model.to("cpu")
        self.model.eval()

        load_s = time.monotonic() - t0
        logger.info("Model loaded in %.1fs", load_s)

        # -- Load speaker embeddings ---------------------------------------
        spk_file = os.path.join(model_dir, "speakers_xtts.pth")
        if os.path.exists(spk_file):
            self.speakers = torch.load(spk_file, weights_only=False)
            logger.info(
                "Loaded %d speakers from %s", len(self.speakers), spk_file
            )
        else:
            logger.warning("No speakers file at %s", spk_file)

        # -- Detect latent/speaker dimensions from actual data -------------
        latent_dim, speaker_dim = 1024, 512
        if self.speakers:
            sample = next(iter(self.speakers.values()))
            cond = sample.get("gpt_cond_latent")
            emb = sample.get("speaker_embedding")
            if cond is not None:
                latent_dim = cond.shape[-1]
            if emb is not None:
                speaker_dim = emb.shape[1]
            logger.info(
                "Detected dimensions: latent=%d, speaker=%d",
                latent_dim, speaker_dim,
            )

        # -- Replace HiFi-GAN with DirectML vocoder -----------------------
        onnx_cache = os.path.join(model_dir, "onnx_cache")
        vocoder = DirectMLVocoder(
            self.model.hifigan_decoder,
            onnx_cache,
            latent_dim=latent_dim,
            speaker_dim=speaker_dim,
        )
        self.model.hifigan_decoder = vocoder
        self.vocoder_backend = vocoder.active_backend

        # -- Set initial voice ---------------------------------------------
        self.set_voice(self.voice_name)
        self._loaded = True

        # -- Banner --------------------------------------------------------
        print("=" * 60)
        print("  XTTS DirectML READY")
        print(f"  Voice   : {self.voice_name}")
        print(f"  Lang    : {self.language}")
        print(f"  Speakers: {len(self.speakers)}")
        print(f"  GPT     : CPU (PyTorch {torch.__version__})")
        print(f"  Vocoder : {self.vocoder_backend}")
        print("=" * 60)

    # -- Voice / language management ----------------------------------------

    def set_voice(self, voice: str) -> bool:
        if voice in self.speakers:
            self.voice_name = voice
            logger.info("Voice set: %s", voice)
            return True
        for name in self.speakers:
            if name.lower() == voice.lower():
                self.voice_name = name
                logger.info("Voice set: %s", name)
                return True
        logger.warning("Speaker '%s' not found, keeping '%s'", voice, self.voice_name)
        return False

    def set_language(self, lang: str) -> None:
        if lang in SUPPORTED_LANGUAGES:
            self.language = lang
            logger.info("Language set: %s", lang)

    def list_voices(self) -> list[str]:
        return sorted(self.speakers.keys())

    # -- Synthesis ----------------------------------------------------------

    def synthesize(
        self,
        text: str,
        voice: Optional[str] = None,
        lang: Optional[str] = None,
        rate: float = 1.0,
        pitch: float = 1.0,
    ) -> bytes:
        """Synthesize text → PCM16 24 kHz mono bytes."""
        if not self._loaded or not self.model:
            raise RuntimeError("Model not loaded")

        text = self._EMOJI_RE.sub("", text).strip()
        if not text:
            return b""

        use_voice = (
            voice if voice and voice in self.speakers else self.voice_name
        )
        use_lang = (
            lang if lang and lang in SUPPORTED_LANGUAGES else self.language
        )

        # Cache lookup
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

        # Tensor → numpy
        if hasattr(wav, "cpu"):
            wav = wav.cpu()
        if hasattr(wav, "numpy"):
            wav = wav.numpy()
        wav = np.asarray(wav, dtype=np.float32).squeeze()

        # Pitch shift if needed
        if abs(pitch - 1.0) > 0.05:
            wav = self._pitch_shift(wav, pitch)

        # float32 → int16 PCM
        pcm = np.clip(wav * 32767, -32768, 32767).astype(np.int16)
        raw = pcm.tobytes()

        dt = time.monotonic() - t0
        duration = len(raw) / (OUTPUT_SAMPLE_RATE * 2)
        logger.info(
            "Synth %.1fs audio in %.2fs (RTF=%.2f) voice=%s lang=%s: %s",
            duration, dt, dt / max(duration, 0.01),
            use_voice, use_lang, text[:60],
        )

        self._cache.put(text, use_voice, use_lang, raw)
        return raw

    @staticmethod
    def _pitch_shift(samples: np.ndarray, factor: float) -> np.ndarray:
        n = int(len(samples) / factor)
        if n < 1:
            return samples
        idx = np.linspace(0, len(samples) - 1, n)
        f = idx.astype(np.int64)
        c = np.minimum(f + 1, len(samples) - 1)
        frac = (idx - f).astype(np.float32)
        return samples[f] * (1 - frac) + samples[c] * frac


# ---------------------------------------------------------------------------
# WebSocket session handler
# ---------------------------------------------------------------------------

class TTSSession:
    def __init__(self, engine: XTTSDirectMLEngine):
        self.engine = engine
        self._cancel = False

    async def handle(self, ws) -> None:
        logger.info("Client connected")

        await ws.send(json.dumps({
            "type": "ready",
            "voice": self.engine.voice_name,
            "sample_rate": OUTPUT_SAMPLE_RATE,
            "backend": "xtts_v2_directml",
            "vocoder": self.engine.vocoder_backend,
            "languages": SUPPORTED_LANGUAGES,
        }))

        try:
            async for message in ws:
                if isinstance(message, str):
                    await self._dispatch(ws, message)
        except Exception as e:
            logger.error("Session error: %s", e)
        finally:
            logger.info("Client disconnected")

    async def _dispatch(self, ws, raw: str) -> None:
        try:
            msg = json.loads(raw)
        except json.JSONDecodeError:
            return

        t = msg.get("type", "")

        if t == "synthesize":
            self._cancel = False
            await self._synth_and_stream(ws, msg)
        elif t == "cancel":
            self._cancel = True
        elif t == "list_voices":
            await ws.send(json.dumps({
                "type": "voices",
                "available": self.engine.list_voices(),
            }))
        elif t == "set_voice":
            ok = self.engine.set_voice(msg.get("voice", ""))
            await ws.send(json.dumps({
                "type": "voice_changed",
                "voice": self.engine.voice_name,
                "success": ok,
            }))
        elif t == "set_language":
            self.engine.set_language(msg.get("lang", ""))
            await ws.send(json.dumps({
                "type": "language_changed",
                "lang": self.engine.language,
            }))

    async def _synth_and_stream(self, ws, msg: dict) -> None:
        text = msg.get("text", "").strip()
        if not text:
            await ws.send(json.dumps({
                "type": "error", "message": "Empty text"
            }))
            return

        try:
            await ws.send(json.dumps({"type": "start", "text": text}))

            loop = asyncio.get_event_loop()
            t0 = time.monotonic()
            pcm = await loop.run_in_executor(
                None,
                lambda: self.engine.synthesize(
                    text,
                    msg.get("voice"),
                    msg.get("lang"),
                    float(msg.get("rate", 1.0)),
                    float(msg.get("pitch", 1.0)),
                ),
            )
            synth_ms = (time.monotonic() - t0) * 1000

            if self._cancel:
                return

            # Stream audio in chunks
            offset = 0
            while offset < len(pcm):
                if self._cancel:
                    return
                await ws.send(pcm[offset : offset + CHUNK_SIZE])
                offset += CHUNK_SIZE
                await asyncio.sleep(0)

            duration = len(pcm) / (OUTPUT_SAMPLE_RATE * 2)
            await ws.send(json.dumps({
                "type": "end",
                "duration": round(duration, 2),
                "synth_ms": round(synth_ms),
            }))

        except Exception as e:
            logger.error("Synthesis error: %s", e)
            try:
                await ws.send(json.dumps({
                    "type": "error", "message": str(e),
                }))
            except Exception:
                pass


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

async def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(
        description="EXO TTS Server — XTTS v2 + ONNX Runtime DirectML"
    )
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument(
        "--voice", default=DEFAULT_VOICE,
        help="Speaker name (default: Claribel Dervla)",
    )
    parser.add_argument(
        "--lang", default=DEFAULT_LANG,
        help="Default language (default: fr)",
    )
    args = parser.parse_args()

    engine = XTTSDirectMLEngine(voice=args.voice, lang=args.lang)
    engine.load()

    import websockets

    async def handler(ws):
        session = TTSSession(engine)
        await session.handle(ws)

    server = await websockets.serve(
        handler, args.host, args.port,
        ping_interval=None, ping_timeout=None,
    )
    logger.info(
        "Listening on ws://%s:%d  voice=%s lang=%s vocoder=%s",
        args.host, args.port, args.voice, args.lang, engine.vocoder_backend,
    )

    try:
        await asyncio.Future()
    except KeyboardInterrupt:
        pass
    finally:
        server.close()
        await server.wait_closed()
        logger.info("Server stopped")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
