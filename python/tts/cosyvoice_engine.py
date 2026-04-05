"""
cosyvoice_engine.py — CosyVoice 2 engine for EXO TTS server

Drop-in replacement for XTTSEngine. Uses CosyVoice2-0.5B with streaming
inference for low-latency token-level audio generation on CUDA.

Audio output: PCM16 24 kHz mono — identical to the previous XTTS v2 backend.
"""

from __future__ import annotations

import logging
import os
import time
from pathlib import Path
from typing import Optional

import numpy as np
import torch

logger = logging.getLogger("exo.tts")

# Audio constants — must match C++ TTSManager expectations
COSYVOICE_SAMPLE_RATE = 24000  # CosyVoice2-0.5B native rate (from yaml)
OUTPUT_SAMPLE_RATE = 24000
CHUNK_FRAMES = 1024  # ~21 ms @ 24 kHz mono16


class CosyVoiceEngine:
    """CosyVoice 2 streaming TTS engine for EXO.

    API contract (identical to former XTTSEngine):
      - load()             → warm the model on CUDA
      - synthesize_stream() → yield PCM16 bytes chunks
      - synthesize()        → return full PCM16 bytes
      - warmup()           → silent GPU warm-up
      - set_voice() / set_language() / list_voices()
    """

    # Readiness phases (same as previous XTTSEngine for compatibility)
    PHASE_INIT = "ready_init"
    PHASE_LOADING = "ready_loading"
    PHASE_WARMUP = "ready_warmup"
    PHASE_ONLINE = "ready_online"

    def __init__(self, voice: str = "", lang: str = "fr") -> None:
        self.voice_name = voice
        self.language = lang
        self.model = None  # CosyVoice2 instance
        self._loaded = False
        self.device = "cpu"
        self._last_synth_time = 0.0
        # Readiness
        self.phase = self.PHASE_INIT
        self._phase_callback = None
        self._profile: dict = {}
        # Cache (injected from tts_server)
        self._cache = None
        # Voice prompt for zero-shot cloning
        self._prompt_wav: Optional[str] = None
        self._prompt_text: str = ""
        # Available speakers from spk2info
        self._available_spks: list[str] = []

    # ------------------------------------------------------------------
    # Device detection
    # ------------------------------------------------------------------
    @staticmethod
    def _detect_device() -> str:
        if torch.cuda.is_available():
            name = torch.cuda.get_device_name(0)
            vram = torch.cuda.get_device_properties(0).total_memory / (1024**3)
            logger.info("CosyVoice CUDA device: %s (VRAM: %.1f GB)", name, vram)
            return "cuda"
        logger.warning("CUDA not available — falling back to CPU")
        return "cpu"

    # ------------------------------------------------------------------
    # Model loading
    # ------------------------------------------------------------------
    def load(self) -> None:
        """Load CosyVoice2-0.5B model and warm up GPU."""
        t_total = time.monotonic()

        # ── Phase 1: INIT ──
        self._set_phase(self.PHASE_INIT)
        t0 = time.monotonic()
        self.device = self._detect_device()
        self._profile["python_init_ms"] = (time.monotonic() - t0) * 1000

        # ── Phase 2: LOADING ──
        self._set_phase(self.PHASE_LOADING)
        t0 = time.monotonic()

        model_dir = os.environ.get(
            "EXO_COSYVOICE_MODELS",
            os.environ.get("EXO_XTTS_MODELS", r"D:\EXO\models\CosyVoice2-0.5B"),
        )
        logger.info("Loading CosyVoice2-0.5B from %s on %s …", model_dir, self.device)

        # CosyVoice is not a pip package — add repo root + Matcha-TTS to sys.path
        import sys
        cosyvoice_root = os.environ.get("COSYVOICE_ROOT", r"D:\EXO\CosyVoice")
        matcha_path = os.path.join(cosyvoice_root, "third_party", "Matcha-TTS")
        for p in (cosyvoice_root, matcha_path):
            if p not in sys.path and os.path.isdir(p):
                sys.path.insert(0, p)
                logger.info("Added to sys.path: %s", p)

        from cosyvoice.cli.cosyvoice import CosyVoice2 as _CosyVoice2

        self.model = _CosyVoice2(model_dir=model_dir, load_jit=False, fp16=False)
        self._profile["model_load_ms"] = (time.monotonic() - t0) * 1000
        logger.info("CosyVoice2-0.5B loaded in %.0f ms", self._profile["model_load_ms"])

        # Verify sample rate
        native_sr = getattr(self.model, "sample_rate", COSYVOICE_SAMPLE_RATE)
        if native_sr != OUTPUT_SAMPLE_RATE:
            logger.warning(
                "CosyVoice2 native sample rate %d ≠ expected %d — will resample",
                native_sr, OUTPUT_SAMPLE_RATE,
            )

        # Discover available speakers
        try:
            self._available_spks = self.model.list_available_spks()
            logger.info("Available speakers: %s", self._available_spks)
        except Exception:
            self._available_spks = []

        # Voice prompt for cross-lingual / zero-shot inference
        self._resolve_voice_prompt()

        # Register prompt WAV as a reusable zero-shot speaker (avoids
        # re-processing the WAV embedding on every inference call).
        if self._prompt_wav and os.path.isfile(self._prompt_wav):
            spk_id = "exo_default"
            try:
                self.model.add_zero_shot_spk(
                    self._prompt_text, self._prompt_wav, spk_id,
                )
                self._available_spks = self.model.list_available_spks()
                self.voice_name = spk_id
                logger.info("Registered zero-shot speaker '%s' from %s", spk_id, self._prompt_wav)
            except Exception as exc:
                logger.warning("Failed to register zero-shot speaker: %s", exc)

        # CUDA settings
        if torch.cuda.is_available():
            torch.backends.cudnn.benchmark = True
            torch.backends.cuda.matmul.allow_tf32 = True
            torch.backends.cudnn.allow_tf32 = True

        # ── Phase 3: WARMUP ──
        self._set_phase(self.PHASE_WARMUP)
        self._warmup_gpu()
        self._warmup_streaming()
        self._warmup_audio()

        self._loaded = True

        # ── Phase 4: ONLINE ──
        self._profile["total_ms"] = (time.monotonic() - t_total) * 1000
        self._set_phase(self.PHASE_ONLINE)

        logger.info(
            "CosyVoice2 ready — device=%s, voice=%s, lang=%s, speakers=%d",
            self.device, self.voice_name, self.language, len(self._available_spks),
        )
        if str(self.device).startswith("cuda"):
            logger.info("[TTS] CosyVoice2 backend: CUDA (RTX 3070)")
            logger.info("[GPU] TTS: CUDA → RTX 3070 (OK)")

        # Profiling report
        logger.info("═══ TTS STARTUP PROFILE ═══")
        for k, v in self._profile.items():
            logger.info("  %-25s %7.0f ms", k, v)
        logger.info("═══════════════════════════")

    # ------------------------------------------------------------------
    # Voice prompt resolution
    # ------------------------------------------------------------------
    def _resolve_voice_prompt(self) -> None:
        """Find the voice prompt WAV file for zero-shot / cross-lingual inference."""
        model_dir = os.environ.get(
            "EXO_COSYVOICE_MODELS",
            os.environ.get("EXO_XTTS_MODELS", r"D:\EXO\models\CosyVoice2-0.5B"),
        )
        # Look for a prompt wav in the model directory
        candidates = [
            os.path.join(model_dir, "prompt.wav"),
            os.path.join(model_dir, f"{self.voice_name}.wav"),
            os.path.join(model_dir, "voice_prompt.wav"),
        ]
        for c in candidates:
            if os.path.isfile(c):
                self._prompt_wav = c
                logger.info("Voice prompt found: %s", c)
                break

        if self._prompt_wav is None:
            # If no prompt wav, we'll use SFT mode with available speakers
            logger.info("No voice prompt WAV found — will use SFT mode if speakers available")

        # Default prompt text for zero-shot (short French sentence)
        self._prompt_text = "Bonjour, je suis votre assistant vocal."

    # ------------------------------------------------------------------
    # Phase management
    # ------------------------------------------------------------------
    def _set_phase(self, phase: str) -> None:
        self.phase = phase
        logger.info("[Readiness] Phase → %s", phase)
        if self._phase_callback:
            try:
                self._phase_callback(phase)
            except Exception:
                pass

    # ------------------------------------------------------------------
    # Warmup
    # ------------------------------------------------------------------
    def _warmup_gpu(self) -> None:
        """Warm up GPU with a short inference pass."""
        if str(self.device) == "cpu" or self.model is None:
            return
        t0 = time.monotonic()
        try:
            logger.info("GPU warm-up (CosyVoice2) …")
            for _ in self._inference_internal("Bonjour.", stream=False):
                pass
            self._profile["gpu_warmup_ms"] = (time.monotonic() - t0) * 1000
            logger.info("GPU warm-up done in %.0f ms", self._profile["gpu_warmup_ms"])
        except Exception as exc:
            logger.warning("GPU warm-up failed: %s", exc)
            self._profile["gpu_warmup_ms"] = (time.monotonic() - t0) * 1000

    def _warmup_streaming(self) -> None:
        """Warm up the streaming inference path."""
        if str(self.device) == "cpu" or self.model is None:
            return
        t0 = time.monotonic()
        try:
            logger.info("Streaming warm-up (CosyVoice2) …")
            for _ in self._inference_internal("Bonjour.", stream=True):
                break  # first chunk enough
            self._profile["streaming_warmup_ms"] = (time.monotonic() - t0) * 1000
            logger.info("Streaming warm-up done in %.0f ms", self._profile["streaming_warmup_ms"])
        except Exception as exc:
            logger.warning("Streaming warm-up failed: %s", exc)

    def _warmup_audio(self) -> None:
        """Generate silence to prime the audio pipeline."""
        t0 = time.monotonic()
        silence = np.zeros(OUTPUT_SAMPLE_RATE, dtype=np.float32)
        pcm = np.clip(silence * 32767, -32768, 32767).astype(np.int16)
        _ = pcm.tobytes()
        del pcm, silence
        self._profile["audio_warmup_ms"] = (time.monotonic() - t0) * 1000

    def warmup(self) -> None:
        """Public warmup entry point."""
        self._warmup_gpu()
        self._warmup_streaming()
        self._warmup_audio()

    # ------------------------------------------------------------------
    # Voice / language management
    # ------------------------------------------------------------------
    def set_voice(self, voice: str) -> bool:
        """Switch voice. Returns True if voice exists."""
        if voice in self._available_spks:
            self.voice_name = voice
            logger.info("Voice set to: %s (SFT speaker)", voice)
            return True
        # Check for a matching prompt wav
        model_dir = os.environ.get(
            "EXO_COSYVOICE_MODELS",
            os.environ.get("EXO_XTTS_MODELS", r"D:\EXO\models\CosyVoice2-0.5B"),
        )
        wav_path = os.path.join(model_dir, f"{voice}.wav")
        if os.path.isfile(wav_path):
            self.voice_name = voice
            self._prompt_wav = wav_path
            logger.info("Voice set to: %s (zero-shot prompt)", voice)
            return True
        # Case-insensitive fallback
        for spk in self._available_spks:
            if spk.lower() == voice.lower():
                return self.set_voice(spk)
        logger.warning("Speaker '%s' not found, keeping '%s'", voice, self.voice_name)
        return False

    def set_language(self, lang: str) -> None:
        self.language = lang
        logger.info("Language set to: %s", lang)

    def list_voices(self) -> list[str]:
        return sorted(self._available_spks)

    # ------------------------------------------------------------------
    # Internal inference dispatcher
    # ------------------------------------------------------------------
    def _inference_internal(self, text: str, stream: bool = True, speed: float = 1.0):
        """Dispatch to the appropriate CosyVoice2 inference method.

        Priority: registered zero-shot speaker (cached) > raw prompt wav > fallback.
        Yields dicts with 'tts_speech' tensor key (shape [1, N]).
        """
        if self.voice_name and self.voice_name in self._available_spks:
            # Registered zero-shot speaker: use cross-lingual with
            # zero_shot_spk_id to leverage cached embeddings.
            # (inference_sft only works with native SFT speakers that have
            # a single 'embedding' key; add_zero_shot_spk stores separate
            # llm_embedding / flow_embedding.)
            yield from self.model.inference_cross_lingual(
                tts_text=text,
                prompt_wav=self._prompt_wav or "",
                zero_shot_spk_id=self.voice_name,
                stream=stream,
                speed=speed,
            )
        elif self._prompt_wav and os.path.isfile(self._prompt_wav):
            # Raw cross-lingual mode: reprocesses prompt wav each call
            yield from self.model.inference_cross_lingual(
                tts_text=text,
                prompt_wav=self._prompt_wav,
                stream=stream,
                speed=speed,
            )
        else:
            raise RuntimeError(
                "No voice prompt WAV and no speakers available. "
                "Place a prompt.wav in the model directory."
            )

    # ------------------------------------------------------------------
    # Tensor → PCM16 bytes conversion
    # ------------------------------------------------------------------
    @staticmethod
    def _tensor_to_pcm16(speech_tensor: torch.Tensor, target_sr: int = OUTPUT_SAMPLE_RATE) -> bytes:
        """Convert a CosyVoice speech tensor to PCM16 bytes at target sample rate."""
        wav = speech_tensor.squeeze()
        if wav.dim() == 0:
            return b""
        if hasattr(wav, "cpu"):
            wav = wav.cpu()
        wav_np = wav.numpy().astype(np.float32)
        if wav_np.size == 0:
            return b""
        # Normalize to [-1, 1] range if needed
        peak = np.max(np.abs(wav_np))
        if peak > 1.0:
            wav_np = wav_np / peak
        # float32 → int16
        pcm = np.clip(wav_np * 32767, -32768, 32767).astype(np.int16)
        return pcm.tobytes()

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

    # ------------------------------------------------------------------
    # Public synthesis API
    # ------------------------------------------------------------------
    def synthesize_stream(
        self,
        text: str,
        voice: Optional[str] = None,
        lang: Optional[str] = None,
        rate: float = 1.0,
    ):
        """Streaming synthesis: yield PCM16 byte chunks as CosyVoice2 generates them.

        Each yielded chunk is raw PCM16 bytes at OUTPUT_SAMPLE_RATE.
        Token-level streaming — chunks are sent as soon as they are available.
        """
        if not self._loaded or self.model is None:
            raise RuntimeError("Model not loaded")
        if not text or not text.strip():
            return

        t0 = time.monotonic()
        chunk_idx = 0
        native_sr = getattr(self.model, "sample_rate", COSYVOICE_SAMPLE_RATE)

        try:
            for output in self._inference_internal(text, stream=True, speed=rate):
                speech = output.get("tts_speech")
                if speech is None:
                    continue

                # Convert tensor to numpy float32
                wav = speech.squeeze()
                if hasattr(wav, "cpu"):
                    wav = wav.cpu()
                wav_np = wav.numpy().astype(np.float32)
                if wav_np.size == 0:
                    continue

                # Resample if needed
                if native_sr != OUTPUT_SAMPLE_RATE:
                    wav_np = self._resample(wav_np, native_sr, OUTPUT_SAMPLE_RATE)

                # Normalize
                peak = np.max(np.abs(wav_np))
                if peak > 1.0:
                    wav_np = wav_np / peak

                # float32 → int16 PCM
                pcm_int16 = np.clip(wav_np * 32767, -32768, 32767).astype(np.int16)
                pcm_bytes = pcm_int16.tobytes()

                if chunk_idx == 0:
                    first_chunk_ms = (time.monotonic() - t0) * 1000
                    logger.info(
                        "[Latency] TTS first-chunk: %.0f ms (%d bytes) text=%s",
                        first_chunk_ms, len(pcm_bytes), text[:50],
                    )
                    if first_chunk_ms > 600:
                        logger.warning(
                            "[Latency] TTS first-chunk slow (%.0f ms > 600 ms)", first_chunk_ms
                        )

                chunk_idx += 1
                yield pcm_bytes

        except Exception as exc:
            logger.error("CosyVoice2 streaming error: %s", exc)
            if chunk_idx == 0:
                # Fallback to non-streaming
                full_pcm = self.synthesize(text, voice, lang, rate)
                if full_pcm:
                    yield full_pcm
                return

        dt = time.monotonic() - t0
        self._last_synth_time = time.monotonic()
        logger.info("[STREAM] done: %d chunks in %.2fs text=%s", chunk_idx, dt, text[:50])

    def synthesize(
        self,
        text: str,
        voice: Optional[str] = None,
        lang: Optional[str] = None,
        rate: float = 1.0,
        pitch: float = 1.0,
    ) -> bytes:
        """Full (non-streaming) synthesis returning complete PCM16 bytes."""
        if not self._loaded or self.model is None:
            raise RuntimeError("Model not loaded")
        if not text or not text.strip():
            return b""

        t0 = time.monotonic()
        native_sr = getattr(self.model, "sample_rate", COSYVOICE_SAMPLE_RATE)
        all_pcm = bytearray()

        for output in self._inference_internal(text, stream=False, speed=rate):
            speech = output.get("tts_speech")
            if speech is None:
                continue
            wav = speech.squeeze()
            if hasattr(wav, "cpu"):
                wav = wav.cpu()
            wav_np = wav.numpy().astype(np.float32)
            if wav_np.size == 0:
                continue
            # Resample if needed
            if native_sr != OUTPUT_SAMPLE_RATE:
                wav_np = self._resample(wav_np, native_sr, OUTPUT_SAMPLE_RATE)
            peak = np.max(np.abs(wav_np))
            if peak > 1.0:
                wav_np = wav_np / peak
            pcm_int16 = np.clip(wav_np * 32767, -32768, 32767).astype(np.int16)
            all_pcm.extend(pcm_int16.tobytes())

        dt = time.monotonic() - t0
        duration = len(all_pcm) / (OUTPUT_SAMPLE_RATE * 2)
        logger.info(
            "CosyVoice2 synthesized %.1fs audio in %.2fs (RTF=%.2f) text=%s",
            duration, dt, dt / max(duration, 0.01), text[:60],
        )
        self._last_synth_time = time.monotonic()
        return bytes(all_pcm)
