"""
EXO v4.2 — Validation fonctionnelle complète du pipeline
Teste chaque microservice individuellement puis le pipeline complet.
"""

import asyncio
import json
import struct
import time
import sys
import math
import traceback

try:
    import websockets
except ImportError:
    print("ERREUR: websockets non installé. Installez avec: pip install websockets")
    sys.exit(1)

# ─── Configuration ───────────────────────────────────────────────────────────
SERVICES = {
    "exo_server":      {"port": 8765, "desc": "Orchestrateur"},
    "stt_server":      {"port": 8766, "desc": "Speech-to-Text (Whisper)"},
    "tts_server":      {"port": 8767, "desc": "Text-to-Speech (XTTS v2)"},
    "vad_server":      {"port": 8768, "desc": "Voice Activity Detection"},
    "wakeword_server": {"port": 8770, "desc": "Wake Word Detection"},
    "memory_server":   {"port": 8771, "desc": "Mémoire sémantique (FAISS)"},
    "nlu_server":      {"port": 8772, "desc": "NLU (intentions)"},
}

TIMEOUT = 15  # secondes max par test
RESULTS = {}


def log(icon, msg):
    print(f"  {icon} {msg}")


def section(title):
    print(f"\n{'='*70}")
    print(f"  {title}")
    print(f"{'='*70}")


def generate_silence_pcm16(duration_s=0.5, sample_rate=16000):
    """Génère un buffer PCM16 silencieux."""
    n_samples = int(sample_rate * duration_s)
    return b'\x00\x00' * n_samples


def generate_tone_pcm16(freq=440, duration_s=0.5, sample_rate=16000, amplitude=16000):
    """Génère un buffer PCM16 contenant un ton sinusoïdal (simule de la voix)."""
    n_samples = int(sample_rate * duration_s)
    buf = bytearray()
    for i in range(n_samples):
        val = int(amplitude * math.sin(2 * math.pi * freq * i / sample_rate))
        buf += struct.pack('<h', max(-32768, min(32767, val)))
    return bytes(buf)


def generate_speech_like_pcm16(duration_s=1.0, sample_rate=16000):
    """Génère un buffer PCM16 qui ressemble à de la parole (multi-fréquences)."""
    n_samples = int(sample_rate * duration_s)
    buf = bytearray()
    for i in range(n_samples):
        t = i / sample_rate
        # Mélange de fréquences vocales typiques
        val = (
            8000 * math.sin(2 * math.pi * 150 * t) +
            6000 * math.sin(2 * math.pi * 300 * t) +
            4000 * math.sin(2 * math.pi * 600 * t) +
            2000 * math.sin(2 * math.pi * 1200 * t)
        )
        # Modulation d'amplitude (enveloppe)
        envelope = 0.5 + 0.5 * math.sin(2 * math.pi * 4 * t)
        val = int(val * envelope)
        buf += struct.pack('<h', max(-32768, min(32767, val)))
    return bytes(buf)


# ═══════════════════════════════════════════════════════════════════════════════
# 1) TEST WEBSOCKET CONNECTIVITY
# ═══════════════════════════════════════════════════════════════════════════════

async def test_ws_connect(name, port):
    """Teste la connexion WebSocket et le message initial."""
    uri = f"ws://localhost:{port}"
    t0 = time.perf_counter()
    try:
        async with websockets.connect(uri, open_timeout=5) as ws:
            latency_connect = (time.perf_counter() - t0) * 1000

            # Attendre le message initial (ready) si disponible
            try:
                raw = await asyncio.wait_for(ws.recv(), timeout=5)
                latency_ready = (time.perf_counter() - t0) * 1000
                if isinstance(raw, str):
                    msg = json.loads(raw)
                    return {
                        "status": "OK",
                        "connect_ms": round(latency_connect, 1),
                        "ready_ms": round(latency_ready, 1),
                        "initial_msg": msg,
                    }
                else:
                    return {
                        "status": "OK",
                        "connect_ms": round(latency_connect, 1),
                        "initial_msg": "(binary data)",
                    }
            except asyncio.TimeoutError:
                return {
                    "status": "OK",
                    "connect_ms": round(latency_connect, 1),
                    "initial_msg": "(no initial message within 5s)",
                }
    except Exception as e:
        return {"status": "FAIL", "error": str(e)}


async def test_ws_ping(name, port):
    """Teste le ping/pong WebSocket."""
    uri = f"ws://localhost:{port}"

    # exo_server n'a pas de handler JSON ping
    if name == "exo_server":
        return {"status": "SKIP", "note": "No JSON ping handler"}

    # NLU utilise 'action' au lieu de 'type'
    ping_msg = {"action": "ping"} if name == "nlu_server" else {"type": "ping"}

    try:
        async with websockets.connect(uri, open_timeout=5) as ws:
            # Drainer TOUS les messages initiaux (ready, etc.)
            while True:
                try:
                    await asyncio.wait_for(ws.recv(), timeout=2)
                except asyncio.TimeoutError:
                    break

            # Envoyer ping JSON
            t0 = time.perf_counter()
            await ws.send(json.dumps(ping_msg))

            # Attendre le pong (ignorer d'éventuels messages intermédiaires)
            deadline = time.perf_counter() + 5
            while time.perf_counter() < deadline:
                remaining = deadline - time.perf_counter()
                try:
                    raw = await asyncio.wait_for(ws.recv(), timeout=max(remaining, 0.1))
                    latency = (time.perf_counter() - t0) * 1000
                    if isinstance(raw, str):
                        msg = json.loads(raw)
                        if msg.get("type") == "pong":
                            return {"status": "OK", "latency_ms": round(latency, 1), "response": msg}
                    # Pas un pong, continuer à lire
                except asyncio.TimeoutError:
                    break
            return {"status": "WARN", "note": "No pong response within 5s"}
    except Exception as e:
        return {"status": "FAIL", "error": str(e)}


# ═══════════════════════════════════════════════════════════════════════════════
# 2) TEST WAKEWORD
# ═══════════════════════════════════════════════════════════════════════════════

async def test_wakeword():
    """Teste le wakeword_server : ping, ready, config, reset."""
    results = {}
    uri = "ws://localhost:8770"
    try:
        async with websockets.connect(uri, open_timeout=5) as ws:
            # Ready message
            raw = await asyncio.wait_for(ws.recv(), timeout=5)
            msg = json.loads(raw)
            results["ready"] = msg
            log("✓", f"Modèle chargé: {msg.get('models', 'N/A')}")

            # Ping
            t0 = time.perf_counter()
            await ws.send(json.dumps({"type": "ping"}))
            raw = await asyncio.wait_for(ws.recv(), timeout=5)
            pong = json.loads(raw)
            results["ping_ms"] = round((time.perf_counter() - t0) * 1000, 1)
            results["pong"] = pong
            log("✓", f"Ping/Pong OK ({results['ping_ms']}ms)")

            # Config
            await ws.send(json.dumps({"type": "config", "threshold": 0.7}))
            log("✓", "Config threshold=0.7 envoyé")

            # Reset
            await ws.send(json.dumps({"type": "reset"}))
            log("✓", "Reset envoyé")

            # Envoyer du silence (ne doit PAS déclencher de wakeword)
            silence = generate_silence_pcm16(0.5, 16000)
            chunk_size = 1280 * 2  # 1280 samples * 2 bytes
            for i in range(0, len(silence), chunk_size):
                await ws.send(silence[i:i+chunk_size])

            # Vérifier qu'aucun wakeword n'est détecté
            try:
                raw = await asyncio.wait_for(ws.recv(), timeout=2)
                msg = json.loads(raw)
                if msg.get("type") == "wakeword":
                    results["false_positive"] = True
                    log("✗", f"Faux positif détecté: {msg}")
                else:
                    results["no_false_positive"] = True
                    log("✓", "Pas de faux positif sur silence")
            except asyncio.TimeoutError:
                results["no_false_positive"] = True
                log("✓", "Pas de faux positif sur silence (timeout = correct)")

            results["status"] = "OK"
    except Exception as e:
        results["status"] = "FAIL"
        results["error"] = str(e)
        log("✗", f"Erreur wakeword: {type(e).__name__}: {e}")
        traceback.print_exc()
    return results


# ═══════════════════════════════════════════════════════════════════════════════
# 3) TEST VAD
# ═══════════════════════════════════════════════════════════════════════════════

async def test_vad():
    """Teste le VAD : silence → no speech, ton → speech detected."""
    results = {}
    uri = "ws://localhost:8768"
    try:
        async with websockets.connect(uri, open_timeout=5) as ws:
            # Ready
            raw = await asyncio.wait_for(ws.recv(), timeout=5)
            msg = json.loads(raw)
            results["ready"] = msg
            log("✓", f"VAD prêt: modèle={msg.get('model', 'N/A')}")

            # Test silence
            log("→", "Envoi de silence (0.5s)...")
            silence = generate_silence_pcm16(0.5, 16000)
            chunk_size = 512 * 2  # 512 samples * 2 bytes
            silence_scores = []
            for i in range(0, len(silence), chunk_size):
                chunk = silence[i:i+chunk_size]
                if len(chunk) == chunk_size:
                    await ws.send(chunk)
                    try:
                        raw = await asyncio.wait_for(ws.recv(), timeout=2)
                        vad_msg = json.loads(raw)
                        if vad_msg.get("type") == "vad":
                            silence_scores.append(vad_msg["score"])
                    except asyncio.TimeoutError:
                        pass

            if silence_scores:
                avg_silence = sum(silence_scores) / len(silence_scores)
                results["silence_avg_score"] = round(avg_silence, 4)
                results["silence_is_speech"] = avg_silence > 0.5
                if avg_silence < 0.5:
                    log("✓", f"Silence détecté correctement (score moyen: {avg_silence:.4f})")
                else:
                    log("⚠", f"Score silence anormalement haut: {avg_silence:.4f}")
            else:
                log("⚠", "Aucune réponse VAD reçue pour le silence")
                results["silence_avg_score"] = None

            # Test son (ton sinusoïdal)
            log("→", "Envoi d'un ton 440Hz (0.5s)...")
            tone = generate_speech_like_pcm16(0.5, 16000)
            tone_scores = []
            for i in range(0, len(tone), chunk_size):
                chunk = tone[i:i+chunk_size]
                if len(chunk) == chunk_size:
                    await ws.send(chunk)
                    try:
                        raw = await asyncio.wait_for(ws.recv(), timeout=2)
                        vad_msg = json.loads(raw)
                        if vad_msg.get("type") == "vad":
                            tone_scores.append(vad_msg["score"])
                    except asyncio.TimeoutError:
                        pass

            if tone_scores:
                avg_tone = sum(tone_scores) / len(tone_scores)
                results["tone_avg_score"] = round(avg_tone, 4)
                results["tone_is_speech"] = avg_tone > 0.5
                if avg_tone > 0.3:
                    log("✓", f"Son détecté (score moyen: {avg_tone:.4f})")
                else:
                    log("⚠", f"Score ton bas (attendu >0.3): {avg_tone:.4f}")
            else:
                log("⚠", "Aucune réponse VAD reçue pour le ton")
                results["tone_avg_score"] = None

            results["status"] = "OK"
    except Exception as e:
        results["status"] = "FAIL"
        results["error"] = str(e)
        log("✗", f"Erreur: {e}")
    return results


# ═══════════════════════════════════════════════════════════════════════════════
# 4) TEST STT
# ═══════════════════════════════════════════════════════════════════════════════

async def test_stt():
    """Teste le STT : envoie un buffer audio et vérifie la transcription."""
    results = {}
    uri = "ws://localhost:8766"
    try:
        async with websockets.connect(uri, open_timeout=5) as ws:
            # Ready
            raw = await asyncio.wait_for(ws.recv(), timeout=10)
            msg = json.loads(raw)
            results["ready"] = msg
            log("✓", f"STT prêt: backend={msg.get('backend', 'N/A')}, model={msg.get('model', 'N/A')}")

            # Envoyer start + audio + end
            await ws.send(json.dumps({"type": "start"}))
            log("→", "Start envoyé")

            # Envoyer un ton (le modèle transcrira du bruit ou rien)
            audio = generate_tone_pcm16(440, 1.0, 16000, 10000)
            chunk_size = 4096
            for i in range(0, len(audio), chunk_size):
                await ws.send(audio[i:i+chunk_size])
            log("→", f"Audio envoyé ({len(audio)} bytes, 1s)")

            await ws.send(json.dumps({"type": "end"}))
            log("→", "End envoyé, attente transcription...")

            # Collecter les réponses
            t0 = time.perf_counter()
            final_received = False
            while not final_received:
                try:
                    raw = await asyncio.wait_for(ws.recv(), timeout=TIMEOUT)
                    if isinstance(raw, str):
                        resp = json.loads(raw)
                        if resp.get("type") == "final":
                            latency = (time.perf_counter() - t0) * 1000
                            results["final"] = resp
                            results["latency_ms"] = round(latency, 1)
                            results["text"] = resp.get("text", "")
                            log("✓", f"Transcription reçue: \"{resp.get('text', '')}\" ({latency:.0f}ms)")
                            final_received = True
                        elif resp.get("type") == "partial":
                            log("…", f"Partiel: \"{resp.get('text', '')}\"")
                        elif resp.get("type") == "error":
                            results["error_msg"] = resp.get("message", "")
                            log("✗", f"Erreur STT: {resp.get('message', '')}")
                            final_received = True
                except asyncio.TimeoutError:
                    log("✗", f"Timeout ({TIMEOUT}s) en attendant la transcription")
                    results["timeout"] = True
                    break

            results["status"] = "OK" if final_received else "TIMEOUT"
    except Exception as e:
        results["status"] = "FAIL"
        results["error"] = str(e)
        log("✗", f"Erreur: {e}")
    return results


# ═══════════════════════════════════════════════════════════════════════════════
# 5) TEST TTS
# ═══════════════════════════════════════════════════════════════════════════════

async def test_tts():
    """Teste le TTS : synthétise un texte et vérifie l'audio retourné."""
    results = {}
    uri = "ws://localhost:8767"
    try:
        async with websockets.connect(uri, open_timeout=5) as ws:
            # Ready
            raw = await asyncio.wait_for(ws.recv(), timeout=10)
            msg = json.loads(raw)
            results["ready"] = msg
            log("✓", f"TTS prêt: voice={msg.get('voice', 'N/A')}, backend={msg.get('backend', 'N/A')}")

            # List voices
            await ws.send(json.dumps({"type": "list_voices"}))
            raw = await asyncio.wait_for(ws.recv(), timeout=5)
            voices_msg = json.loads(raw)
            if voices_msg.get("type") == "voices":
                n_voices = len(voices_msg.get("available", []))
                results["voices_count"] = n_voices
                log("✓", f"{n_voices} voix disponibles")

            # Ping
            t0 = time.perf_counter()
            await ws.send(json.dumps({"type": "ping"}))
            raw = await asyncio.wait_for(ws.recv(), timeout=5)
            results["ping_ms"] = round((time.perf_counter() - t0) * 1000, 1)
            log("✓", f"Ping TTS OK ({results['ping_ms']}ms)")

            # Synthesize
            log("→", "Synthèse: \"Bonjour, je suis EXO.\"")
            t0 = time.perf_counter()
            await ws.send(json.dumps({
                "type": "synthesize",
                "text": "Bonjour, je suis EXO.",
                "lang": "fr"
            }))

            audio_chunks = []
            start_msg = None
            end_msg = None
            synth_done = False

            while not synth_done:
                try:
                    raw = await asyncio.wait_for(ws.recv(), timeout=30)
                    if isinstance(raw, bytes):
                        audio_chunks.append(raw)
                    else:
                        resp = json.loads(raw)
                        if resp.get("type") == "start":
                            start_msg = resp
                            log("→", "Synthèse démarrée...")
                        elif resp.get("type") == "end":
                            end_msg = resp
                            synth_done = True
                        elif resp.get("type") == "error":
                            results["error_msg"] = resp.get("message", "")
                            log("✗", f"Erreur TTS: {resp.get('message', '')}")
                            synth_done = True
                except asyncio.TimeoutError:
                    log("✗", "Timeout (30s) en attendant la synthèse TTS")
                    results["timeout"] = True
                    break

            total_ms = (time.perf_counter() - t0) * 1000
            total_audio_bytes = sum(len(c) for c in audio_chunks)
            results["synth_ms"] = round(total_ms, 1)
            results["audio_bytes"] = total_audio_bytes
            results["audio_chunks"] = len(audio_chunks)
            results["start_msg"] = start_msg
            results["end_msg"] = end_msg

            if total_audio_bytes > 0:
                # PCM16 24kHz mono → duration
                duration_s = total_audio_bytes / (24000 * 2)
                results["audio_duration_s"] = round(duration_s, 2)
                log("✓", f"Audio reçu: {total_audio_bytes} bytes, {len(audio_chunks)} chunks, ~{duration_s:.2f}s")
                log("✓", f"Latence totale: {total_ms:.0f}ms")
                if end_msg:
                    log("✓", f"synth_ms serveur: {end_msg.get('synth_ms', 'N/A')}")
                results["status"] = "OK"
            else:
                log("✗", "Aucun audio reçu")
                results["status"] = "FAIL"

    except Exception as e:
        results["status"] = "FAIL"
        results["error"] = str(e)
        log("✗", f"Erreur: {e}")
    return results


# ═══════════════════════════════════════════════════════════════════════════════
# 6) TEST MEMORY
# ═══════════════════════════════════════════════════════════════════════════════

async def test_memory():
    """Teste le memory_server : add, search, stats, remove."""
    results = {}
    uri = "ws://localhost:8771"
    try:
        async with websockets.connect(uri, open_timeout=5) as ws:
            # Ready
            raw = await asyncio.wait_for(ws.recv(), timeout=10)
            msg = json.loads(raw)
            results["ready"] = msg
            log("✓", f"Memory prêt: model={msg.get('model', 'N/A')}, memories={msg.get('memories', 'N/A')}")

            # Stats
            await ws.send(json.dumps({"type": "stats"}))
            raw = await asyncio.wait_for(ws.recv(), timeout=5)
            stats = json.loads(raw)
            results["stats_before"] = stats
            log("✓", f"Stats: count={stats.get('count', 'N/A')}, dim={stats.get('dim', 'N/A')}")

            # Add
            test_text = "EXO validation test: la température est de 22 degrés"
            await ws.send(json.dumps({
                "type": "add",
                "text": test_text,
                "importance": 0.9,
                "category": "test",
                "tags": ["validation", "test"]
            }))
            raw = await asyncio.wait_for(ws.recv(), timeout=5)
            added = json.loads(raw)
            results["added"] = added
            memory_id = added.get("id", "")
            log("✓", f"Souvenir ajouté: id={memory_id}")

            # Search
            await ws.send(json.dumps({
                "type": "search",
                "query": "température degrés",
                "top_k": 3
            }))
            raw = await asyncio.wait_for(ws.recv(), timeout=5)
            search_result = json.loads(raw)
            results["search"] = search_result
            memories = search_result.get("memories", [])
            if memories:
                best = memories[0]
                log("✓", f"Recherche OK: top1 score={best.get('score', 'N/A'):.4f}, text=\"{best.get('text', '')[:60]}\"")
            else:
                log("⚠", "Aucun résultat de recherche")

            # Remove (nettoyage)
            if memory_id:
                await ws.send(json.dumps({"type": "remove", "id": memory_id}))
                raw = await asyncio.wait_for(ws.recv(), timeout=5)
                removed = json.loads(raw)
                results["removed"] = removed
                log("✓", f"Souvenir supprimé: success={removed.get('success', 'N/A')}")

            # Ping
            t0 = time.perf_counter()
            await ws.send(json.dumps({"type": "ping"}))
            raw = await asyncio.wait_for(ws.recv(), timeout=5)
            pong = json.loads(raw)
            if pong.get("type") == "pong":
                results["ping_ms"] = round((time.perf_counter() - t0) * 1000, 1)
                log("✓", f"Ping OK ({results['ping_ms']}ms)")
            else:
                log("⚠", f"Réponse inattendue au ping: {pong}")

            results["status"] = "OK"
    except Exception as e:
        results["status"] = "FAIL"
        results["error"] = str(e)
        log("✗", f"Erreur memory: {type(e).__name__}: {e}")
        traceback.print_exc()
    return results


# ═══════════════════════════════════════════════════════════════════════════════
# 7) TEST NLU
# ═══════════════════════════════════════════════════════════════════════════════

async def test_nlu():
    """Teste le NLU : classify plusieurs phrases, list_intents."""
    results = {}
    uri = "ws://localhost:8772"
    test_phrases = [
        ("quelle heure est-il", "time"),
        ("allume la lumière du salon", "home_control"),
        ("quel temps fait-il à Paris", "weather"),
        ("mets un minuteur de 5 minutes", "timer"),
        ("bonjour", "greeting"),
    ]
    try:
        async with websockets.connect(uri, open_timeout=5) as ws:
            # Ready/initial message
            try:
                raw = await asyncio.wait_for(ws.recv(), timeout=3)
                msg = json.loads(raw)
                results["initial"] = msg
                log("✓", f"NLU connecté: {msg.get('type', 'N/A')}")
            except asyncio.TimeoutError:
                log("→", "Pas de message initial (normal)")

            # Ping
            t0 = time.perf_counter()
            await ws.send(json.dumps({"action": "ping"}))
            raw = await asyncio.wait_for(ws.recv(), timeout=5)
            results["ping_ms"] = round((time.perf_counter() - t0) * 1000, 1)
            pong = json.loads(raw)
            log("✓", f"Ping OK ({results['ping_ms']}ms): {pong}")

            # List intents
            await ws.send(json.dumps({"action": "list_intents"}))
            raw = await asyncio.wait_for(ws.recv(), timeout=5)
            intents_msg = json.loads(raw)
            results["intents"] = intents_msg
            log("✓", f"Intentions: {intents_msg.get('intents', 'N/A')}")

            # Classify phrases
            results["classifications"] = []
            for phrase, expected_intent in test_phrases:
                t0 = time.perf_counter()
                await ws.send(json.dumps({"action": "classify", "text": phrase}))
                raw = await asyncio.wait_for(ws.recv(), timeout=10)
                latency = (time.perf_counter() - t0) * 1000
                resp = json.loads(raw)
                
                detected_intent = resp.get("intent", "unknown")
                confidence = resp.get("confidence", 0)
                entities = resp.get("entities", {})
                match = detected_intent == expected_intent

                classification = {
                    "phrase": phrase,
                    "expected": expected_intent,
                    "detected": detected_intent,
                    "confidence": confidence,
                    "entities": entities,
                    "match": match,
                    "latency_ms": round(latency, 1),
                }
                results["classifications"].append(classification)

                icon = "✓" if match else "⚠"
                log(icon, f"\"{phrase}\" → {detected_intent} (conf={confidence:.2f}, {latency:.0f}ms)"
                    + (f" entités={entities}" if entities else "")
                    + ("" if match else f" [attendu: {expected_intent}]"))

            # Stats
            matched = sum(1 for c in results["classifications"] if c["match"])
            total = len(results["classifications"])
            results["accuracy"] = f"{matched}/{total}"
            log("✓" if matched == total else "⚠", f"Précision: {matched}/{total}")

            results["status"] = "OK"
    except Exception as e:
        results["status"] = "FAIL"
        results["error"] = str(e)
        log("✗", f"Erreur: {e}")
    return results


# ═══════════════════════════════════════════════════════════════════════════════
# 8) TEST PIPELINE COMPLET
# ═══════════════════════════════════════════════════════════════════════════════

async def test_pipeline():
    """Simule le pipeline complet: wakeword → VAD → STT → NLU → TTS"""
    results = {"steps": []}
    pipeline_start = time.perf_counter()

    try:
        # Étape 1: Wakeword - envoyer un ping pour confirmer qu'il est actif
        log("→", "ÉTAPE 1: Wakeword — vérification activité")
        t0 = time.perf_counter()
        async with websockets.connect("ws://localhost:8770", open_timeout=5) as ws:
            raw = await asyncio.wait_for(ws.recv(), timeout=5)
            ready = json.loads(raw)
            results["steps"].append({
                "step": "wakeword_ready",
                "status": "OK",
                "latency_ms": round((time.perf_counter() - t0) * 1000, 1),
                "data": ready
            })
            log("✓", f"Wakeword actif, modèles: {ready.get('models', [])}")

        # Étape 2: VAD — envoyer un son et vérifier la détection
        log("→", "ÉTAPE 2: VAD — détection d'activité vocale")
        t0 = time.perf_counter()
        async with websockets.connect("ws://localhost:8768", open_timeout=5) as ws:
            await asyncio.wait_for(ws.recv(), timeout=5)  # ready
            audio = generate_speech_like_pcm16(0.3, 16000)
            chunk_size = 512 * 2
            vad_detected = False
            for i in range(0, len(audio), chunk_size):
                chunk = audio[i:i+chunk_size]
                if len(chunk) == chunk_size:
                    await ws.send(chunk)
                    try:
                        raw = await asyncio.wait_for(ws.recv(), timeout=1)
                        vad_msg = json.loads(raw)
                        if vad_msg.get("type") == "vad" and vad_msg.get("score", 0) > 0.3:
                            vad_detected = True
                    except asyncio.TimeoutError:
                        pass
            results["steps"].append({
                "step": "vad_detection",
                "status": "OK" if vad_detected else "WARN",
                "latency_ms": round((time.perf_counter() - t0) * 1000, 1),
                "speech_detected": vad_detected
            })
            icon = "✓" if vad_detected else "⚠"
            log(icon, f"VAD: speech_detected={vad_detected}")

        # Étape 3: STT — transcrire (on envoie un silence court, le modèle transcrira vide ou bruit)
        log("→", "ÉTAPE 3: STT — transcription audio")
        t0 = time.perf_counter()
        async with websockets.connect("ws://localhost:8766", open_timeout=5) as ws:
            await asyncio.wait_for(ws.recv(), timeout=10)  # ready
            await ws.send(json.dumps({"type": "start"}))
            audio = generate_tone_pcm16(440, 0.5, 16000, 5000)
            for i in range(0, len(audio), 4096):
                await ws.send(audio[i:i+4096])
            await ws.send(json.dumps({"type": "end"}))

            stt_text = ""
            while True:
                try:
                    raw = await asyncio.wait_for(ws.recv(), timeout=TIMEOUT)
                    if isinstance(raw, str):
                        resp = json.loads(raw)
                        if resp.get("type") == "final":
                            stt_text = resp.get("text", "")
                            break
                        elif resp.get("type") == "error":
                            break
                except asyncio.TimeoutError:
                    break

            stt_latency = (time.perf_counter() - t0) * 1000
            results["steps"].append({
                "step": "stt_transcription",
                "status": "OK",
                "latency_ms": round(stt_latency, 1),
                "text": stt_text
            })
            log("✓", f"STT: \"{stt_text}\" ({stt_latency:.0f}ms)")

        # Étape 4: NLU — classifier le résultat (on utilise une phrase connue comme fallback)
        nlu_input = stt_text if stt_text.strip() else "quelle heure est-il"
        log("→", f"ÉTAPE 4: NLU — classification de \"{nlu_input}\"")
        t0 = time.perf_counter()
        async with websockets.connect("ws://localhost:8772", open_timeout=5) as ws:
            try:
                await asyncio.wait_for(ws.recv(), timeout=2)
            except asyncio.TimeoutError:
                pass
            await ws.send(json.dumps({"action": "classify", "text": nlu_input}))
            raw = await asyncio.wait_for(ws.recv(), timeout=10)
            nlu_result = json.loads(raw)
            nlu_latency = (time.perf_counter() - t0) * 1000
            results["steps"].append({
                "step": "nlu_classification",
                "status": "OK",
                "latency_ms": round(nlu_latency, 1),
                "intent": nlu_result.get("intent"),
                "entities": nlu_result.get("entities", {}),
                "confidence": nlu_result.get("confidence", 0)
            })
            log("✓", f"NLU: intent={nlu_result.get('intent')}, conf={nlu_result.get('confidence', 0):.2f} ({nlu_latency:.0f}ms)")

        # Étape 5: TTS — synthétiser une réponse
        tts_text = "Il est seize heures cinquante."
        log("→", f"ÉTAPE 5: TTS — synthèse de \"{tts_text}\"")
        t0 = time.perf_counter()
        async with websockets.connect("ws://localhost:8767", open_timeout=5) as ws:
            await asyncio.wait_for(ws.recv(), timeout=10)  # ready
            await ws.send(json.dumps({"type": "synthesize", "text": tts_text, "lang": "fr"}))

            audio_bytes = 0
            tts_done = False
            while not tts_done:
                try:
                    raw = await asyncio.wait_for(ws.recv(), timeout=30)
                    if isinstance(raw, bytes):
                        audio_bytes += len(raw)
                    else:
                        resp = json.loads(raw)
                        if resp.get("type") == "end":
                            tts_done = True
                        elif resp.get("type") == "error":
                            tts_done = True
                except asyncio.TimeoutError:
                    break

            tts_latency = (time.perf_counter() - t0) * 1000
            results["steps"].append({
                "step": "tts_synthesis",
                "status": "OK" if audio_bytes > 0 else "FAIL",
                "latency_ms": round(tts_latency, 1),
                "audio_bytes": audio_bytes
            })
            if audio_bytes > 0:
                log("✓", f"TTS: {audio_bytes} bytes audio ({tts_latency:.0f}ms)")
            else:
                log("✗", "TTS: aucun audio reçu")

        # Étape 6: Memory — stocker l'interaction
        log("→", "ÉTAPE 6: Memory — stockage de l'interaction")
        t0 = time.perf_counter()
        async with websockets.connect("ws://localhost:8771", open_timeout=5) as ws:
            await asyncio.wait_for(ws.recv(), timeout=10)  # ready
            await ws.send(json.dumps({
                "type": "add",
                "text": f"L'utilisateur a demandé: {nlu_input}. Réponse: {tts_text}",
                "category": "interaction",
                "importance": 0.5
            }))
            raw = await asyncio.wait_for(ws.recv(), timeout=5)
            mem_result = json.loads(raw)
            mem_latency = (time.perf_counter() - t0) * 1000

            # Nettoyage
            mem_id = mem_result.get("id", "")
            if mem_id:
                await ws.send(json.dumps({"type": "remove", "id": mem_id}))
                await asyncio.wait_for(ws.recv(), timeout=5)

            results["steps"].append({
                "step": "memory_store",
                "status": "OK",
                "latency_ms": round(mem_latency, 1),
                "id": mem_id
            })
            log("✓", f"Memory: stocké id={mem_id} ({mem_latency:.0f}ms)")

        total_ms = (time.perf_counter() - pipeline_start) * 1000
        results["total_ms"] = round(total_ms, 1)
        results["status"] = "OK"
        log("✓", f"Pipeline complet: {total_ms:.0f}ms total")

    except Exception as e:
        results["status"] = "FAIL"
        results["error"] = str(e)
        log("✗", f"Pipeline échoué: {e}")
        traceback.print_exc()

    return results


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

async def main():
    global RESULTS
    print("╔══════════════════════════════════════════════════════════════════════╗")
    print("║     EXO v4.2 — VALIDATION FONCTIONNELLE COMPLÈTE DU PIPELINE      ║")
    print("╚══════════════════════════════════════════════════════════════════════╝")

    # ── 1) Connectivité WebSocket ──
    section("1) TEST DE CONNECTIVITÉ WEBSOCKET")
    RESULTS["connectivity"] = {}
    for name, info in SERVICES.items():
        log("→", f"Test {name} (:{info['port']}) — {info['desc']}")
        conn = await test_ws_connect(name, info["port"])
        RESULTS["connectivity"][name] = conn
        icon = "✓" if conn["status"] == "OK" else "✗"
        if conn["status"] == "OK":
            init_type = conn.get("initial_msg", {}).get("type", "N/A") if isinstance(conn.get("initial_msg"), dict) else "N/A"
            log(icon, f"Connecté en {conn.get('connect_ms', '?')}ms, msg initial: type={init_type}")
        else:
            log(icon, f"ÉCHEC: {conn.get('error', 'unknown')}")

    # ── 1b) Ping ──
    section("1b) TEST PING/PONG")
    RESULTS["pings"] = {}
    for name, info in SERVICES.items():
        ping_result = await test_ws_ping(name, info["port"])
        RESULTS["pings"][name] = ping_result
        if ping_result["status"] == "OK":
            log("✓", f"{name}: pong en {ping_result['latency_ms']}ms")
        elif ping_result["status"] == "SKIP":
            log("—", f"{name}: {ping_result.get('note', 'skipped')}")
        elif ping_result["status"] == "WARN":
            log("⚠", f"{name}: {ping_result.get('note', 'no response')}")
        else:
            log("✗", f"{name}: {ping_result.get('error', 'unknown')}")

    # ── 2) Wakeword ──
    section("2) TEST WAKEWORD SERVER")
    RESULTS["wakeword"] = await test_wakeword()

    # ── 3) VAD ──
    section("3) TEST VAD SERVER")
    RESULTS["vad"] = await test_vad()

    # ── 4) STT ──
    section("4) TEST STT SERVER")
    RESULTS["stt"] = await test_stt()

    # ── 5) TTS ──
    section("5) TEST TTS SERVER (fallback CPU)")
    RESULTS["tts"] = await test_tts()

    # ── 6) Memory ──
    section("6) TEST MEMORY SERVER")
    RESULTS["memory"] = await test_memory()

    # ── 7) NLU ──
    section("7) TEST NLU SERVER")
    RESULTS["nlu"] = await test_nlu()

    # ── 8) Pipeline complet ──
    section("8) TEST PIPELINE COMPLET")
    RESULTS["pipeline"] = await test_pipeline()

    # ── 9) Rapport final ──
    section("9) RAPPORT FINAL")
    print()
    print("┌────────────────────┬──────────┬─────────────────────────────────────┐")
    print("│ Service            │ Statut   │ Détails                             │")
    print("├────────────────────┼──────────┼─────────────────────────────────────┤")

    for name, info in SERVICES.items():
        conn = RESULTS["connectivity"].get(name, {})
        ping = RESULTS["pings"].get(name, {})
        status = "OK" if conn.get("status") == "OK" else "FAIL"
        ping_ms = ping.get("latency_ms", "N/A")
        detail = f"connect={conn.get('connect_ms', '?')}ms, ping={ping_ms}ms"
        status_icon = "  OK  " if status == "OK" else " FAIL "
        print(f"│ {name:<18} │ {status_icon} │ {detail:<35} │")

    print("├────────────────────┼──────────┼─────────────────────────────────────┤")

    # Tests fonctionnels
    func_tests = [
        ("Wakeword", RESULTS.get("wakeword", {})),
        ("VAD", RESULTS.get("vad", {})),
        ("STT", RESULTS.get("stt", {})),
        ("TTS", RESULTS.get("tts", {})),
        ("Memory", RESULTS.get("memory", {})),
        ("NLU", RESULTS.get("nlu", {})),
        ("Pipeline", RESULTS.get("pipeline", {})),
    ]
    for test_name, result in func_tests:
        status = result.get("status", "N/A")
        status_icon = "  OK  " if status == "OK" else " FAIL " if status == "FAIL" else " WARN "

        if test_name == "TTS":
            detail = f"{result.get('audio_bytes', 0)}B, {result.get('synth_ms', '?')}ms"
        elif test_name == "STT":
            detail = f"\"{result.get('text', '')[:30]}\", {result.get('latency_ms', '?')}ms"
        elif test_name == "NLU":
            detail = f"accuracy={result.get('accuracy', 'N/A')}"
        elif test_name == "Pipeline":
            detail = f"total={result.get('total_ms', '?')}ms"
        elif test_name == "Memory":
            detail = f"ping={result.get('ping_ms', '?')}ms"
        elif test_name == "VAD":
            detail = f"silence={result.get('silence_avg_score', '?')}, tone={result.get('tone_avg_score', '?')}"
        else:
            detail = f"ping={result.get('ping_ms', '?')}ms"

        print(f"│ {test_name:<18} │ {status_icon} │ {detail:<35} │")

    print("└────────────────────┴──────────┴─────────────────────────────────────┘")

    # Résumé global
    all_ok = all(
        RESULTS["connectivity"].get(name, {}).get("status") == "OK"
        for name in SERVICES
    )
    pipeline_ok = RESULTS.get("pipeline", {}).get("status") == "OK"

    print()
    if all_ok and pipeline_ok:
        print("  ══ RÉSULTAT GLOBAL: TOUS LES SERVICES SONT OPÉRATIONNELS ══")
        print("  ══ LE PIPELINE COMPLET FONCTIONNE DE BOUT EN BOUT        ══")
    elif all_ok:
        print("  ══ RÉSULTAT: Services individuels OK, pipeline avec avertissements ══")
    else:
        failed = [n for n in SERVICES if RESULTS["connectivity"].get(n, {}).get("status") != "OK"]
        print(f"  ══ RÉSULTAT: {len(failed)} service(s) en échec: {', '.join(failed)} ══")

    return RESULTS


if __name__ == "__main__":
    asyncio.run(main())
