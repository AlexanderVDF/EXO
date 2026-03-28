"""
TTS XTTS v2 — Diagnostic complet
Exécute toutes les étapes du diagnostic en séquence.
"""
import asyncio
import json
import time
import sys

try:
    import websockets
except ImportError:
    print("ERREUR: websockets non installé")
    sys.exit(1)

WS_URL = "ws://localhost:8767"
RESULTS = {}


async def step1_verify_service():
    """Étape 1: Vérification du service XTTS"""
    print("\n" + "=" * 60)
    print("ÉTAPE 1: VÉRIFICATION DU SERVICE XTTS")
    print("=" * 60)
    try:
        ws = await asyncio.wait_for(websockets.connect(WS_URL), timeout=5)
        msg = await asyncio.wait_for(ws.recv(), timeout=5)
        data = json.loads(msg)
        print(f"  ✓ Service actif sur {WS_URL}")
        print(f"  ✓ Type: {data.get('type')}")
        print(f"  ✓ Voice: {data.get('voice')}")
        print(f"  ✓ Sample rate: {data.get('sample_rate')}")
        print(f"  ✓ Backend: {data.get('backend')}")
        RESULTS["service"] = "OK"
        RESULTS["ready_data"] = data
        return ws
    except Exception as e:
        print(f"  ✗ Service DOWN: {e}")
        RESULTS["service"] = f"KO: {e}"
        return None


async def step2_test_connection(ws):
    """Étape 2: Test de connexion — ping/pong"""
    print("\n" + "=" * 60)
    print("ÉTAPE 2: TEST DE CONNEXION XTTS")
    print("=" * 60)
    if ws is None:
        print("  ✗ Pas de connexion disponible")
        RESULTS["connection"] = "KO: pas de WS"
        return None
    try:
        await ws.send(json.dumps({"type": "ping"}))
        msg = await asyncio.wait_for(ws.recv(), timeout=5)
        data = json.loads(msg)
        if data.get("type") == "pong":
            print(f"  ✓ Ping → Pong OK")
            RESULTS["connection"] = "OK"
        else:
            print(f"  ? Réponse inattendue: {data}")
            RESULTS["connection"] = f"INATTENDU: {data}"
        return ws
    except Exception as e:
        print(f"  ✗ Erreur connexion: {e}")
        RESULTS["connection"] = f"KO: {e}"
        return None


async def step3_test_simple(ws):
    """Étape 3: Test de synthèse simple"""
    print("\n" + "=" * 60)
    print("ÉTAPE 3: TEST DE SYNTHÈSE SIMPLE (SANS GUI)")
    print("=" * 60)
    if ws is None:
        print("  ✗ Pas de connexion")
        RESULTS["synth_simple"] = "KO: pas de WS"
        return ws

    text = "Bonjour, ceci est un test."
    await ws.send(json.dumps({
        "type": "synthesize",
        "text": text,
        "lang": "fr",
        "rate": 1.0,
        "pitch": 1.0,
    }))

    t0 = time.monotonic()
    chunks = 0
    total_bytes = 0
    got_start = False
    got_end = False
    end_data = None
    errors = []

    try:
        while True:
            msg = await asyncio.wait_for(ws.recv(), timeout=15)
            if isinstance(msg, bytes):
                chunks += 1
                total_bytes += len(msg)
            else:
                data = json.loads(msg)
                mtype = data.get("type", "")
                if mtype == "start":
                    got_start = True
                    print(f"  ✓ Header JSON 'start' reçu: text={data.get('text', '')[:40]}")
                elif mtype == "end":
                    got_end = True
                    end_data = data
                    break
                elif mtype == "error":
                    errors.append(data.get("message", ""))
                    print(f"  ✗ Erreur serveur: {data.get('message')}")
                    break
                else:
                    print(f"  ? Message: {data}")
    except asyncio.TimeoutError:
        print("  ✗ TIMEOUT après 15s")
    except Exception as e:
        print(f"  ✗ Exception: {e}")

    dt = time.monotonic() - t0
    duration_est = total_bytes / (24000 * 2) if total_bytes > 0 else 0

    print(f"  Chunks PCM reçus: {chunks}")
    print(f"  Taille totale: {total_bytes} bytes")
    print(f"  Durée estimée audio: {duration_est:.2f}s")
    print(f"  Temps total: {dt:.2f}s")

    if got_start and got_end and chunks > 0:
        print(f"  ✓ Synthèse RÉUSSIE")
        if end_data:
            print(f"    Duration: {end_data.get('duration')}s, synth_ms: {end_data.get('synth_ms')}ms")
        RESULTS["synth_simple"] = f"OK: {chunks} chunks, {total_bytes} bytes, {duration_est:.2f}s"
    else:
        print(f"  ✗ Synthèse ÉCHOUÉE (start={got_start}, end={got_end}, chunks={chunks})")
        RESULTS["synth_simple"] = f"KO: start={got_start}, end={got_end}, chunks={chunks}, errors={errors}"

    return ws


async def step4_test_voice_fr(ws):
    """Étape 4: Test voix FR"""
    print("\n" + "=" * 60)
    print("ÉTAPE 4: TEST DE VOIX COMPATIBLE (fr-FR-siwis)")
    print("=" * 60)
    if ws is None:
        RESULTS["voice_fr"] = "KO: pas de WS"
        return ws

    # Lister les voix disponibles
    await ws.send(json.dumps({"type": "list_voices"}))
    msg = await asyncio.wait_for(ws.recv(), timeout=5)
    data = json.loads(msg)
    voices = data.get("available", [])
    print(f"  Voix disponibles ({len(voices)}): {voices[:10]}{'...' if len(voices) > 10 else ''}")

    # Tester changement de voix
    target_voice = "fr-FR-siwis"
    if target_voice not in voices:
        print(f"  ! Voix '{target_voice}' non disponible, test avec voix courante")
        target_voice = None
    else:
        await ws.send(json.dumps({"type": "set_voice", "voice": target_voice}))
        msg = await asyncio.wait_for(ws.recv(), timeout=5)
        voice_data = json.loads(msg)
        print(f"  Changement voix: {voice_data}")

    # Synthèse test FR
    await ws.send(json.dumps({
        "type": "synthesize",
        "text": "Bonjour, ceci est un test avec la voix française.",
        "voice": target_voice,
        "lang": "fr",
        "rate": 1.0,
    }))

    chunks = 0
    total_bytes = 0
    try:
        while True:
            msg = await asyncio.wait_for(ws.recv(), timeout=15)
            if isinstance(msg, bytes):
                chunks += 1
                total_bytes += len(msg)
            else:
                data = json.loads(msg)
                if data.get("type") == "end":
                    break
                elif data.get("type") == "error":
                    print(f"  ✗ Erreur: {data.get('message')}")
                    break
    except asyncio.TimeoutError:
        print("  ✗ TIMEOUT")

    if chunks > 0:
        print(f"  ✓ Voix FR: {chunks} chunks, {total_bytes} bytes")
        RESULTS["voice_fr"] = f"OK: {chunks} chunks"
    else:
        print(f"  ✗ Voix FR: aucun chunk PCM reçu")
        RESULTS["voice_fr"] = "KO: 0 chunks"

    return ws


async def step5_test_sans_emoji(ws):
    """Étape 5: Test sans emojis"""
    print("\n" + "=" * 60)
    print("ÉTAPE 5: TEST SANS EMOJIS")
    print("=" * 60)
    if ws is None:
        RESULTS["sans_emoji"] = "KO: pas de WS"
        return ws

    await ws.send(json.dumps({
        "type": "synthesize",
        "text": "Bonjour Alex, comment vas-tu aujourd'hui ?",
        "lang": "fr",
        "rate": 1.0,
    }))

    chunks = 0
    total_bytes = 0
    try:
        while True:
            msg = await asyncio.wait_for(ws.recv(), timeout=15)
            if isinstance(msg, bytes):
                chunks += 1
                total_bytes += len(msg)
            else:
                data = json.loads(msg)
                if data.get("type") == "end":
                    break
                elif data.get("type") == "error":
                    print(f"  ✗ Erreur: {data.get('message')}")
                    break
    except asyncio.TimeoutError:
        print("  ✗ TIMEOUT")

    if chunks > 0:
        print(f"  ✓ Sans emoji: {chunks} chunks, {total_bytes} bytes")
        RESULTS["sans_emoji"] = f"OK: {chunks} chunks"
    else:
        print(f"  ✗ Sans emoji: aucun chunk PCM reçu")
        RESULTS["sans_emoji"] = "KO: 0 chunks"

    return ws


async def step6_test_avec_emoji(ws):
    """Étape 6: Test avec emojis"""
    print("\n" + "=" * 60)
    print("ÉTAPE 6: TEST AVEC EMOJIS")
    print("=" * 60)
    if ws is None:
        RESULTS["avec_emoji"] = "KO: pas de WS"
        return ws

    await ws.send(json.dumps({
        "type": "synthesize",
        "text": "Bonjour Alex \U0001f60a",
        "lang": "fr",
        "rate": 1.0,
    }))

    chunks = 0
    total_bytes = 0
    try:
        while True:
            msg = await asyncio.wait_for(ws.recv(), timeout=15)
            if isinstance(msg, bytes):
                chunks += 1
                total_bytes += len(msg)
            else:
                data = json.loads(msg)
                if data.get("type") == "end":
                    break
                elif data.get("type") == "error":
                    print(f"  ✗ Erreur: {data.get('message')}")
                    break
    except asyncio.TimeoutError:
        print("  ✗ TIMEOUT")

    if chunks > 0:
        print(f"  ✓ Avec emoji: {chunks} chunks, {total_bytes} bytes")
        RESULTS["avec_emoji"] = f"OK: {chunks} chunks"
    else:
        print(f"  ✗ Avec emoji: aucun chunk PCM reçu")
        RESULTS["avec_emoji"] = "KO: 0 chunks"

    return ws


async def run_all():
    ws = await step1_verify_service()
    ws = await step2_test_connection(ws)
    ws = await step3_test_simple(ws)
    ws = await step4_test_voice_fr(ws)
    ws = await step5_test_sans_emoji(ws)
    ws = await step6_test_avec_emoji(ws)

    if ws:
        await ws.close()

    # Rapport
    print("\n" + "=" * 60)
    print("RAPPORT DIAGNOSTIC XTTS v2")
    print("=" * 60)
    for key, val in RESULTS.items():
        status = "✓" if val.startswith("OK") else "✗"
        print(f"  {status} {key}: {val}")


if __name__ == "__main__":
    asyncio.run(run_all())
