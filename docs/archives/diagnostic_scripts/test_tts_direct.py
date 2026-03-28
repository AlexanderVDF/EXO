"""Direct XTTS model test — bypass server, test synthesize() directly."""
import sys
import os
import time
import traceback

# Add project root
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Set env vars
os.environ.setdefault("EXO_XTTS_MODELS", r"D:\EXO\models\xtts")

# Apply same monkey-patches as tts_server.py
import torch
torch.inference_mode = torch.no_grad

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
except Exception:
    pass

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

# Now test
print("[1] Loading XTTS model...")
try:
    from TTS.api import TTS
    model_dir = os.environ.get("EXO_XTTS_MODELS", r"D:\EXO\models\xtts")
    tts_api = TTS(model_path=model_dir, config_path=os.path.join(model_dir, "config.json"))
    model = tts_api.synthesizer.tts_model
    device = next(model.parameters()).device
    print(f"    Model loaded on device: {device}")
except Exception as e:
    print(f"    FAIL loading model: {e}")
    traceback.print_exc()
    sys.exit(1)

# Load speakers
print("[2] Loading speakers...")
spk_file = os.path.join(model_dir, "speakers_xtts.pth")
if os.path.exists(spk_file):
    speakers = torch.load(spk_file, weights_only=False)
    print(f"    {len(speakers)} speakers loaded")
    for name in sorted(speakers.keys()):
        print(f"      - {name}")
else:
    print("    FAIL: no speakers file")
    sys.exit(1)

# Test inference
print("[3] Testing model.inference()...")
voice = "Claribel Dervla"
if voice not in speakers:
    print(f"    FAIL: voice '{voice}' not in speakers")
    sys.exit(1)

import numpy as np
t0 = time.time()
try:
    out = model.inference(
        text="Bonjour, ceci est un test.",
        language="fr",
        gpt_cond_latent=speakers[voice]["gpt_cond_latent"],
        speaker_embedding=speakers[voice]["speaker_embedding"],
        speed=1.0,
    )
    wav = out["wav"]
    if hasattr(wav, "cpu"):
        wav = wav.cpu()
    if hasattr(wav, "numpy"):
        wav = wav.numpy()
    wav = np.asarray(wav, dtype=np.float32)
    elapsed = time.time() - t0
    print(f"    OK: wav shape={wav.shape}, duration={len(wav)/24000:.2f}s, time={elapsed:.2f}s")
    
    pcm = np.clip(wav * 32767, -32768, 32767).astype(np.int16)
    print(f"    PCM bytes: {len(pcm.tobytes())}")
except Exception as e:
    elapsed = time.time() - t0
    print(f"    FAIL ({elapsed:.2f}s): {e}")
    traceback.print_exc()

print("\n[DONE]")
