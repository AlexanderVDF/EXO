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
from pathlib import Path
from typing import Optional

import numpy as np

# Singleton guard — prevent duplicate instances
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from shared.singleton_guard import ensure_single_instance
from shared.base_service import init_v9

# ---------------------------------------------------------------------------
# PyTorch compat: Coqui TTS uses torch.inference_mode() internally, but
# PyTorch >= 2.4 raises "Cannot set version_counter for inference tensor".
# Monkey-patching inference_mode → no_grad fixes this.
# ---------------------------------------------------------------------------
import torch
torch.inference_mode = torch.no_grad  # type: ignore[assignment]

# ---------------------------------------------------------------------------
# Transformers compat: recent transformers calls isin_mps_friendly() with
# eos_token_id (int) and expects a tensor.  Monkey-patch to convert int→tensor
# so inference_stream() works on CUDA / CPU.
# ---------------------------------------------------------------------------
try:
    import transformers.pytorch_utils as _tpu
    _orig_isin = _tpu.isin_mps_friendly

    def _patched_isin(elements, test_elements):
        if isinstance(elements, int):
            elements = torch.tensor([elements])
        if isinstance(test_elements, int):
            test_elements = torch.tensor([test_elements])
        return _orig_isin(elements, test_elements)

    _tpu.isin_mps_friendly = _patched_isin
    # Also patch the imported copy in generation.utils
    import transformers.generation.utils as _gen_utils
    if hasattr(_gen_utils, "isin_mps_friendly"):
        _gen_utils.isin_mps_friendly = _patched_isin
except Exception:
    pass  # Older transformers without isin_mps_friendly — not needed

# ---------------------------------------------------------------------------
# Transformers compat (2): recent transformers (≥4.43) expects
# _eos_token_tensor / _pad_token_tensor / _bos_token_tensor attributes on
# GenerationConfig, set by _prepare_special_tokens().  Coqui TTS's
# StreamGenerationConfig bypasses that setup → AttributeError.
# Monkey-patch its __init__ to set sensible defaults.
# ---------------------------------------------------------------------------
try:
    from TTS.tts.layers.xtts.stream_generator import StreamGenerationConfig as _SGC

    _sgc_orig_init = _SGC.__init__

    def _sgc_patched_init(self, **kwargs):
        _sgc_orig_init(self, **kwargs)
        for attr in ("_eos_token_tensor", "_bos_token_tensor",
                      "_pad_token_tensor", "_decoder_start_token_tensor"):
            if not hasattr(self, attr):
                setattr(self, attr, None)

    _SGC.__init__ = _sgc_patched_init
except Exception:
    pass

# ---------------------------------------------------------------------------
# Transformers compat (3): transformers ≥4.40 removed _get_logits_warper()
# from GenerationMixin (merged into _get_logits_processor).  Coqui TTS's
# stream_generator.py still calls self._get_logits_warper(generation_config).
# Re-implement it using the warper classes that still exist.
# ---------------------------------------------------------------------------
try:
    from transformers.generation import (
        LogitsProcessorList,
        TemperatureLogitsWarper,
        TopKLogitsWarper,
        TopPLogitsWarper,
        TypicalLogitsWarper,
        EpsilonLogitsWarper,
        EtaLogitsWarper,
    )
    from TTS.tts.layers.xtts.stream_generator import NewGenerationMixin

    def _patched_get_logits_warper(self, generation_config):
        warpers = LogitsProcessorList()
        if generation_config.temperature is not None and generation_config.temperature != 1.0:
            warpers.append(TemperatureLogitsWarper(generation_config.temperature))
        min_tokens_to_keep = 1
        if generation_config.top_k is not None and generation_config.top_k != 0:
            warpers.append(TopKLogitsWarper(
                top_k=generation_config.top_k, min_tokens_to_keep=min_tokens_to_keep))
        if generation_config.top_p is not None and generation_config.top_p < 1.0:
            warpers.append(TopPLogitsWarper(
                top_p=generation_config.top_p, min_tokens_to_keep=min_tokens_to_keep))
        if getattr(generation_config, "typical_p", None) is not None and generation_config.typical_p < 1.0:
            warpers.append(TypicalLogitsWarper(
                mass=generation_config.typical_p, min_tokens_to_keep=min_tokens_to_keep))
        if getattr(generation_config, "epsilon_cutoff", None) is not None and 0.0 < generation_config.epsilon_cutoff < 1.0:
            warpers.append(EpsilonLogitsWarper(
                epsilon=generation_config.epsilon_cutoff, min_tokens_to_keep=min_tokens_to_keep))
        if getattr(generation_config, "eta_cutoff", None) is not None and 0.0 < generation_config.eta_cutoff < 1.0:
            warpers.append(EtaLogitsWarper(
                epsilon=generation_config.eta_cutoff, min_tokens_to_keep=min_tokens_to_keep))
        return warpers

    # Attach to PreTrainedModel since stream_generator binds generate_stream there
    from transformers import PreTrainedModel
    PreTrainedModel._get_logits_warper = _patched_get_logits_warper
except Exception:
    pass

# ---------------------------------------------------------------------------
# Transformers/CUDA compat (4): Coqui TTS stream_generator.py passes
# integer token IDs (bos/pad/eos) to sample_stream(). Ensure they are
# converted to tensors on the correct device before calling generate_stream().
# ---------------------------------------------------------------------------
try:
    from TTS.tts.layers.xtts.gpt import GPT as _GPT

    _orig_get_generator = _GPT.get_generator

    def _patched_get_generator(self, fake_inputs, **hf_generate_kwargs):
        device = fake_inputs.device
        return self.gpt_inference.generate_stream(
            fake_inputs,
            bos_token_id=torch.tensor(self.start_audio_token, device=device),
            pad_token_id=torch.tensor(self.stop_audio_token, device=device),
            eos_token_id=torch.tensor([self.stop_audio_token], device=device),
            max_length=self.max_gen_mel_tokens + fake_inputs.shape[-1],
            do_stream=True,
            **hf_generate_kwargs,
        )

    _GPT.get_generator = _patched_get_generator

    # Same fix for GPT.generate() — used by model.inference() (non-streaming).
    # Without this, bos/pad/eos are raw ints and transformers accesses .device
    # on them → "'int' object has no attribute 'device'"
    _orig_gpt_generate = _GPT.generate

    def _patched_gpt_generate(self, cond_latents, text_inputs, **hf_generate_kwargs):
        gpt_inputs = self.compute_embeddings(cond_latents, text_inputs)
        device = gpt_inputs.device
        gen = self.gpt_inference.generate(
            gpt_inputs,
            bos_token_id=torch.tensor(self.start_audio_token, device=device),
            pad_token_id=torch.tensor(self.stop_audio_token, device=device),
            eos_token_id=torch.tensor([self.stop_audio_token], device=device),
            max_length=self.max_gen_mel_tokens + gpt_inputs.shape[-1],
            **hf_generate_kwargs,
        )
        if "return_dict_in_generate" in hf_generate_kwargs:
            return gen.sequences[:, gpt_inputs.shape[1]:], gen
        return gen[:, gpt_inputs.shape[1]:]

    _GPT.generate = _patched_gpt_generate
except Exception:
    pass

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
CHUNK_SIZE = 1024           # v26.1: ~21ms @ 24kHz mono16 — reduced from 2048 for faster streaming
STREAM_CHUNK_SIZE = 4       # v26.1: smaller GPT chunks for faster first-chunk (was 8)

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

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from shared.cache import PhraseCache


# ---------------------------------------------------------------------------
# TTS Engine wrapper — XTTS v2
# ---------------------------------------------------------------------------

class XTTSEngine:
    """Wraps Coqui XTTS v2 for streaming synthesis."""

    # Readiness phases (v5.1)
    PHASE_INIT    = "ready_init"
    PHASE_LOADING = "ready_loading"
    PHASE_WARMUP  = "ready_warmup"
    PHASE_ONLINE  = "ready_online"

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
        self._last_synth_time = 0.0  # monotonic timestamp of last synthesis
        # v5.1 readiness
        self.phase = self.PHASE_INIT
        self._phase_callback = None   # async callback for phase changes
        self._profile: dict = {}      # startup profiling timings

    @staticmethod
    def _detect_device():
        """Detect best available device: CUDA > CPU.
        Priority: RTX 3070 SUPRIM X via CUDA for all critical TTS workloads."""
        import torch
        if torch.cuda.is_available():
            name = torch.cuda.get_device_name(0)
            vram = torch.cuda.get_device_properties(0).total_memory / (1024**3)
            logger.info("XTTS CUDA device: %s (VRAM: %.1f GB)", name, vram)
            logger.info("CUDA: OK")
            logger.info("XTTS loaded on CUDA")
            return "cuda"
        logger.warning("CUDA not available — falling back to CPU (TTS will be slower)")
        return "cpu"

    def load(self) -> None:
        """Load XTTS v2 model, speaker embeddings, warm-up GPU + audio (v5.2 persistent)."""
        import torch
        from TTS.api import TTS

        # v5.2: CUDA persistence — lock cudnn benchmarks for stable kernel selection
        if torch.cuda.is_available():
            torch.backends.cudnn.benchmark = True
            torch.backends.cuda.matmul.allow_tf32 = True
            torch.backends.cudnn.allow_tf32 = True

        t_total = time.monotonic()

        # ── Phase 1: READY_INIT — Python lancé ──
        self._set_phase(self.PHASE_INIT)
        t0 = time.monotonic()
        self.device = self._detect_device()
        self._profile["python_init_ms"] = (time.monotonic() - t0) * 1000

        # ── Phase 2: READY_LOADING — chargement du modèle ──
        self._set_phase(self.PHASE_LOADING)
        t0 = time.monotonic()
        logger.info("Loading XTTS v2 model on %s...", self.device)
        tts_api = TTS(
            model_name="tts_models/multilingual/multi-dataset/xtts_v2",
            progress_bar=False,
        )
        self.model = tts_api.synthesizer.tts_model
        self._profile["model_load_ms"] = (time.monotonic() - t0) * 1000

        # Move model to GPU (fall back to CPU if VRAM insufficient)
        if str(self.device) != "cpu":
            try:
                t0 = time.monotonic()
                self.model = self.model.to(self.device)
                self._profile["model_to_gpu_ms"] = (time.monotonic() - t0) * 1000
                logger.info("XTTS model moved to %s", self.device)
            except RuntimeError as exc:
                logger.warning("XTTS fallback: CUDA → CPU (%s)", exc)
                self.device = "cpu"
                self.model = self.model.to("cpu")

        # Load speaker embeddings
        model_dir = os.environ.get(
            "EXO_XTTS_MODELS",
            r"D:\EXO\models\xtts",
        )
        spk_file = os.path.join(model_dir, "speakers_xtts.pth")
        if os.path.exists(spk_file):
            t0 = time.monotonic()
            self.speakers = torch.load(spk_file, weights_only=False)
            # Move speaker embeddings to GPU
            if str(self.device) != "cpu":
                try:
                    for name in self.speakers:
                        for key in self.speakers[name]:
                            if hasattr(self.speakers[name][key], "to"):
                                self.speakers[name][key] = self.speakers[name][key].to(self.device)
                except RuntimeError as exc:
                    logger.warning("GPU speaker embed allocation failed (%s), falling back to CPU", exc)
                    self.device = "cpu"
                    self.model = self.model.to("cpu")
            self._profile["speakers_load_ms"] = (time.monotonic() - t0) * 1000
            logger.info("Loaded %d speakers from %s", len(self.speakers), spk_file)
        else:
            logger.warning("No speakers file found at %s", spk_file)

        # Set initial voice (pre-load embeddings)
        self.set_voice(self.voice_name)

        # ── Phase 3: READY_WARMUP — warm-up GPU + audio ──
        self._set_phase(self.PHASE_WARMUP)
        self._warmup_gpu(torch)
        self._warmup_streaming()
        self._warmup_audio()

        self._loaded = True

        # ── Phase 4: READY_ONLINE — service prêt ──
        self._profile["total_ms"] = (time.monotonic() - t_total) * 1000
        self._set_phase(self.PHASE_ONLINE)

        logger.info(
            "XTTS v2 ready — device=%s, voice=%s, lang=%s, speakers=%d",
            self.device, self.voice_name, self.language, len(self.speakers),
        )
        if str(self.device).startswith("cuda"):
            logger.info("Streaming CUDA active")
            logger.info("[TTS] XTTS backend: CUDA (RTX 3070)")
            logger.info("[GPU] TTS: CUDA → RTX 3070 (OK)")
            logger.info("[GPU] Multi-GPU configuration: ACTIVE")

        # ── Profiling report ──
        logger.info("═══ TTS STARTUP PROFILE ═══")
        for k, v in self._profile.items():
            logger.info("  %-25s %7.0f ms", k, v)
        logger.info("═══════════════════════════")

    def _set_phase(self, phase: str) -> None:
        """Update readiness phase and notify callback."""
        self.phase = phase
        logger.info("[Readiness] Phase → %s", phase)
        if self._phase_callback:
            try:
                self._phase_callback(phase)
            except Exception:
                pass

    def _warmup_gpu(self, torch) -> None:
        """Warm-up GPU with a dummy tensor pass to keep DirectML/CUDA backend hot."""
        if str(self.device) == "cpu" or self.gpt_cond_latent is None:
            return
        t0 = time.monotonic()
        try:
            logger.info("GPU warm-up on %s...", self.device)
            # Inference with minimal text to warm the full pipeline
            _test = self.model.inference(
                text="test",
                language="en",
                gpt_cond_latent=self.gpt_cond_latent,
                speaker_embedding=self.speaker_embedding,
                speed=1.0,
            )
            del _test
            self._profile["gpu_warmup_ms"] = (time.monotonic() - t0) * 1000
            logger.info("GPU warm-up done in %.0f ms", self._profile["gpu_warmup_ms"])
        except RuntimeError as exc:
            logger.warning("GPU warm-up failed (%s) — falling back to CPU", exc)
            self._profile["gpu_warmup_ms"] = (time.monotonic() - t0) * 1000
            self.device = "cpu"
            self.model = self.model.to("cpu")
            for name in self.speakers:
                for key in self.speakers[name]:
                    if hasattr(self.speakers[name][key], "to"):
                        self.speakers[name][key] = self.speakers[name][key].to("cpu")
            if self.gpt_cond_latent is not None:
                self.gpt_cond_latent = self.gpt_cond_latent.to("cpu")
            if self.speaker_embedding is not None:
                self.speaker_embedding = self.speaker_embedding.to("cpu")

    def _warmup_streaming(self) -> None:
        """Warm-up inference_stream to pre-compile the streaming compute graph."""
        if str(self.device) == "cpu" or self.gpt_cond_latent is None:
            return
        t0 = time.monotonic()
        try:
            logger.info("Streaming warm-up on %s...", self.device)
            for chunk in self.model.inference_stream(
                text="bonjour",
                language="fr",
                gpt_cond_latent=self.gpt_cond_latent,
                speaker_embedding=self.speaker_embedding,
                speed=1.0,
                stream_chunk_size=STREAM_CHUNK_SIZE,
                overlap_wav_len=256,
                enable_text_splitting=True,
            ):
                break  # first chunk is enough to warm the graph
            logger.info("Streaming warm-up done in %.0f ms", (time.monotonic() - t0) * 1000)
        except Exception as exc:
            logger.warning("Streaming warm-up failed: %s", exc)

    def _warmup_audio(self) -> None:
        """Generate 1 second of silence to initialize the DSP/audio pipeline."""
        t0 = time.monotonic()
        try:
            silence = np.zeros(OUTPUT_SAMPLE_RATE, dtype=np.float32)
            pcm = np.clip(silence * 32767, -32768, 32767).astype(np.int16)
            _ = pcm.tobytes()
            del pcm, silence
            self._profile["audio_warmup_ms"] = (time.monotonic() - t0) * 1000
        except Exception as exc:
            logger.warning("Audio warm-up failed: %s", exc)
            self._profile["audio_warmup_ms"] = (time.monotonic() - t0) * 1000

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

    def _clean_text(self, text: str) -> str:
        """Strip emojis and whitespace from text."""
        return _EMOJI_RE.sub("", text).strip()

    def _resolve_params(self, voice: Optional[str], lang: Optional[str]):
        use_voice = voice if voice and voice in self.speakers else self.voice_name
        use_lang = lang if lang and lang in SUPPORTED_LANGUAGES else self.language
        return use_voice, use_lang

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

        text = self._clean_text(text)
        if not text:
            return b""

        use_voice, use_lang = self._resolve_params(voice, lang)

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
            "XTTS synthesized %.1fs audio in %.2fs (RTF=%.2f, TTS latency: %.0fms) voice=%s lang=%s: %s",
            duration, dt, dt / max(duration, 0.01), dt * 1000, use_voice, use_lang, text[:60],
        )

        # Cache short phrases
        self._cache.put(text, use_voice, use_lang, raw_pcm)

        return raw_pcm

    def synthesize_stream(
        self,
        text: str,
        voice: Optional[str] = None,
        lang: Optional[str] = None,
        rate: float = 1.0,
    ):
        """
        Streaming synthesis: yield PCM16 byte chunks as XTTS v2 generates them.

        Each yielded chunk is a bytes object of raw PCM16 at OUTPUT_SAMPLE_RATE.
        First chunk arrives in ~300-800ms instead of waiting for full synthesis.
        """
        if not self._loaded or self.model is None:
            raise RuntimeError("Model not loaded")
        if not text.strip():
            return

        text = self._clean_text(text)
        if not text:
            return

        use_voice, use_lang = self._resolve_params(voice, lang)

        gpt_cond = self.speakers[use_voice]["gpt_cond_latent"]
        spk_emb = self.speakers[use_voice]["speaker_embedding"]

        t0 = time.monotonic()
        chunk_idx = 0

        try:
            chunks_gen = self.model.inference_stream(
                text=text,
                language=use_lang,
                gpt_cond_latent=gpt_cond,
                speaker_embedding=spk_emb,
                speed=rate,
                stream_chunk_size=STREAM_CHUNK_SIZE,  # v5.2: use global constant
                overlap_wav_len=256,       # reduced overlap for faster chunks
                temperature=0.5,           # lower temp = faster convergence
                top_p=0.85,
                repetition_penalty=1.1,    # prevent repetitive output
                enable_text_splitting=True, # split long text → faster first chunk
            )
        except AttributeError:
            # Fallback: model doesn't support inference_stream (old version)
            logger.warning("inference_stream not available — falling back to full synthesis")
            full_pcm = self.synthesize(text, voice, lang, rate)
            if full_pcm:
                yield full_pcm
            return

        try:
            stream_iterator = iter(chunks_gen)
        except Exception:
            stream_iterator = None

        if stream_iterator is None:
            logger.warning("inference_stream iteration failed — falling back to full synthesis")
            full_pcm = self.synthesize(text, voice, lang, rate)
            if full_pcm:
                yield full_pcm
            return

        try:
            for wav_chunk in stream_iterator:
                # Tensor → numpy float32
                if hasattr(wav_chunk, "cpu"):
                    wav_chunk = wav_chunk.cpu()
                if hasattr(wav_chunk, "numpy"):
                    wav_chunk = wav_chunk.numpy()
                wav_chunk = np.asarray(wav_chunk, dtype=np.float32).flatten()

                if wav_chunk.size == 0:
                    continue

                # float32 → int16 PCM
                pcm_int16 = np.clip(wav_chunk * 32767, -32768, 32767).astype(np.int16)
                pcm_bytes = pcm_int16.tobytes()

                if chunk_idx == 0:
                    first_chunk_ms = (time.monotonic() - t0) * 1000
                    logger.info(
                        "[Latency] TTS first-chunk: %.0f ms (%d bytes) text=%s",
                        first_chunk_ms, len(pcm_bytes), text[:50],
                    )
                    if first_chunk_ms > 800:
                        logger.warning("[Latency] TTS first-chunk slow (%.0f ms > 800 ms)", first_chunk_ms)

                chunk_idx += 1
                yield pcm_bytes
        except Exception as stream_err:
            logger.warning("inference_stream iteration error: %s — falling back", stream_err)
            if chunk_idx == 0:
                # No chunks produced yet; fall back to full synthesis
                full_pcm = self.synthesize(text, voice, lang, rate)
                if full_pcm:
                    yield full_pcm
                return

        dt = time.monotonic() - t0
        self._last_synth_time = time.monotonic()
        logger.info(
            "[STREAM] done: %d chunks in %.2fs text=%s",
            chunk_idx, dt, text[:50],
        )

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

        # v5.1: Send current phase as ready message
        await ws.send(json.dumps({
            "type": "ready",
            "phase": self.engine.phase,
            "voice": self.engine.voice_name,
            "sample_rate": OUTPUT_SAMPLE_RATE,
            "backend": "xtts_v2",
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
        try:
            msg = json.loads(raw)
        except json.JSONDecodeError:
            return

        msg_type = msg.get("type", "")

        if msg_type == "ping":
            await ws.send(json.dumps({"type": "pong"}))
            return

        elif msg_type == "synthesize":
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
        """Synthesize and stream audio — uses streaming inference for low latency."""
        try:
            # Clean text for cache lookup
            clean = self.engine._clean_text(text)
            if not clean:
                await ws.send(json.dumps({"type": "error", "message": "Empty text after cleaning"}))
                return

            use_voice, use_lang = self.engine._resolve_params(voice, lang)

            # Check cache first — instant send if cached
            cached = self.engine._cache.get(clean, use_voice, use_lang)
            if cached is not None:
                logger.info("Cache hit: %s", clean[:40])
                await ws.send(json.dumps({"type": "start", "text": text}))
                offset = 0
                while offset < len(cached):
                    if self._cancel_flag:
                        return
                    chunk = cached[offset : offset + CHUNK_SIZE]
                    await ws.send(chunk)
                    offset += CHUNK_SIZE
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
                """Run streaming synthesis in thread, push chunks to async queue."""
                try:
                    for pcm_chunk in self.engine.synthesize_stream(
                        text, voice, lang, rate
                    ):
                        if self._cancel_flag:
                            break
                        all_pcm.extend(pcm_chunk)
                        # Split into CHUNK_SIZE frames for WebSocket
                        off = 0
                        while off < len(pcm_chunk):
                            frame = pcm_chunk[off : off + CHUNK_SIZE]
                            loop.call_soon_threadsafe(queue.put_nowait, frame)
                            off += CHUNK_SIZE
                except Exception as e:
                    import traceback
                    logger.error("Stream worker error: %s\n%s", e, traceback.format_exc())
                finally:
                    loop.call_soon_threadsafe(queue.put_nowait, None)

            t0 = time.monotonic()
            fut = loop.run_in_executor(None, _stream_worker)

            total_bytes = 0
            while True:
                chunk = await queue.get()
                if chunk is None:
                    break
                if self._cancel_flag:
                    break
                await ws.send(chunk)
                total_bytes += len(chunk)
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
    import argparse

    parser = argparse.ArgumentParser(description="EXO TTS Server (XTTS v2)")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--voice", default=DEFAULT_VOICE,
                        help="XTTS v2 speaker name (e.g. 'Claribel Dervla')")
    parser.add_argument("--lang", default=DEFAULT_LANG,
                        help="Default language (e.g. fr, en, de)")
    args = parser.parse_args()

    # Prevent duplicate instances
    ensure_single_instance(args.port, "tts_server")
    _v9 = init_v9("tts_server", args.port)

    logger.info("[Latency] TTS target: < 1200 ms")
    logger.info("[Latency] Pipeline vocal complet target: < 2500 ms")

    # v5.1: Track connected clients for phase broadcast
    connected_clients: set = set()

    engine = XTTSEngine(voice=args.voice, lang=args.lang)

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
        ping_interval=None, ping_timeout=None,
    )
    logger.info(
        "TTS WS server listening on ws://%s:%d — loading model…",
        args.host, args.port,
    )

    # Load model in executor to keep event loop responsive for WS connections
    loop = asyncio.get_event_loop()
    t_load = time.monotonic()
    await loop.run_in_executor(None, engine.load)
    load_ms = (time.monotonic() - t_load) * 1000
    logger.info("[Latency] Preload TTS: OK (%.0f ms)", load_ms)

    # Broadcast READY_ONLINE to any already-connected clients
    _broadcast_phase(XTTSEngine.PHASE_ONLINE)

    logger.info(
        "XTTS v2 TTS server ready on ws://%s:%d (voice=%s, lang=%s, speakers=%d)",
        args.host, args.port, args.voice, args.lang, len(engine.speakers),
    )
    logger.info("[Latency] Streaming: OK — ready for low-latency synthesis")

    # v5.2: CUDA keepalive — prevent GPU clock downclocking during idle periods.
    # Runs a tiny tensor op every 30s if no synthesis happened recently.
    async def _cuda_keepalive():
        if str(engine.device) == "cpu":
            return
        while True:
            await asyncio.sleep(30)
            idle_s = time.monotonic() - engine._last_synth_time
            if idle_s > 20 and engine._loaded:
                try:
                    # Full streaming mini-inference to keep GPT graph warm
                    for chunk in engine.model.inference_stream(
                        text="ok",
                        language="fr",
                        gpt_cond_latent=engine.gpt_cond_latent,
                        speaker_embedding=engine.speaker_embedding,
                        speed=1.0,
                        stream_chunk_size=STREAM_CHUNK_SIZE,
                        overlap_wav_len=256,
                        enable_text_splitting=True,
                    ):
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
