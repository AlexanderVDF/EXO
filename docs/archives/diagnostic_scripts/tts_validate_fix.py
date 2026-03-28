"""Quick validation: does the monkey-patch fix inference_stream?"""
import os, sys, time, traceback
os.environ.setdefault("EXO_XTTS_MODELS", r"D:\EXO\models\xtts")
os.environ.setdefault("HF_HOME", r"D:\EXO\cache\huggingface")
os.environ.setdefault("TRANSFORMERS_CACHE", r"D:\EXO\cache\huggingface\hub")

import torch
torch.inference_mode = torch.no_grad

# ── Apply the SAME monkey-patch as tts_server.py ──
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
    import transformers.generation.utils as _gen_utils
    if hasattr(_gen_utils, "isin_mps_friendly"):
        _gen_utils.isin_mps_friendly = _patched_isin
    print("[PATCH] isin_mps_friendly patched OK")
except Exception as e:
    print(f"[PATCH] failed: {e}")

# ── Patch 2: StreamGenerationConfig missing _eos_token_tensor ──
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
    print("[PATCH] StreamGenerationConfig patched OK")
except Exception as e:
    print(f"[PATCH] StreamGenerationConfig patch failed: {e}")

# ── Patch 3: _get_logits_warper removed in transformers ≥4.40 ──
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

    from transformers import PreTrainedModel
    PreTrainedModel._get_logits_warper = _patched_get_logits_warper
    print("[PATCH] _get_logits_warper patched OK")
except Exception as e:
    print(f"[PATCH] _get_logits_warper patch failed: {e}")

import numpy as np
from TTS.api import TTS

# Detect device
device = "cpu"
try:
    import torch_directml
    if torch_directml.is_available():
        device = torch_directml.device()
except ImportError:
    pass
print(f"[DEVICE] {device}")

# Load model
print("[MODEL] Loading XTTS v2...")
tts_api = TTS(model_name="tts_models/multilingual/multi-dataset/xtts_v2", progress_bar=False)
model = tts_api.synthesizer.tts_model
if str(device) != "cpu":
    model = model.to(device)

# Load speakers
spk_file = os.path.join(os.environ["EXO_XTTS_MODELS"], "speakers_xtts.pth")
speakers = torch.load(spk_file, weights_only=False)
voice = "Claribel Dervla"
if str(device) != "cpu":
    for key in speakers[voice]:
        if hasattr(speakers[voice][key], "to"):
            speakers[voice][key] = speakers[voice][key].to(device)

gpt_cond = speakers[voice]["gpt_cond_latent"]
spk_emb = speakers[voice]["speaker_embedding"]

# Test 1: inference_stream (will likely fail on DirectML)
print("\n[TEST 1] inference_stream() with patches...")
stream_works = False
try:
    t0 = time.monotonic()
    gen = model.inference_stream(
        text="Bonjour, ceci est un test.",
        language="fr",
        gpt_cond_latent=gpt_cond,
        speaker_embedding=spk_emb,
        stream_chunk_size=20,
        overlap_wav_len=1024,
    )
    chunk_count = 0
    total_samples = 0
    for wav_chunk in gen:
        if hasattr(wav_chunk, "cpu"):
            wav_chunk = wav_chunk.cpu()
        if hasattr(wav_chunk, "numpy"):
            wav_chunk = wav_chunk.numpy()
        wav_chunk = np.asarray(wav_chunk, dtype=np.float32).flatten()
        chunk_count += 1
        total_samples += len(wav_chunk)
        if chunk_count == 1:
            print(f"  First chunk: {len(wav_chunk)} samples in {(time.monotonic()-t0)*1000:.0f}ms")
    dt = time.monotonic() - t0
    print(f"  OK: {chunk_count} chunks, {total_samples/24000:.2f}s audio, {dt:.2f}s compute")
    stream_works = True
except Exception as e:
    print(f"  FAIL (expected on DirectML): {type(e).__name__}: {e}")

# Test 2: inference (non-streaming) — this is the fallback path
print("\n[TEST 2] inference() non-streaming (fallback path)...")
try:
    t0 = time.monotonic()
    out = model.inference(
        text="Bonjour, ceci est un test de synthèse vocale.",
        language="fr",
        gpt_cond_latent=gpt_cond,
        speaker_embedding=spk_emb,
        speed=1.0,
    )
    wav = out["wav"]
    if hasattr(wav, "cpu"):
        wav = wav.cpu()
    if hasattr(wav, "numpy"):
        wav = wav.numpy()
    wav = np.asarray(wav, dtype=np.float32).flatten()
    pcm_int16 = np.clip(wav * 32767, -32768, 32767).astype(np.int16)
    pcm_bytes = pcm_int16.tobytes()
    dt = time.monotonic() - t0
    duration = len(pcm_bytes) / (24000 * 2)
    print(f"  OK: {duration:.2f}s audio, {len(pcm_bytes)} bytes, {dt:.2f}s compute")
except Exception as e:
    print(f"  FAIL: {type(e).__name__}: {e}")
    traceback.print_exc()

# Test 3: Simulate synthesize_stream() fallback logic
print("\n[TEST 3] Simulated synthesize_stream() with fallback...")
try:
    t0 = time.monotonic()
    chunk_idx = 0
    total_bytes = 0

    # Try streaming first
    try:
        gen = model.inference_stream(
            text="Le fallback fonctionne correctement.",
            language="fr",
            gpt_cond_latent=gpt_cond,
            speaker_embedding=spk_emb,
            stream_chunk_size=20,
            overlap_wav_len=1024,
        )
        for wav_chunk in gen:
            if hasattr(wav_chunk, "cpu"):
                wav_chunk = wav_chunk.cpu()
            if hasattr(wav_chunk, "numpy"):
                wav_chunk = wav_chunk.numpy()
            wav_chunk = np.asarray(wav_chunk, dtype=np.float32).flatten()
            if wav_chunk.size == 0:
                continue
            pcm = np.clip(wav_chunk * 32767, -32768, 32767).astype(np.int16).tobytes()
            chunk_idx += 1
            total_bytes += len(pcm)
    except Exception as stream_err:
        print(f"  Streaming failed: {type(stream_err).__name__}: {stream_err}")
        if chunk_idx == 0:
            print("  Falling back to non-streaming...")
            out = model.inference(
                text="Le fallback fonctionne correctement.",
                language="fr",
                gpt_cond_latent=gpt_cond,
                speaker_embedding=spk_emb,
                speed=1.0,
            )
            wav = out["wav"]
            if hasattr(wav, "cpu"):
                wav = wav.cpu()
            if hasattr(wav, "numpy"):
                wav = wav.numpy()
            wav = np.asarray(wav, dtype=np.float32).flatten()
            pcm = np.clip(wav * 32767, -32768, 32767).astype(np.int16).tobytes()
            total_bytes = len(pcm)
            chunk_idx = 1

    dt = time.monotonic() - t0
    duration = total_bytes / (24000 * 2)
    if total_bytes > 0:
        print(f"  OK: {duration:.2f}s audio, {total_bytes} bytes, {dt:.2f}s compute")
    else:
        print(f"  FAIL: 0 bytes produced")
except Exception as e:
    print(f"  FAIL: {type(e).__name__}: {e}")
    traceback.print_exc()

print("\n[SUMMARY]")
print(f"  inference_stream: {'OK' if stream_works else 'BROKEN (DirectML device issue)'}")
print(f"  inference (fallback): {'OK' if total_bytes > 0 else 'BROKEN'}")
print(f"  Overall TTS: {'FUNCTIONAL via fallback' if total_bytes > 0 else 'NOT WORKING'}")
print("\n[DONE]")
