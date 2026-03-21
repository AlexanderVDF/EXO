# EXO_SPEC_V4.2.md — Spécification Officielle (Source de Vérité)

## 1. Objectif
EXO v4.2 est un assistant vocal local, temps réel, modulaire, basé sur :
- un moteur C++/Qt 6.9.3
- un pipeline audio temps réel
- des serveurs IA Python spécialisés
- une interface QML style VS Code
- une intégration Home Assistant complète
- une architecture micro‑services via WebSocket
 
EXO doit être stable, déterministe et cohérent.

---

## 2. Architecture générale

Audio → VoicePipeline (C++) → STT → NLU → LLM → TTS → DSP → AudioOut

### 2.1 C++ (moteur)
- VoicePipeline : capture micro, DSP entrée, VAD, wakeword, STT streaming, FSM
- TTSManager : cascade XTTS v2 → Qt TTS
- ClaudeAPI : SSE + Function Calling
- AIMemoryManager : mémoire 3 couches + FAISS
- WeatherManager : météo + géoloc
- AssistantManager : orchestrateur global
- ConfigManager : configuration 3 couches
- LogManager : logs catégorisés

### 2.2 Serveurs Python (WebSocket)
- stt_server.py : Whisper.cpp Vulkan GPU
- tts_server.py : XTTS v2
- vad_server.py : Silero VAD
- wakeword_server.py : OpenWakeWord
- memory_server.py : FAISS vectoriel
- nlu_server.py : NLU local
- exo_server.py : GUI + Home Assistant

### 2.3 Interface QML
- MainWindow.qml
- 9 composants VS Code : Sidebar, Transcript, Response, Visualizer, SettingsPanel, etc.

---

## 3. Pipeline audio

### 3.1 Capture
- Backend : QAudioSource
- Format : 16 kHz, mono, Int16
- Buffer : circulaire borné

### 3.2 DSP entrée
- High‑pass 150 Hz
- Noise gate
- AGC
- Normalisation RMS

### 3.3 VAD
- Backend : Silero VAD via WebSocket
- Modes : builtin | silero | hybrid
- Seuil configurable

### 3.4 WakeWord
- Backend principal : OpenWakeWord
- Fallback : transcript Whisper
- Wakewords : EXO, EXO!, EXO?
- Phonétique : ɛɡ.zɔ, ɛk.so

### 3.5 STT
- Backend unique : Whisper.cpp Vulkan GPU
- Modèle : ggml-large-v3.bin (recommandé), fallback ggml-small.bin
- Chemin modèles : D:\EXO\models\whisper\
- Protocole : start → PCM → partial → final

### 3.6 NLU
- Backend : nlu_server.py
- Rôle : classification d’intentions simples
- Fallback : ClaudeAPI

### 3.7 LLM
- Backend : Claude Sonnet 4
- Mode : SSE streaming
- Function Calling : 8 outils Home Assistant

### 3.8 TTS
- Backend principal : XTTS v2 (DirectML / CUDA natif Windows)
- Voix : Claribel Dervla (58 voix disponibles)
- Paramètres : voice, pitch, rate, style, langue
- Chemin modèles : D:\EXO\models\xtts\
- Fallback : Qt TextToSpeech

### 3.9 DSP sortie
- EQ 3 kHz +3 dB
- Compresseur -12 dBFS
- Normalisation -16 dBFS
- Fade 15–20 ms
- Anti‑clip

### 3.10 Sortie audio
- Backend : QAudioSink
- Format : 16 kHz mono Int16

---

## 4. Serveurs Python (spécification)

### 4.1 stt_server.py
- Backend : Whisper.cpp Vulkan
- Protocole : start, PCM16, partial, final
- Fallback CPU : faster-whisper small/int8

### 4.2 tts_server.py
- Backend : XTTS v2
- Paramètres : voice, lang, pitch, rate, style
- Streaming PCM16

### 4.3 vad_server.py
- Backend : Silero VAD
- Retour : score ∈ [0,1], is_speech

### 4.4 wakeword_server.py
- Backend : OpenWakeWord
- Retour : word, score

### 4.5 memory_server.py
- Backend : FAISS + SentenceTransformers
- Opérations : add, search

### 4.6 nlu_server.py
- Backend : regex + transformers
- Intents : météo, heure, domotique, musique, etc.

### 4.7 exo_server.py
- WebSocket GUI
- Bridge Home Assistant
- Sync entités/appareils/pièces

---

## 5. Interface QML

### 5.1 Composants obligatoires
- MainWindow.qml
- Sidebar.qml
- StatusIndicator.qml
- MicrophoneLevel.qml
- TranscriptView.qml
- ResponseView.qml
- Visualizer.qml (ShaderEffect)
- BottomBar.qml
- SettingsPanel.qml
- HistoryPanel.qml

### 5.2 Visualizer
- ShaderEffect GPU
- 60 FPS
- Couleur #007ACC
- Amplitude = RMS

### 5.3 SettingsPanel
Doit exposer :
- Voix XTTS
- Langue TTS
- Pitch / Rate / Style
- Wakewords multiples
- Sensibilité wakeword
- Backend VAD
- Seuil VAD
- Gain micro
- AGC
- Noise gate
- Langue STT
- Backend STT
- Mémoire sémantique
- NLU local

---

## 6. Configuration (source de vérité)

### 6.1 Fichiers de configuration
- `.env` : secrets (CLAUDE_API_KEY, OWM_API_KEY, HA_URL, HA_TOKEN)
- `config/assistant.conf` : paramètres par défaut (lecture seule)
- `%APPDATA%\EXOAssistant\user_config.ini` : préférences utilisateur (prioritaire)

### 6.2 Chemins de données (SSD D:\EXO\)
- STT : `D:\EXO\models\whisper\`
- TTS : `D:\EXO\models\xtts\`
- WakeWord : `D:\EXO\models\wakeword\`
- FAISS : `D:\EXO\faiss\`
- Logs : `D:\EXO\logs\`
- Whisper.cpp : `D:\EXO\whispercpp\`
- Cache HF : `D:\EXO\cache\huggingface\`

> Ancien chemin `J:\EXO\` obsolète — migré vers `D:\EXO\`.

### 6.3 Variables d'environnement (tasks.json / launch_exo.ps1)
- `EXO_WHISPER_MODELS` = `D:\EXO\models\whisper`
- `EXO_WHISPERCPP_BIN` = `D:\EXO\whispercpp\build_vk\bin\Release`
- `EXO_XTTS_MODELS` = `D:\EXO\models\xtts`
- `EXO_FAISS_DIR` = `D:\EXO\faiss\semantic_memory`
- `EXO_WAKEWORD_MODELS` = `D:\EXO\models\wakeword`
- `HF_HOME` = `D:\EXO\cache\huggingface`
- `TRANSFORMERS_CACHE` = `D:\EXO\cache\huggingface\hub`