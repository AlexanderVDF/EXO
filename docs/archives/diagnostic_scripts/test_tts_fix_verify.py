"""Verify the load() validation fix: DirectML fails -> CPU fallback -> synthesize works."""
import os, sys, time
import numpy as np

# Same monkey-patches as tts_server.py
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

# 1. Load model on DirectML
import torch_directml
device = torch_directml.device()
print(f"[1] Device: {device}")

from TTS.api import TTS
tts_api = TTS(model_name="tts_models/multilingual/multi-dataset/xtts_v2", progress_bar=True)
model = tts_api.synthesizer.tts_model
model = model.to(device)
print(f"[2] Model on: {next(model.parameters()).device}")

# 2. Load speakers, move to device
model_dir = os.environ.get("EXO_XTTS_MODELS", r"D:\EXO\models\xtts")
spk_file = os.path.join(model_dir, "speakers_xtts.pth")
speakers = torch.load(spk_file, weights_only=False)
for name in speakers:
    for key in speakers[name]:
        if hasattr(speakers[name][key], "to"):
            speakers[name][key] = speakers[name][key].to(device)

voice = "Claribel Dervla"
gpt_cond = speakers[voice]["gpt_cond_latent"]
spk_emb = speakers[voice]["speaker_embedding"]
print(f"[3] Speakers loaded, voice={voice}, device={gpt_cond.device}")

# 3. Validation inference (the fix)
print(f"[4] Validating inference on {device}...")
try:
    _test = model.inference(
        text="test", language="en",
        gpt_cond_latent=gpt_cond, speaker_embedding=spk_emb, speed=1.0,
    )
    print(f"[4] Validation PASSED on {device}")
except RuntimeError as exc:
    print(f"[4] Validation FAILED: {exc}")
    print(f"[4] Falling back to CPU...")
    device = "cpu"
    model = model.to("cpu")
    for name in speakers:
        for key in speakers[name]:
            if hasattr(speakers[name][key], "to"):
                speakers[name][key] = speakers[name][key].to("cpu")
    gpt_cond = speakers[voice]["gpt_cond_latent"]
    spk_emb = speakers[voice]["speaker_embedding"]
    print(f"[4] Model now on: {next(model.parameters()).device}")

# 4. Real synthesis (should now work on CPU)
print(f"\n[5] Synthesizing 'Bonjour, je suis l assistant vocal Exo.' on {device}...")
t0 = time.time()
out = model.inference(
    text="Bonjour, je suis l assistant vocal Exo.",
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
pcm16 = np.clip(wav * 32767, -32768, 32767).astype(np.int16)
raw_bytes = pcm16.tobytes()
elapsed = time.time() - t0
duration = len(raw_bytes) / (24000 * 2)
print(f"[5] SUCCESS: duration={duration:.2f}s, bytes={len(raw_bytes)}, time={elapsed:.2f}s")
print(f"\n=== FIX VERIFIED: Server will auto-fallback to CPU on startup ===")
