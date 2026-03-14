# 🤖 EXO — Assistant Personnel Intelligent

**Version 3.0** | C++ / Qt 6.9.3 | Python / Home Assistant | React / TailwindCSS

![Qt 6.9.3](https://img.shields.io/badge/Qt-6.9.3-green?logo=qt)
![C++17](https://img.shields.io/badge/C++-17-blue?logo=cplusplus)
![Python 3.13](https://img.shields.io/badge/Python-3.13-yellow?logo=python)
![React 18](https://img.shields.io/badge/React-18-61dafb?logo=react)
![Claude API](https://img.shields.io/badge/Claude-Haiku-blue?logo=anthropic)
![Home Assistant](https://img.shields.io/badge/Home%20Assistant-Integration-41bdf5?logo=homeassistant)
![Windows 11](https://img.shields.io/badge/Windows-11-0078D4?logo=windows)

---

## Présentation

EXO est un assistant personnel multitechnologie combinant :

- **Moteur C++ / Qt** — reconnaissance vocale (Porcupine), synthèse TTS, Claude API, météo, mémoire persistante
- **Backend Python** — pont WebSocket/REST vers Home Assistant (entités, appareils, pièces, 13 actions LLM)
- **GUI React** — interface web moderne (Plans 2D/3D, carte réseau, appareils, paramètres)
- **Interface QML** — interface Material Design radiale intégrée

---

## Démarrage rapide

### Prérequis

| Composant | Version | Usage |
|-----------|---------|-------|
| Windows 11 | — | Plateforme |
| Qt | 6.9.3 MSVC 2022 x64 | C++ / QML |
| CMake | 3.21+ | Build system |
| Visual Studio Build Tools | 2022 | Compilateur |
| Python | 3.13+ | Backend HA |
| Node.js | 22+ | GUI React |

### 1. C++ — Compilation & lancement

```powershell
# Configurer
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH="C:\Qt\6.9.3\msvc2022_64"

# Compiler
cd build
cmake --build . --config Debug

# Lancer
cd Debug
.\RaspberryAssistant.exe
```

Ou via le script automatique :

```powershell
.\launch_exo.ps1
```

### 2. Python — Backend Home Assistant

```powershell
# Créer le .env depuis l'exemple
copy .env.example .env
# Remplir CLAUDE_API_KEY, OWM_API_KEY, HA_URL, HA_TOKEN

# Installer les dépendances
pip install -r requirements.txt

# Lancer le serveur (ws://localhost:8765)
python src/exo_server.py
```

### 3. React — Interface Web

```powershell
cd gui
npm install
npm run dev      # http://localhost:3000
npm run build    # Production dans gui/dist/
```

---

## Architecture

```
EXO/
├── src/                        # C++ — moteur principal
│   ├── main.cpp                # Point d'entrée (Windows console, Qt Material)
│   ├── assistantmanager.*      # Coordinateur central
│   ├── configmanager.*         # Config hybride (conf + AppData)
│   ├── claudeapi.*             # Client Anthropic (Haiku/Sonnet/Opus)
│   ├── voicemanager.*          # Audio 16kHz + Porcupine + TTS
│   ├── weathermanager.*        # OpenWeatherMap + géolocalisation
│   ├── aimemorymanager.*       # Mémoire JSON persistante
│   ├── porcupinewakeword_new.* # Chargement dynamique DLL Porcupine
│   ├── logmanager.*            # Catégories de log
│   ├── exo_server.py           # Serveur principal Python
│   └── integrations/           # Python — modules Home Assistant
│       ├── home_bridge.py      # WebSocket + REST + EventBus
│       ├── ha_entities.py      # Cache entités HA
│       ├── ha_devices.py       # Appareils (MAC/IP matching)
│       ├── ha_areas.py         # Pièces HA ↔ Plans
│       ├── ha_actions.py       # 13 actions LLM Function Calling
│       ├── ha_sync.py          # Sync Plans/Network ↔ HA
│       └── tests/              # 92 tests pytest
│
├── gui/                        # React 18 + Vite + TailwindCSS
│   └── src/
│       ├── components/         # Avatar, Card, Sidebar, TopBar, Waveform...
│       ├── screens/            # Home, Plans, NetworkMap, Devices, Settings
│       └── hooks/              # useWebSocket (auto-reconnect)
│
├── qml/                        # Interface QML Material Design
│   ├── main_radial.qml         # Menu radial principal
│   └── components/             # 12 composants (Chat, Config, Météo, Média...)
│
├── config/                     # Configuration
│   ├── assistant.conf          # Paramètres par défaut
│   └── assistant.conf.example  # Template
│
├── resources/                  # Polices, icônes, modèles Porcupine
├── scripts/                    # PowerShell (build, cleanup, tests, install)
├── include/porcupine/          # Headers Porcupine
├── lib/porcupine/              # DLL Porcupine
├── .env                        # Variables d'environnement (non versionné)
├── requirements.txt            # Dépendances Python
└── CMakeLists.txt              # Build CMake
```

---

## Configuration

### Variables d'environnement (`.env`)

```ini
CLAUDE_API_KEY=sk-ant-api03-...
OWM_API_KEY=...
HA_URL=http://localhost:8123
HA_TOKEN=votre-token-longue-duree
```

### Fichier `config/assistant.conf`

```ini
[Claude]
api_key=${CLAUDE_API_KEY}
model=claude-3-haiku-20240307

[OpenWeatherMap]
api_key=${OWM_API_KEY}
city=Paris

[Voice]
wake_word=EXO
language=fr-FR
```

Les préférences utilisateur sont stockées dans `%APPDATA%\EXOAssistant\user_config.ini` et prennent priorité sur `assistant.conf`.

---

## Utilisation

### Commandes vocales

1. Dites **"EXO"** → l'assistant répond "Oui ?"
2. Posez votre question → traitement Claude API
3. Réponse vocale + affichage dans l'interface

### Exemples

- "EXO, quel temps fait-il ?"
- "EXO, allume la lumière du salon"
- "EXO, raconte-moi une blague"

### Domotique (Home Assistant)

Via le backend Python, EXO peut contrôler vos appareils HA :
- Allumer / éteindre / basculer des entités
- Régler luminosité, couleur, température
- Contrôler les médias (play, pause, stop)
- Lister appareils, entités, pièces

---

## Tests

```powershell
# Tests Python (92 tests — Home Assistant integration)
python -m pytest src/integrations/tests/ -v

# Scripts de validation PowerShell
.\scripts\test_environment.ps1
.\scripts\verify_project.ps1
```

---

## Documentation complète

Consultez [EXO_DOCUMENTATION.md](EXO_DOCUMENTATION.md) pour :
- Architecture détaillée de chaque composant
- Protocole WebSocket GUI ↔ Backend
- Actions LLM Function Calling
- Système de mémoire et géolocalisation
- Dépannage et debug

---

## Roadmap

### Réalisé (v3.0)
- ✅ Assistant Claude API (Haiku / Sonnet / Opus)
- ✅ Reconnaissance vocale Porcupine + TTS français
- ✅ Météo intelligente avec géolocalisation IP
- ✅ Mémoire persistante JSON (100 conversations)
- ✅ Interface QML Material Design radiale
- ✅ GUI React moderne (Plans 2D/3D, réseau, appareils)
- ✅ Intégration Home Assistant complète (13 actions LLM)
- ✅ 92 tests unitaires Python
- ✅ Audit sécurité (12 correctifs appliqués)

### À venir
- 🔄 Whisper API — reconnaissance vocale complète
- 🔄 Google Calendar — agenda intelligent
- 🔄 Streaming musical — Spotify / Tidal
- 🔄 Déploiement Raspberry Pi 5
- 🔄 Interface mobile companion

---

## Licence

Ce projet est sous licence MIT.

---

**EXO — Assistant personnel intelligent** | Développé avec Qt 6.9.3, Python, React