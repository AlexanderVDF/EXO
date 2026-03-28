"""
Traceback diagnostic for inference_stream vs inference.
Runs directly with the XTTS model to identify root cause.
"""
import os
import sys
import time
import traceback

# Environment
os.environ.setdefault("EXO_XTTS_MODELS", r"D:\EXO\models\xtts")
os.environ.setdefault("HF_HOME", r"D:\EXO\cache\huggingface")
os.environ.setdefault("TRANSFORMERS_CACHE", r"D:\EXO\cache\huggingface\hub")

import torch
torch.inference_mode = torch.no_grad

import numpy as np

print("=" * 60)
print("DIAGNOSTIC XTTS v2 — inference vs inference_stream")
print("=" * 60)

# Detect device
print("\n[1] Detection device...")
device = "cpu"
if torch.cuda.is_available():
    device = "cuda"
    print(f"  Device: CUDA — {torch.cuda.get_device_name(0)}")
else:
    try:
        import torch_directml
        if torch_directml.is_available():
            device = torch_directml.device()
            print(f"  Device: DirectML — {device}")
            print(f"  Device type: {type(device)}")
            print(f"  Device repr: {repr(device)}")
    except ImportError:
        pass

if device == "cpu":
    print("  Device: CPU (no GPU)")

# Load model
print("\n[2] Loading XTTS v2 model...")
from TTS.api import TTS

tts_api = TTS(
    model_name="tts_models/multilingual/multi-dataset/xtts_v2",
    progress_bar=False,
)
model = tts_api.synthesizer.tts_model

if str(device) != "cpu":
    try:
        model = model.to(device)
        print(f"  Model moved to {device}")
    except Exception as e:
        print(f"  GPU move failed: {e}, using CPU")
        device = "cpu"

# Load speakers
print("\n[3] Loading speakers...")
spk_file = os.path.join(os.environ["EXO_XTTS_MODELS"], "speakers_xtts.pth")
speakers = torch.load(spk_file, weights_only=False)
print(f"  Loaded {len(speakers)} speakers")

voice = "Claribel Dervla"
if str(device) != "cpu":
    for key in speakers[voice]:
        if hasattr(speakers[voice][key], "to"):
            speakers[voice][key] = speakers[voice][key].to(device)

gpt_cond = speakers[voice]["gpt_cond_latent"]
spk_emb = speakers[voice]["speaker_embedding"]

print(f"  gpt_cond_latent: shape={gpt_cond.shape}, device={gpt_cond.device}, dtype={gpt_cond.dtype}")
print(f"  speaker_embedding: shape={spk_emb.shape}, device={spk_emb.device}, dtype={spk_emb.dtype}")

# Test regular inference
print("\n[4] Testing model.inference()...")
try:
    t0 = time.monotonic()
    out = model.inference(
        text="Bonjour, ceci est un test.",
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
    wav = np.asarray(wav, dtype=np.float32)
    dt = time.monotonic() - t0
    pcm = np.clip(wav * 32767, -32768, 32767).astype(np.int16)
    print(f"  ✓ inference() OK: {len(pcm)} samples, {len(pcm)/24000:.2f}s audio, {dt:.2f}s compute")
except Exception as e:
    print(f"  ✗ inference() FAILED:")
    traceback.print_exc()

# Test inference_stream
print("\n[5] Testing model.inference_stream()...")
try:
    t0 = time.monotonic()

    # Check if method exists
    if not hasattr(model, "inference_stream"):
        print("  ✗ inference_stream method NOT FOUND")
    else:
        print(f"  Method exists: {type(model.inference_stream)}")

        # Check method signature
        import inspect
        sig = inspect.signature(model.inference_stream)
        print(f"  Signature: {sig}")

        # Try calling it
        gen = model.inference_stream(
            text="Bonjour, ceci est un test.",
            language="fr",
            gpt_cond_latent=gpt_cond,
            speaker_embedding=spk_emb,
            stream_chunk_size=20,
            overlap_wav_len=1024,
        )
        print(f"  Generator created: {type(gen)}")

        # Iterate
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
        print(f"  ✓ inference_stream() OK: {chunk_count} chunks, {total_samples} samples, {total_samples/24000:.2f}s audio, {dt:.2f}s compute")

except Exception as e:
    print(f"  ✗ inference_stream() FAILED:")
    traceback.print_exc()

# Test inference_stream WITH speed param
print("\n[6] Testing model.inference_stream() WITH speed=1.0...")
try:
    gen = model.inference_stream(
        text="Bonjour.",
        language="fr",
        gpt_cond_latent=gpt_cond,
        speaker_embedding=spk_emb,
        speed=1.0,
        stream_chunk_size=20,
        overlap_wav_len=1024,
    )
    chunk_count = 0
    for wav_chunk in gen:
        chunk_count += 1
    print(f"  ✓ With speed: {chunk_count} chunks")
except Exception as e:
    print(f"  ✗ With speed FAILED:")
    traceback.print_exc()

print("\n" + "=" * 60)
print("DIAGNOSTIC TERMINÉ")
print("=" * 60)
