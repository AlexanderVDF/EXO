"""Quick test: send debug_audio_1.wav to whisper-server and get result."""
import urllib.request
import json
import io
import wave
import numpy as np

# Read debug audio 1 (the one with most signal)
with wave.open("debug_audio_1.wav", "rb") as w:
    pcm = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)

print(f"Input: {len(pcm)} samples, rms={np.sqrt(np.mean(pcm.astype(float)**2)):.1f}, peak={int(np.max(np.abs(pcm)))}")

# Re-encode as WAV
buf = io.BytesIO()
with wave.open(buf, "wb") as wf:
    wf.setnchannels(1)
    wf.setsampwidth(2)
    wf.setframerate(16000)
    wf.writeframes(pcm.tobytes())
wav_bytes = buf.getvalue()

# Also test with amplified version (20x gain)
pcm_loud = np.clip(pcm.astype(np.int32) * 20, -32768, 32767).astype(np.int16)
buf2 = io.BytesIO()
with wave.open(buf2, "wb") as wf:
    wf.setnchannels(1)
    wf.setsampwidth(2)
    wf.setframerate(16000)
    wf.writeframes(pcm_loud.tobytes())
wav_loud = buf2.getvalue()

print(f"Amplified: rms={np.sqrt(np.mean(pcm_loud.astype(float)**2)):.1f}, peak={int(np.max(np.abs(pcm_loud)))}")

boundary = "----TestBoundary123"

def send_to_whisper(wav_data, label):
    body = b""
    body += f"--{boundary}\r\n".encode()
    body += b'Content-Disposition: form-data; name="file"; filename="audio.wav"\r\n'
    body += b"Content-Type: audio/wav\r\n\r\n"
    body += wav_data
    body += f"\r\n--{boundary}\r\n".encode()
    body += b'Content-Disposition: form-data; name="response_format"\r\n\r\n'
    body += b"verbose_json"
    body += f"\r\n--{boundary}\r\n".encode()
    body += b'Content-Disposition: form-data; name="language"\r\n\r\n'
    body += b"fr"
    body += f"\r\n--{boundary}--\r\n".encode()

    req = urllib.request.Request(
        "http://127.0.0.1:8769/inference",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        result = json.loads(resp.read())
    print(f"\n[{label}] text={result.get('text', '')!r}")
    return result

send_to_whisper(wav_bytes, "Original (-22 dBFS)")
send_to_whisper(wav_loud, "Amplified (20x)")
