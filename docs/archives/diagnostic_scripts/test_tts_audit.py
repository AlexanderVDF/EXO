"""Quick TTS audit test — verifies WebSocket handshake + synthesis."""
import asyncio
import json
import time
import websockets

async def test_tts():
    uri = "ws://localhost:8767"
    print(f"[1] Connecting to {uri}...")
    async with websockets.connect(uri, ping_interval=None) as ws:
        init = await asyncio.wait_for(ws.recv(), timeout=10)
        init_data = json.loads(init)
        print(f"[2] Handshake: type={init_data.get('type')}, sample_rate={init_data.get('sample_rate')}")

        req = {
            "type": "synthesize",
            "text": "Bonjour, ceci est un test audio.",
            "voice": "Claribel Dervla",
            "lang": "fr",
            "rate": 1.0,
            "pitch": 1.0,
        }
        print(f"[3] Sending synthesize...")
        await ws.send(json.dumps(req))

        total_bytes = 0
        chunks = 0
        t0 = time.time()

        while True:
            msg = await asyncio.wait_for(ws.recv(), timeout=60)
            if isinstance(msg, bytes):
                chunks += 1
                total_bytes += len(msg)
                if chunks <= 3:
                    print(f"    chunk #{chunks}: {len(msg)} bytes")
            else:
                data = json.loads(msg)
                print(f"[4] JSON: {data}")
                if data.get("type") in ("end", "error"):
                    break

        elapsed = time.time() - t0
        print(f"[5] RESULT: {chunks} chunks, {total_bytes} total bytes, {elapsed:.2f}s")
        if total_bytes > 0:
            duration = total_bytes / (24000 * 2)
            print(f"    Audio: {duration:.2f}s @ 24kHz 16-bit mono")
            print("    STATUS: OK")
        else:
            print("    STATUS: FAIL - 0 bytes PCM")

if __name__ == "__main__":
    asyncio.run(test_tts())
