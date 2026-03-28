"""Reproduce TTS server exact flow on DirectML to capture the actual error."""
import os, sys, time, traceback
import numpy as np

# Monkey-patches first (same as tts_server.py)
import torch
torch.inference_mode = torch.no_grad

_orig_isin = torch.isin
def _isin_mps_friendly(elements, test_elements, **kwargs):
    if hasattr(elements, 'cpu'):
        elements = elements.cpu()
    if hasattr(test_elements, 'cpu'):
        test_elements = test_elements.cpu()
    return _orig_isin(elements, test_elements, **kwargs)
torch.isin = _isin_mps_friendly

os.environ.setdefault("EXO_XTTS_MODELS", r"D:\EXO\models\xtts")

print("=== Step 1: Detect device ===")
try:
    import torch_directml
    if torch_directml.is_available():
        device = torch_directml.device()
        print(f"DirectML available: device = {device} (type: {type(device)})")
    else:
        device = "cpu"
        print("DirectML NOT available, using CPU")
except ImportError:
    device = "cpu"
    print("torch_directml not importable, using CPU")

print(f"\n=== Step 2: Load XTTS v2 model ===")
from TTS.api import TTS
tts_api = TTS(model_name="tts_models/multilingual/multi-dataset/xtts_v2", progress_bar=True)
model = tts_api.synthesizer.tts_model
print(f"Model loaded on: {next(model.parameters()).device}")

print(f"\n=== Step 3: Move model to {device} ===")
try:
    model = model.to(device)
    print(f"Model moved to: {next(model.parameters()).device}")
except RuntimeError as e:
    print(f"FAILED to move model to {device}: {e}")
    device = "cpu"
    model = model.to("cpu")
    print(f"Fell back to CPU: {next(model.parameters()).device}")

print(f"\n=== Step 4: Load speaker embeddings ===")
model_dir = os.environ.get("EXO_XTTS_MODELS", r"D:\EXO\models\xtts")
spk_file = os.path.join(model_dir, "speakers_xtts.pth")
speakers = torch.load(spk_file, weights_only=False)
print(f"Loaded {len(speakers)} speakers")

# Move embeddings to device
if str(device) != "cpu":
    for name in speakers:
        for key in speakers[name]:
            if hasattr(speakers[name][key], "to"):
                speakers[name][key] = speakers[name][key].to(device)
    print(f"Speaker embeddings moved to {device}")

voice = "Claribel Dervla"
gpt_cond = speakers[voice]["gpt_cond_latent"]
spk_emb = speakers[voice]["speaker_embedding"]
print(f"Voice={voice}, gpt_cond device={gpt_cond.device}, spk_emb device={spk_emb.device}")

print(f"\n=== Step 5: Call model.inference() on {device} ===")
text = "Test de synthèse vocale."
try:
    t0 = time.time()
    out = model.inference(
        text=text,
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
    elapsed = time.time() - t0
    
    pcm16 = np.clip(wav * 32767, -32768, 32767).astype(np.int16)
    raw_bytes = pcm16.tobytes()
    duration = len(raw_bytes) / (24000 * 2)
    
    print(f"SUCCESS: wav shape={wav.shape}, duration={duration:.2f}s, bytes={len(raw_bytes)}, time={elapsed:.2f}s")
except Exception as e:
    print(f"FAILED: {type(e).__name__}: {e}")
    traceback.print_exc()
    
    # Try on CPU as control
    print(f"\n=== Step 6: Retry on CPU (control test) ===")
    model = model.to("cpu")
    gpt_cond_cpu = gpt_cond.cpu()
    spk_emb_cpu = spk_emb.cpu()
    try:
        t0 = time.time()
        out = model.inference(
            text=text,
            language="fr",
            gpt_cond_latent=gpt_cond_cpu,
            speaker_embedding=spk_emb_cpu,
            speed=1.0,
        )
        wav = out["wav"]
        if hasattr(wav, "cpu"):
            wav = wav.cpu()
        if hasattr(wav, "numpy"):
            wav = wav.numpy()
        wav = np.asarray(wav, dtype=np.float32)
        elapsed = time.time() - t0
        pcm16 = np.clip(wav * 32767, -32768, 32767).astype(np.int16)
        raw_bytes = pcm16.tobytes()
        duration = len(raw_bytes) / (24000 * 2)
        print(f"CPU SUCCESS: wav shape={wav.shape}, duration={duration:.2f}s, bytes={len(raw_bytes)}, time={elapsed:.2f}s")
    except Exception as e2:
        print(f"CPU ALSO FAILED: {type(e2).__name__}: {e2}")
        traceback.print_exc()
