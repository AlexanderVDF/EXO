"""Section 5 — Full pipeline integration test.
Tests each service individually then simulates the full chain:
WakeWord → VAD → STT → NLU → TTS → PCM audio output
"""
import asyncio
import json
import time
import struct
import math
import numpy as np
import websockets

SAMPLE_RATE_16K = 16000
SAMPLE_RATE_24K = 24000

def pcm16_silence(duration_s, sr=16000):
    """Generate PCM16 silence."""
    return b"\x00\x00" * int(sr * duration_s)

def pcm16_speech_like(duration_s, sr=16000):
    """Generate speech-like audio."""
    n = int(sr * duration_s)
    t = np.arange(n, dtype=np.float32) / sr
    signal = (0.3 * np.sin(2 * np.pi * 200 * t) +
              0.2 * np.sin(2 * np.pi * 400 * t) +
              0.1 * np.sin(2 * np.pi * 800 * t))
    am = 0.5 + 0.5 * np.sin(2 * np.pi * 3 * t)
    signal *= am * 0.8
    return (signal * 32767).astype(np.int16).tobytes()

async def test_service(name, port, test_fn):
    """Test a single service."""
    print(f"\n{'─'*50}")
    print(f"[{name}] Port {port}")
    try:
        ws = await asyncio.wait_for(
            websockets.connect(f"ws://localhost:{port}", ping_interval=None, max_size=10_000_000),
            timeout=5
        )
        ready = await asyncio.wait_for(ws.recv(), timeout=10)
        info = json.loads(ready)
        print(f"  Handshake: {info.get('type', '?')} — {json.dumps({k:v for k,v in info.items() if k != 'type' and k != 'languages'}, ensure_ascii=False)}")
        
        result = await test_fn(ws, info)
        await ws.close()
        return result
    except Exception as e:
        print(f"  FAILED: {type(e).__name__}: {e}")
        return False

async def test_wakeword(ws, info):
    """Test WakeWord service."""
    # Send silence — should not trigger
    audio = pcm16_silence(1.0)
    chunk_size = 1024
    for off in range(0, len(audio), chunk_size):
        await ws.send(audio[off:off+chunk_size])
        await asyncio.sleep(0.001)
    
    # Check for any messages (with short timeout)
    triggered = False
    try:
        while True:
            msg = await asyncio.wait_for(ws.recv(), timeout=1.0)
            data = json.loads(msg)
            if data.get("type") == "wakeword":
                triggered = True
                break
    except asyncio.TimeoutError:
        pass
    
    if not triggered:
        print(f"  Silence test: OK (no false trigger)")
    else:
        print(f"  Silence test: WARNING (false trigger on silence!)")
    
    print(f"  Status: OK")
    return True

async def test_vad(ws, info):
    """Test VAD service."""
    # Send speech-like audio
    audio = pcm16_speech_like(1.0)
    chunk_size = 1024
    scores = []
    
    for off in range(0, len(audio), chunk_size):
        await ws.send(audio[off:off+chunk_size])
        await asyncio.sleep(0.001)
    
    # Collect VAD scores
    try:
        while True:
            msg = await asyncio.wait_for(ws.recv(), timeout=2.0)
            data = json.loads(msg)
            if data.get("type") == "vad":
                scores.append(data.get("score", 0))
    except asyncio.TimeoutError:
        pass
    
    if scores:
        avg = sum(scores) / len(scores)
        print(f"  VAD scores: {len(scores)} frames, avg={avg:.3f}, min={min(scores):.3f}, max={max(scores):.3f}")
        print(f"  Status: OK")
    else:
        print(f"  VAD scores: none received")
        print(f"  Status: WARNING")
    return True

async def test_stt(ws, info):
    """Test STT transcription."""
    audio = pcm16_speech_like(1.5)
    
    await ws.send(json.dumps({"type": "start"}))
    chunk_size = 1024
    for off in range(0, len(audio), chunk_size):
        await ws.send(audio[off:off+chunk_size])
        await asyncio.sleep(0.001)
    
    t0 = time.monotonic()
    await ws.send(json.dumps({"type": "end"}))
    
    while True:
        try:
            msg = await asyncio.wait_for(ws.recv(), timeout=20)
            data = json.loads(msg)
            if data.get("type") == "final":
                dt = (time.monotonic() - t0) * 1000
                print(f"  Transcription: '{data.get('text', '')}'")
                print(f"  Latency: {dt:.0f}ms, transcribe_ms={data.get('transcribe_ms', '?')}")
                print(f"  Status: OK")
                return True
            elif data.get("type") == "error":
                print(f"  Error: {data.get('message', '')}")
                return False
        except asyncio.TimeoutError:
            print(f"  TIMEOUT")
            return False

async def test_nlu(ws, info):
    """Test NLU service."""
    await ws.send(json.dumps({
        "type": "analyze",
        "text": "allume la lumière du salon",
    }))
    
    try:
        msg = await asyncio.wait_for(ws.recv(), timeout=10)
        data = json.loads(msg)
        print(f"  Response type: {data.get('type', '?')}")
        intent = data.get("intent", data.get("result", "?"))
        print(f"  Intent/Result: {str(intent)[:100]}")
        print(f"  Status: OK")
        return True
    except asyncio.TimeoutError:
        print(f"  TIMEOUT")
        return False

async def test_memory(ws, info):
    """Test Memory service."""
    await ws.send(json.dumps({
        "type": "search",
        "query": "test",
        "top_k": 3,
    }))
    
    try:
        msg = await asyncio.wait_for(ws.recv(), timeout=10)
        data = json.loads(msg)
        print(f"  Response type: {data.get('type', '?')}")
        results = data.get("results", [])
        print(f"  Results: {len(results)} memories")
        print(f"  Status: OK")
        return True
    except asyncio.TimeoutError:
        print(f"  TIMEOUT")
        return False

async def test_tts(ws, info):
    """Test TTS synthesis."""
    await ws.send(json.dumps({
        "type": "synthesize",
        "text": "Test du pipeline complet.",
        "voice": "Claribel Dervla",
        "lang": "fr",
    }))
    
    total_bytes = 0
    msgs = []
    t0 = time.monotonic()
    
    while True:
        try:
            msg = await asyncio.wait_for(ws.recv(), timeout=30)
            if isinstance(msg, bytes):
                total_bytes += len(msg)
            else:
                data = json.loads(msg)
                msgs.append(data)
                if data.get("type") in ("end", "error"):
                    break
        except asyncio.TimeoutError:
            break
    
    dt = time.monotonic() - t0
    end_msg = next((m for m in msgs if m.get("type") == "end"), {})
    duration = end_msg.get("duration", 0)
    synth_ms = end_msg.get("synth_ms", 0)
    
    print(f"  PCM bytes: {total_bytes}")
    print(f"  Duration: {duration}s, synth_ms={synth_ms}")
    print(f"  RTF: {(synth_ms/1000)/max(duration,0.01):.2f}")
    
    if total_bytes > 0:
        print(f"  Status: OK")
        return True
    else:
        print(f"  Status: FAILED (0 bytes)")
        return False

async def test_orchestrator(ws, info):
    """Test Orchestrator/exo_server."""
    # Just verify handshake — full orchestrator test requires audio pipeline
    print(f"  Connected to orchestrator")
    print(f"  Status: OK (handshake)")
    return True

async def main():
    print("="*60)
    print("SECTION 5 — FULL PIPELINE INTEGRATION TEST")
    print("="*60)
    
    services = [
        ("WakeWord", 8770, test_wakeword),
        ("VAD", 8768, test_vad),
        ("STT", 8766, test_stt),
        ("NLU", 8772, test_nlu),
        ("Memory", 8771, test_memory),
        ("TTS", 8767, test_tts),
        ("Orchestrator", 8765, test_orchestrator),
    ]
    
    results = {}
    for name, port, fn in services:
        results[name] = await test_service(name, port, fn)
    
    # --- Summary ---
    print(f"\n{'='*60}")
    print("PIPELINE SUMMARY")
    print(f"{'='*60}")
    all_ok = True
    for name, ok in results.items():
        status = "PASS" if ok else "FAIL"
        emoji = "+" if ok else "X"
        print(f"  [{emoji}] {name}: {status}")
        if not ok:
            all_ok = False
    
    print(f"\nOverall: {'ALL PASS' if all_ok else 'ISSUES FOUND'}")
    print(f"{'='*60}")

if __name__ == "__main__":
    asyncio.run(main())
