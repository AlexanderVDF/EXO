"""Quick STT latency test — sends 1.5s of sine wave and measures stop→final delay."""
import asyncio, websockets, json, time, struct, math

async def test_latency():
    sr, dur = 16000, 1.5
    n = int(sr * dur)
    samples = b""
    for i in range(n):
        v = int(16000 * math.sin(2 * math.pi * 440 * i / sr))
        samples += struct.pack("<h", v)

    async with websockets.connect("ws://localhost:8766") as ws:
        ready = await asyncio.wait_for(ws.recv(), timeout=5)
        print("Server:", ready)

        await ws.send(json.dumps({"type": "start"}))

        chunk_bytes = 512 * 2
        for off in range(0, len(samples), chunk_bytes):
            await ws.send(samples[off : off + chunk_bytes])
            await asyncio.sleep(0.001)

        t0 = time.monotonic()
        await ws.send(json.dumps({"type": "end"}))

        while True:
            r = await asyncio.wait_for(ws.recv(), timeout=10)
            msg = json.loads(r)
            mtype = msg.get("type", "")
            if mtype == "final":
                dt = (time.monotonic() - t0) * 1000
                text = msg.get("text", "")
                print(f"Final transcript: '{text}'")
                print(f"STT latency (stop -> final): {dt:.0f} ms")
                break
            elif mtype == "error":
                print("Error:", msg)
                break
            else:
                print(f"  [{mtype}] {msg.get('text', '')}")

asyncio.run(test_latency())
