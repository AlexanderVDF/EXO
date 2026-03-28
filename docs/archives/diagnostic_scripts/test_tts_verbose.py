"""Direct TTS synthesize() test — bypasses WebSocket to isolate the issue."""
import asyncio
import json
import time
import traceback
import websockets

async def test_tts_verbose():
    uri = "ws://localhost:8767"
    print(f"[1] Connecting to {uri}...")
    async with websockets.connect(uri, ping_interval=None, max_size=10_000_000) as ws:
        init = await asyncio.wait_for(ws.recv(), timeout=10)
        init_data = json.loads(init)
        print(f"[2] Handshake OK: {init_data}")

        # Test 1: Short text
        for text in [
            "Bonjour.",
            "Ceci est un test.",
            "Hello, this is a test.",
        ]:
            req = {
                "type": "synthesize",
                "text": text,
                "lang": "fr",
                "rate": 1.0,
            }
            print(f"\n[TEST] '{text}'")
            await ws.send(json.dumps(req))

            total_bytes = 0
            chunks = 0
            t0 = time.time()

            while True:
                msg = await asyncio.wait_for(ws.recv(), timeout=120)
                if isinstance(msg, bytes):
                    chunks += 1
                    total_bytes += len(msg)
                else:
                    data = json.loads(msg)
                    print(f"  JSON: {data}")
                    if data.get("type") in ("end", "error"):
                        break

            elapsed = time.time() - t0
            if total_bytes > 0:
                dur = total_bytes / (24000 * 2)
                print(f"  OK: {chunks} chunks, {total_bytes} bytes, audio={dur:.2f}s, time={elapsed:.2f}s")
            else:
                print(f"  FAIL: 0 bytes in {elapsed:.2f}s")

if __name__ == "__main__":
    asyncio.run(test_tts_verbose())
