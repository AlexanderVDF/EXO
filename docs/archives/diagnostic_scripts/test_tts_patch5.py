"""Test GPT.generate() monkey-patch fix on DirectML — simulates tts_server.py flow."""
import os, sys, time, traceback
import numpy as np

# --- Same monkey-patches as tts_server.py ---
import torch
torch.inference_mode = torch.no_grad

# Patch isin_mps_friendly
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

# Patch StreamGenerationConfig
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

# Patch _get_logits_warper
try:
    from transformers.generation import (
        LogitsProcessorList, TemperatureLogitsWarper, TopKLogitsWarper,
        TopPLogitsWarper, TypicalLogitsWarper, EpsilonLogitsWarper, EtaLogitsWarper,
    )
    from TTS.tts.layers.xtts.stream_generator import NewGenerationMixin
    def _patched_get_logits_warper(self, generation_config):
        warpers = LogitsProcessorList()
        if generation_config.temperature is not None and generation_config.temperature != 1.0:
            warpers.append(TemperatureLogitsWarper(generation_config.temperature))
        min_tokens_to_keep = 1
        if generation_config.top_k is not None and generation_config.top_k != 0:
            warpers.append(TopKLogitsWarper(top_k=generation_config.top_k, min_tokens_to_keep=min_tokens_to_keep))
        if generation_config.top_p is not None and generation_config.top_p < 1.0:
            warpers.append(TopPLogitsWarper(top_p=generation_config.top_p, min_tokens_to_keep=min_tokens_to_keep))
        return warpers
    from transformers import PreTrainedModel
    PreTrainedModel._get_logits_warper = _patched_get_logits_warper
except Exception:
    pass

# Patch #4: GPT.get_generator (streaming)
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

    # Patch #5 (NEW FIX): GPT.generate (non-streaming — used by model.inference)
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
except Exception as e:
    print(f"WARNING: Failed to patch GPT: {e}")

os.environ.setdefault("EXO_XTTS_MODELS", r"D:\EXO\models\xtts")

# --- Load model on DirectML ---
print("=== Step 1: Detect device ===")
import torch_directml
device = torch_directml.device()
print(f"Device: {device}")

print("=== Step 2: Load model ===")
from TTS.api import TTS
tts_api = TTS(model_name="tts_models/multilingual/multi-dataset/xtts_v2", progress_bar=True)
model = tts_api.synthesizer.tts_model
model = model.to(device)
print(f"Model on: {next(model.parameters()).device}")

print("=== Step 3: Load speakers ===")
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
print(f"Speakers loaded, device={gpt_cond.device}")

print("\n=== Step 4: model.inference() ON DIRECTML (with GPT.generate patch) ===")
try:
    t0 = time.time()
    out = model.inference(
        text="Bonjour, je suis Exo.",
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
    print(f"SUCCESS on DirectML: duration={duration:.2f}s, bytes={len(raw_bytes)}, time={elapsed:.2f}s")
except Exception as e:
    print(f"FAILED: {type(e).__name__}: {e}")
    traceback.print_exc()
