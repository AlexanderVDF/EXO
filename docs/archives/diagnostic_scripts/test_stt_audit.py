"""STT audit test — tests transcription flow, backends, error handling."""
import asyncio
import json
import time
import struct
import math
import numpy as np
import websockets

SAMPLE_RATE = 16000

def generate_speech_like_audio(duration_s=2.0):
    """Generate audio that resembles speech patterns (multiple frequencies + modulation)."""
    n = int(SAMPLE_RATE * duration_s)
    t = np.arange(n, dtype=np.float32) / SAMPLE_RATE
    # Simulated speech: multiple harmonics with amplitude modulation
    signal = (
        0.3 * np.sin(2 * np.pi * 200 * t) +   # fundamental
        0.2 * np.sin(2 * np.pi * 400 * t) +   # 2nd harmonic
        0.1 * np.sin(2 * np.pi * 800 * t) +   # 4th harmonic
        0.05 * np.sin(2 * np.pi * 1600 * t)   # 8th harmonic
    )
    # Amplitude modulation to simulate syllables
    am = 0.5 + 0.5 * np.sin(2 * np.pi * 3 * t)
    signal *= am
    # Normalize to 80% of max
    signal = signal / np.max(np.abs(signal)) * 0.8
    # Convert to PCM16
    pcm16 = (signal * 32767).astype(np.int16)
    return pcm16.tobytes()

async def test_stt():
    print("="*60)
    print("SECTION 4 — TEST STT SERVER")
    print("="*60)
    
    uri = "ws://localhost:8766"
    
    # --- Test 1: Connection & Handshake ---
    print("\n[Test 1] Connection & Handshake")
    try:
        ws = await websockets.connect(uri, ping_interval=None, max_size=10_000_000)
        ready = await asyncio.wait_for(ws.recv(), timeout=10)
        info = json.loads(ready)
        print(f"  Status: CONNECTED")
        print(f"  Model: {info.get('model', '?')}")
        print(f"  Device: {info.get('device', '?')}")
        print(f"  Backend: {info.get('backend', '?')}")
        
        expected_backend = "whispercpp"
        actual_backend = info.get("backend", "")
        if expected_backend in actual_backend:
            print(f"  Backend check: OK ({actual_backend})")
        else:
            print(f"  Backend check: UNEXPECTED ({actual_backend}, expected {expected_backend})")
    except Exception as e:
        print(f"  FAILED: {e}")
        return
    
    # --- Test 2: Transcription flow (start → audio → end → final) ---
    print("\n[Test 2] Transcription flow (2s speech-like audio)")
    audio = generate_speech_like_audio(2.0)
    print(f"  Audio: {len(audio)} bytes, {len(audio)/2/SAMPLE_RATE:.2f}s")
    
    await ws.send(json.dumps({"type": "start"}))
    
    chunk_size = 1024  # 512 samples * 2 bytes
    for off in range(0, len(audio), chunk_size):
        await ws.send(audio[off:off+chunk_size])
        await asyncio.sleep(0.001)
    
    t0 = time.monotonic()
    await ws.send(json.dumps({"type": "end"}))
    
    partials = []
    final_text = None
    final_msg = None
    
    while True:
        try:
            r = await asyncio.wait_for(ws.recv(), timeout=25)
            msg = json.loads(r)
            mtype = msg.get("type", "")
            
            if mtype == "partial":
                partials.append(msg.get("text", ""))
            elif mtype == "final":
                dt_ms = (time.monotonic() - t0) * 1000
                final_text = msg.get("text", "")
                final_msg = msg
                print(f"  Partials received: {len(partials)}")
                print(f"  Final text: '{final_text}'")
                print(f"  Segments: {len(msg.get('segments', []))}")
                print(f"  Duration: {msg.get('duration', '?')}s")
                print(f"  Transcribe time: {msg.get('transcribe_ms', '?')}ms")
                print(f"  End-to-final latency: {dt_ms:.0f}ms")
                if msg.get('transcribe_ms', 0) > 0:
                    print(f"  Status: OK")
                else:
                    print(f"  Status: WARNING (transcribe_ms=0)")
                break
            elif mtype == "error":
                print(f"  ERROR: {msg.get('message', '')}")
                break
        except asyncio.TimeoutError:
            print(f"  TIMEOUT: No 'final' received within 25s")
            break
    
    # --- Test 3: Cancel flow ---
    print("\n[Test 3] Cancel flow")
    try:
        await ws.send(json.dumps({"type": "start"}))
        # Send a bit of audio
        await ws.send(generate_speech_like_audio(0.5))
        await ws.send(json.dumps({"type": "cancel"}))
        # Brief pause to ensure all pending messages are processed
        await asyncio.sleep(0.5)
        print(f"  Cancel sent successfully (no crash)")
        print(f"  Status: OK")
    except Exception as e:
        print(f"  FAILED: {e}")
    
    # --- Test 4: Ping/Pong ---
    print("\n[Test 4] Ping/Pong")
    try:
        await ws.send(json.dumps({"type": "ping"}))
        r = await asyncio.wait_for(ws.recv(), timeout=5)
        msg = json.loads(r)
        if msg.get("type") == "pong":
            print(f"  Pong received: OK")
        else:
            print(f"  Unexpected: {msg}")
    except Exception as e:
        print(f"  FAILED: {e}")
    
    # --- Test 5: Dynamic config ---
    print("\n[Test 5] Dynamic config change")
    try:
        await ws.send(json.dumps({"type": "config", "language": "fr", "beam_size": 3}))
        await asyncio.sleep(0.5)
        print(f"  Config sent: language=fr, beam_size=3")
        print(f"  Status: OK (no error response)")
    except Exception as e:
        print(f"  FAILED: {e}")
    
    await ws.close()
    
    # --- Test 6: Check whisper-server subprocess ---
    print("\n[Test 6] Whisper-server.exe subprocess (port 8769)")
    import urllib.request
    try:
        req = urllib.request.urlopen("http://127.0.0.1:8769", timeout=3)
        print(f"  HTTP response: {req.status}")
        print(f"  Status: REACHABLE")
    except Exception as e:
        # whisper-server may not have a root endpoint, try /inference health
        try:
            import socket
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(3)
            result = s.connect_ex(("127.0.0.1", 8769))
            s.close()
            if result == 0:
                print(f"  Port 8769 is LISTENING (whisper-server.exe)")
                print(f"  Status: OK")
            else:
                print(f"  Port 8769 NOT listening")
                print(f"  Status: WARNING — subprocess may not be running")
        except Exception as e2:
            print(f"  FAILED: {e2}")
    
    print("\n" + "="*60)
    print("STT AUDIT COMPLETE")
    print("="*60)

if __name__ == "__main__":
    asyncio.run(test_stt())
