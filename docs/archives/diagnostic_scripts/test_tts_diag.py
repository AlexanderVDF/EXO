"""Test TTS server with error capture — sends synthesize and watches for errors."""
import asyncio
import json
import time
import websockets

async def test_with_error_capture():
    uri = "ws://localhost:8767"
    async with websockets.connect(uri, ping_interval=None, max_size=10_000_000) as ws:
        init = await asyncio.wait_for(ws.recv(), timeout=10)
        init_data = json.loads(init)
        print(f"Server: {init_data}")
        
        # Ask for voice list to confirm engine state
        await ws.send(json.dumps({"type": "list_voices"}))
        voices_msg = await asyncio.wait_for(ws.recv(), timeout=10)
        voices = json.loads(voices_msg)
        print(f"Voices: {len(voices.get('available', []))} available")
        
        # Now synthesize
        req = {
            "type": "synthesize",
            "text": "Test audio.",
            "voice": "Claribel Dervla",
            "lang": "fr",
        }
        print(f"\nSending synthesize: '{req['text']}'")
        await ws.send(json.dumps(req))
        
        total_bytes = 0
        msgs = []
        t0 = time.time()
        
        while True:
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=30)
            except asyncio.TimeoutError:
                print("TIMEOUT waiting for response")
                break
            if isinstance(msg, bytes):
                total_bytes += len(msg)
            else:
                data = json.loads(msg)
                msgs.append(data)
                if data.get("type") in ("end", "error"):
                    break
        
        elapsed = time.time() - t0
        print(f"Time: {elapsed:.3f}s")
        print(f"Total PCM bytes: {total_bytes}")
        for m in msgs:
            print(f"  Message: {m}")
        
        if total_bytes == 0:
            print("\n=== DIAGNOSIS ===")
            print("The server worker thread returned 0 bytes.")
            print("Most likely: model.inference() fails on DirectML device.")
            print("The error is caught by _stream_worker() and logged server-side only.")
            print("Check TTS server console for 'Stream worker error' messages.")

if __name__ == "__main__":
    asyncio.run(test_with_error_capture())
