> 🧭 [Index](../README.md) → [Guides](../README.md#-guides-techniques--guides) → audio_pipeline.md

# Pipeline Audio EXO v4.2
> Documentation EXO v4.2 — Section : Guides
> Dernière mise à jour : Mars 2026

---

<!-- TOC -->
## Table des matières

- [Flux complet](#flux-complet)
- [Machine à états (VoicePipeline)](#machine-à-états-voicepipeline)
- [Formats audio](#formats-audio)
- [Latences typiques](#latences-typiques)

<!-- /TOC -->

## Flux complet

```
Microphone
    │
    ▼
┌────────────────────────────────────────────────┐
│ CAPTURE AUDIO                                   │
│ Backend: QAudioSource (Qt) ou RtAudio (WASAPI) │
│ Format: 16 kHz, mono, PCM16 (Int16 LE)        │
│ Buffer: CircularAudioBuffer (32s = 1 024 000    │
│         samples)                                │
└────────────────────┬───────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────┐
│ PRÉTRAITEMENT DSP (AudioPreprocessor)           │
│                                                 │
│ 1. High-pass Butterworth 2nd ordre, fc=150 Hz  │
│    → Élimine bruit basse fréquence, rumble     │
│                                                 │
│ 2. Noise Gate                                   │
│    → RMS < seuil (configurable) → silence       │
│    → Élimine bruit de fond résiduel            │
│                                                 │
│ 3. AGC (Automatic Gain Control)                 │
│    → Maintient niveau constant                  │
│    → Compensation dynamique                     │
│                                                 │
│ 4. Normalisation RMS                            │
│    → Cible configurable                         │
│    → Uniformise le niveau d'entrée             │
└────────────────────┬───────────────────────────┘
                     │
              ┌──────┴──────┐
              ▼             ▼
┌──────────────────┐ ┌──────────────────────┐
│ WAKE WORD        │ │ VAD                   │
│ Port 8770        │ │ Port 8768             │
│ OpenWakeWord     │ │ Silero VAD            │
│ Chunks: 1280     │ │ Chunks: 512 samples   │
│ samples (80ms)   │ │ (32ms)                │
│ Modèle:          │ │ Score: 0.0 → 1.0     │
│ hey_jarvis.onnx  │ │ Seuil: 0.45          │
│ Cooldown: 3s     │ │                       │
└────────┬─────────┘ └────────┬──────────────┘
         │                    │
         │ [wakeword détecté] │ [is_speech=true]
         └────────┬───────────┘
                  │
                  ▼
┌────────────────────────────────────────────────┐
│ STT (Speech-to-Text)                            │
│ Port 8766 — Whisper.cpp Vulkan GPU             │
│                                                 │
│ Protocole:                                      │
│   C++ → {"type":"start"} → audio binaire PCM16 │
│       → {"type":"end"}                          │
│   Py  → {"type":"partial","text":"..."}         │
│       → {"type":"final","text":"..."}           │
│                                                 │
│ Modèle: ggml-large-v3 (Vulkan)                 │
│ Beam search: 5                                  │
│ Langue: fr                                      │
│ Filtre hallucination: oui                       │
└────────────────────┬───────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────┐
│ NLU (Natural Language Understanding)            │
│ Port 8772 — Classifieur regex                  │
│                                                 │
│ Entrée: {"action":"classify","text":"..."}     │
│ Sortie: {intent, entities, confidence}          │
│                                                 │
│ Intents: weather, time, timer, home_control,   │
│          music, reminder, greeting, goodbye     │
│                                                 │
│ Si confiance > 0.7 → Action locale (HA)        │
│ Si confiance < 0.7 → Route vers Claude LLM    │
└──────────┬──────────────────┬──────────────────┘
           │                  │
           ▼                  ▼
┌─────────────────┐ ┌────────────────────────────┐
│ ACTION LOCALE   │ │ CLAUDE LLM                  │
│ (HA direct)     │ │ claude-sonnet-4-20250514 │
│                 │ │ SSE streaming               │
│                 │ │ Function calling (13 outils)│
│                 │ │ Max tokens: 4096            │
└────────┬────────┘ └────────────┬───────────────┘
         │                       │
         └───────────┬───────────┘
                     │
                     ▼
┌────────────────────────────────────────────────┐
│ TTS (Text-to-Speech)                            │
│ Port 8767 — XTTS v2 (DirectML / CUDA / CPU)      │
│                                                 │
│ Protocole:                                      │
│   C++ → {"type":"synthesize","text":"..."}     │
│   Py  → {"type":"start"} → binaire PCM16 24kHz│
│       → {"type":"end"}                          │
│                                                 │
│ Voix: Claribel Dervla                           │
│ Langue: fr (17 langues supportées)             │
│ Cache: LRU pour phrases courtes                 │
│ Fallback: TTSBackendQt (local)                  │
└────────────────────┬───────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────┐
│ DSP TTS (5 étages)                              │
│                                                 │
│ 1. Equalizer — présence +3dB @ 3kHz            │
│ 2. Compressor — seuil -12 dBFS, soft knee      │
│ 3. Normalizer — cible -16 dBFS                 │
│ 4. Fade — enveloppe 15-20 ms (anti-click)      │
│ 5. Anti-clip — peak limiter                     │
└────────────────────┬───────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────┐
│ SORTIE AUDIO                                    │
│ QAudioSink — 16 kHz mono PCM16                 │
│ Périphérique: défaut système                   │
└────────────────────┬───────────────────────────┘
                     │
                     ▼
                 Haut-parleur
                     │
                     └──→ Retour à VAD (boucle)
```

## Machine à états (VoicePipeline)

```
          ┌──────────────────────────────────────┐
          │                                      │
          ▼                                      │
    ┌──────────┐  wake word    ┌────────────┐   │
    │   IDLE   │──────────────▶│ DETECTING  │   │
    │          │◀──────────────│  SPEECH    │   │
    └──────────┘  timeout      └─────┬──────┘   │
                                     │          │
                               VAD speech       │
                                     │          │
                                     ▼          │
                               ┌──────────┐     │
                               │LISTENING │     │
                               │          │     │
                               └─────┬────┘     │
                                     │          │
                               silence          │
                                     │          │
                                     ▼          │
                            ┌──────────────┐    │
                            │ TRANSCRIBING │    │
                            │              │    │
                            └──────┬───────┘    │
                                   │            │
                             transcript         │
                                   │            │
                                   ▼            │
                            ┌──────────┐        │
                            │ THINKING │        │
                            │  (LLM)   │        │
                            └────┬─────┘        │
                                 │              │
                           response             │
                                 │              │
                                 ▼              │
                            ┌──────────┐        │
                            │ SPEAKING │        │
                            │  (TTS)   │────────┘
                            └──────────┘
                             TTS terminé
```

## Formats audio

| Étape | Sample Rate | Format | Channels | Chunk Size |
|-------|-------------|--------|----------|------------|
| Capture | 16 kHz | PCM16 LE | Mono | Variable |
| VAD | 16 kHz | PCM16 LE | Mono | 512 samples (32 ms) |
| WakeWord | 16 kHz | PCM16 LE | Mono | 1280 samples (80 ms) |
| STT | 16 kHz | PCM16 LE | Mono | Accumulé |
| TTS sortie | 24 kHz | PCM16 LE | Mono | Streamé |
| Playback | 16 kHz | PCM16 LE | Mono | Rééchantillonné |

## Latences typiques

| Composant | Latence attendue |
|-----------|-----------------|
| VAD (chunk) | < 5 ms |
| WakeWord (chunk) | < 10 ms |
| STT (utterance complète) | 500 ms – 2 s |
| NLU (classification) | < 50 ms |
| Claude (premier token) | 200 ms – 1 s |
| Claude (réponse complète) | 1 s – 5 s |
| TTS (premier chunk) | 200 ms – 500 ms |
| TTS DSP (chunk) | < 1 ms |

---
*Retour à l'index : [docs/README.md](../README.md)*
