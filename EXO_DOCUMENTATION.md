# EXO Assistant — Documentation Technique Complète

**Version 3.0** | Dernière mise à jour : Juillet 2025

---

## Table des matières

1. [Présentation](#-présentation)
2. [Installation](#-installation)
3. [Architecture générale](#-architecture-générale)
4. [Moteur C++ / Qt](#-moteur-c--qt)
5. [Backend Python / Home Assistant](#-backend-python--home-assistant)
6. [GUI React](#-gui-react)
7. [Interface QML](#-interface-qml)
8. [Configuration](#-configuration)
9. [Reconnaissance vocale](#-reconnaissance-vocale)
10. [Météo & Géolocalisation](#-météo--géolocalisation)
11. [Mémoire persistante](#-mémoire-persistante)
12. [Claude API](#-claude-api)
13. [Home Assistant — Détail technique](#-home-assistant--détail-technique)
14. [Tests](#-tests)
15. [Dépannage](#-dépannage)
16. [Changelog](#-changelog)
17. [Roadmap](#-roadmap)

---

## 🎯 Présentation

EXO est un assistant personnel intelligent articulé autour de trois couches :

| Couche | Technologie | Rôle |
|--------|-------------|------|
| **Moteur** | C++17 / Qt 6.9.3 | Audio, IA conversationnelle, météo, mémoire |
| **Backend** | Python 3.13 / aiohttp / websockets | Pont Home Assistant, orchestrateur GUI |
| **Frontends** | React 18 + QML | Interfaces utilisateur web & native |

---

## 🚀 Installation

### Prérequis

- **Windows 11** avec PowerShell
- **Qt 6.9.3** MSVC 2022 x64 (`C:\Qt\6.9.3\msvc2022_64`)
- **CMake 3.21+** et **Visual Studio Build Tools 2022**
- **Python 3.13+**
- **Node.js 22+** (pour la GUI React)
- Clés API : Claude (Anthropic), OpenWeatherMap, token Home Assistant

### Étape 1 — Cloner & configurer

```powershell
git clone https://github.com/AlexanderVDF/EXO.git
cd EXO

# Créer le fichier d'environnement
copy .env.example .env
# Renseigner CLAUDE_API_KEY, OWM_API_KEY, HA_URL, HA_TOKEN
```

### Étape 2 — Compiler le moteur C++

```powershell
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH="C:\Qt\6.9.3\msvc2022_64"
cd build
cmake --build . --config Debug
```

L'exécutable est généré dans `build\Debug\RaspberryAssistant.exe`. Les DLL Porcupine et les ressources sont copiées automatiquement par CMake.

### Étape 3 — Installer le backend Python

```powershell
pip install -r requirements.txt
```

Dépendances : `aiohttp >=3.9`, `websockets >=12`, `pytest >=8`, `pytest-asyncio >=0.23`.

### Étape 4 — Installer la GUI React

```powershell
cd gui
npm install
```

### Lancement

```powershell
# Méthode automatique (recommandée) — lance le moteur C++
.\launch_exo.ps1

# Ou manuellement
cd build\Debug
.\RaspberryAssistant.exe

# Backend Python (dans un terminal séparé)
python src/exo_server.py

# GUI React (dans un terminal séparé)
cd gui && npm run dev
```

Le script `launch_exo.ps1` ajoute Qt au PATH, charge les variables `.env` et lance l'exécutable.

---

## 🏗️ Architecture générale

```
EXO/
├── src/                           # Moteur C++ + Backend Python
│   ├── main.cpp                   # Point d'entrée Windows
│   ├── assistantmanager.cpp/.h    # Coordinateur central
│   ├── configmanager.cpp/.h       # Config hybride (conf + AppData)
│   ├── claudeapi.cpp/.h           # Client REST Anthropic
│   ├── voicemanager.cpp/.h        # Audio 16kHz + Porcupine + TTS
│   ├── weathermanager.cpp/.h      # OpenWeatherMap + géoloc IP
│   ├── aimemorymanager.cpp/.h     # Mémoire JSON circulaire
│   ├── porcupinewakeword_new.cpp/.h # DLL Porcupine dynamique
│   ├── logmanager.cpp/.h          # Logging par catégories
│   ├── exo_server.py              # Serveur Python principal
│   └── integrations/              # Modules Home Assistant
│       ├── __init__.py
│       ├── home_bridge.py         # WebSocket + REST + EventBus
│       ├── ha_entities.py         # Cache & requêtes entités
│       ├── ha_devices.py          # Appareils (MAC/IP matching)
│       ├── ha_areas.py            # Pièces (Plans ↔ HA sync)
│       ├── ha_actions.py          # 13 actions LLM Function Calling
│       ├── ha_sync.py             # Synchronisation complète
│       └── tests/                 # 92 tests pytest
│           ├── conftest.py
│           ├── test_home_bridge.py
│           ├── test_entities.py
│           ├── test_devices.py
│           ├── test_areas.py
│           ├── test_actions.py
│           └── test_sync.py
│
├── gui/                           # Interface React
│   ├── index.html
│   ├── package.json
│   ├── vite.config.js             # Port 3000, proxy WS
│   ├── tailwind.config.js         # Palette EXO (#6C5CE7, #00CEC9)
│   └── src/
│       ├── App.jsx
│       ├── main.jsx
│       ├── index.css
│       ├── components/            # Avatar, Card, Icon, Sidebar, TopBar, StateIndicator, Waveform
│       ├── screens/               # Home, Plans, NetworkMap, Devices, Settings
│       ├── hooks/                 # useWebSocket (auto-reconnect)
│       └── theme/
│
├── qml/                           # Interface QML native
│   ├── main.qml
│   ├── main_radial.qml            # Menu radial principal
│   ├── test_simple.qml
│   └── components/                # 12 composants
│       ├── AssistantInterface.qml
│       ├── ChatSection.qml
│       ├── ConfigurationSection.qml
│       ├── MaisonSection.qml
│       ├── MediasSection.qml
│       ├── AgendaSection.qml
│       ├── ColorWheel.qml
│       ├── ThemeEditor.qml
│       ├── StatusBar.qml
│       ├── VoiceVisualizer.qml
│       ├── TouchButton.qml
│       └── CloseButton.qml
│
├── config/
│   ├── assistant.conf              # Config par défaut (lecture seule)
│   ├── assistant.conf.example      # Template
│   ├── assistant_local.conf        # Config locale (non versionné)
│   └── environment.example         # Template Raspberry Pi
│
├── resources/
│   ├── fonts/
│   ├── icons/
│   └── porcupine/                  # 17 modèles de wake words
│
├── scripts/
│   ├── check_dependencies.ps1
│   ├── cleanup.ps1
│   ├── install_dependencies.ps1
│   ├── quick_build.ps1
│   ├── test_environment.ps1
│   └── verify_project.ps1
│
├── include/porcupine/              # Headers Porcupine C
├── lib/porcupine/                  # libpv_porcupine.dll
├── third_party/                    # Dépendances tierces
│
├── CMakeLists.txt                  # Build CMake (Qt6 modules)
├── requirements.txt                # Dépendances Python
├── pyproject.toml                  # Config pytest
├── .env                            # Variables secrètes (non versionné)
├── .env.example                    # Template .env
├── launch_exo.ps1                  # Script de lancement
└── EXO_DOCUMENTATION.md            # Ce fichier
```

### Diagramme de communication

```
┌─────────────────────┐     ┌──────────────────────┐
│   RaspberryAssistant│     │    GUI React          │
│   (C++ / Qt 6.9.3) │     │  http://localhost:3000│
│                     │     │                       │
│  AssistantManager   │     │  Plans · NetworkMap   │
│  ├─ ConfigManager   │     │  Devices · Settings   │
│  ├─ ClaudeAPI       │     └───────────┬───────────┘
│  ├─ VoiceManager    │                 │ WebSocket
│  ├─ WeatherManager  │                 │ ws://localhost:8765
│  └─ AIMemoryManager │                 │
└─────────────────────┘     ┌───────────▼───────────┐
                            │   exo_server.py       │
                            │   (Python asyncio)    │
                            │                       │
                            │  HomeBridge · Sync    │
                            │  Entities · Devices   │
                            │  Areas · Actions      │
                            └───────────┬───────────┘
                                        │ WebSocket + REST
                                        │ ws://HA_URL/api/websocket
                            ┌───────────▼───────────┐
                            │   Home Assistant      │
                            │   (http://HA_URL)     │
                            └───────────────────────┘
```

---

## ⚙️ Moteur C++ / Qt

### Modules Qt utilisés

Définis dans `CMakeLists.txt` :

| Module | Usage |
|--------|-------|
| Core | Types fondamentaux, signaux/slots |
| Quick | Moteur QML |
| QuickControls2 | Material Design |
| Widgets | Widgets natifs |
| Network | HTTP REST (Claude, OWM, géoloc) |
| Multimedia | QAudioSource / QAudioSink |
| MultimediaWidgets | — |
| TextToSpeech | Synthèse vocale française |
| Sql | Stockage local |

### Composants principaux

#### AssistantManager
Coordinateur central. Instancie et connecte tous les managers via signaux/slots Qt. Expose des Q_PROPERTY et Q_INVOKABLE au QML.

#### ConfigManager
Système hybride à deux niveaux :
- **Fichier base** : `config/assistant.conf` (valeurs par défaut, lecture seule)
- **Préférences utilisateur** : `%APPDATA%\EXOAssistant\user_config.ini` (QSettings, lecture/écriture)

Priorité : préférences utilisateur > configuration base. Supporte les variables d'environnement `${VAR}` dans le fichier conf.

#### ClaudeAPI
Client REST pour l'API Anthropic (`https://api.anthropic.com/v1/messages`). Gestion de timeout, retry automatique, rate limiting (50 requêtes/min). Modèles supportés : Haiku, Sonnet, Opus.

#### VoiceManager
Pipeline audio complet :
- **Capture** : QAudioSource 16 kHz, mono, Int16
- **Wake word** : Porcupine (chargement dynamique de DLL), sensibilité 0.7
- **Analyse** : Patterns audio (énergie, durée, fréquence) avec seuils calibrés
- **TTS** : Qt TextToSpeech (Microsoft Hortense / Julie / Paul)
- **Buffer clearing** : vidage automatique du tampon audio à la détection du wake word

#### WeatherManager
OpenWeatherMap avec mise à jour automatique toutes les 10 minutes. Conseils vestimentaires basés sur température et conditions. Géolocalisation IP via ip-api.com (HTTPS).

#### AIMemoryManager
Persistance JSON dans `%APPDATA%\EXOAssistant\`. Buffer circulaire de 100 conversations. Écritures atomiques (write → rename) pour éviter la corruption. 5 dernières conversations utilisées comme contexte Claude.

---

## 🐍 Backend Python / Home Assistant

### `exo_server.py` — Point d'entrée

Le serveur principal Python :
1. Charge les variables `.env`
2. Initialise `HomeBridge` (connexion HA)
3. Bootstrap tous les managers (entités, appareils, pièces)
4. Démarre le serveur WebSocket GUI sur `ws://localhost:8765`
5. Pousse un snapshot initial à chaque client GUI connecté
6. Dispatche les messages GUI : `plan_move`, `settings_update`, `network_scan`
7. Shutdown gracieux sur SIGINT/SIGTERM

### `home_bridge.py` — Pont WebSocket + REST

**EventBus** interne (async emit/on/off) pour distribuer les événements HA.

Connexion WebSocket persistante :
- Auto-reconnect toutes les 5 secondes
- Ping/pong toutes les 30 secondes
- Commandes/réponses avec système de futures (timeout 15 s)
- Événements souscrits : `state_changed`, `device_registry_updated`, `area_registry_updated`, `entity_registry_updated`

REST helpers pour les opérations ponctuelles (GET/POST vers `/api/...`).

Bootstrap en parallèle (`asyncio.gather`) : `get_states`, `devices`, `areas`, `entity_registry`.

### `ha_entities.py` — Gestionnaire d'entités

Cache en mémoire de toutes les entités HA. Requêtes : `get_entity`, `list_by_domain`, `list_by_area`, `search`, `summary`, `all_summaries`. Mise à jour en temps réel sur événements `state_changed`.

### `ha_devices.py` — Gestionnaire d'appareils

Matching par MAC et IP (normalisé). Persistance JSON dans `%APPDATA%\EXOAssistant\ha_devices.json`. Mapping appareil → entités. Fallback sur cache offline.

### `ha_areas.py` — Gestionnaire de pièces

Mappings area ↔ device ↔ entity. Assignation via commandes WS (`device_registry/update`, `entity_registry/update`). Synchronisation Plans → HA (drag-drop met à jour l'area HA). Recherche floue de pièce par nom.

### `ha_actions.py` — Actions LLM Function Calling

13 outils exposés au moteur Claude pour le contrôle domotique :

| Outil | Description |
|-------|-------------|
| `ha_turn_on` | Allumer une entité |
| `ha_turn_off` | Éteindre une entité |
| `ha_toggle` | Basculer une entité |
| `ha_set_brightness` | Luminosité (0–255, clamped) |
| `ha_set_color` | Couleur RGB (clamped 0–255) |
| `ha_set_temperature` | Thermostat °C |
| `ha_play_media` | Lancer un média |
| `ha_pause_media` | Pause média |
| `ha_stop_media` | Stop média |
| `ha_get_state` | État d'une entité (+ fallback REST) |
| `ha_list_devices` | Lister les appareils |
| `ha_list_entities` | Lister les entités |
| `ha_list_areas` | Lister les pièces |

`ActionDispatcher` avec table de dispatch et méthode `execute()` comme point d'entrée unique.

### `ha_sync.py` — Synchronisation complète

- **Plans → HA** : déplacement d'un appareil dans la vue 2D/3D met à jour l'area HA
- **Network → HA** : matching MAC/IP des hôtes réseau contre le registre HA
- **Snapshot** : `build_full_snapshot()` construit l'état complet (entités, appareils, pièces, topologie)
- **Topologie** : nœuds/arêtes vis-network pour la carte réseau
- **Push GUI** : broadcast temps réel sur `state_changed`

---

## ⚛️ GUI React

### Stack technique

- **React 18** + **Vite 5** (HMR, build rapide)
- **TailwindCSS 3** avec palette custom :
  - Fond : `#0E0E11`
  - Accent : `#6C5CE7`
  - Secondaire : `#00CEC9`
- **Konva / react-konva** : Plans 2D (drag-drop appareils)
- **Three.js / @react-three/fiber** : Vue 3D des plans
- **vis-network / vis-data** : Carte réseau interactive
- **Phosphor Icons** : Iconographie

### Écrans

| Écran | Fichier | Description |
|-------|---------|-------------|
| Home | `screens/Home.jsx` | Dashboard principal, état assistant |
| Plans | `screens/Plans.jsx` | Vue 2D (Konva) + 3D (Three.js) des pièces |
| NetworkMap | `screens/NetworkMap.jsx` | Carte réseau vis-network |
| Devices | `screens/Devices.jsx` | Liste et détail des appareils HA |
| Settings | `screens/Settings.jsx` | Thème, voix, VAD, réseau |

### Composants

| Composant | Description |
|-----------|-------------|
| `Avatar.jsx` | Avatar animé (canvas) |
| `Card.jsx` | Carte générique glassmorphism |
| `Icon.jsx` | Wrapper Phosphor Icons |
| `Sidebar.jsx` | Navigation latérale |
| `TopBar.jsx` | Barre supérieure + état connexion |
| `StateIndicator.jsx` | Indicateur d'état coloré |
| `Waveform.jsx` | Visualiseur audio néon (canvas) |

### WebSocket

Le hook `useWebSocket.js` gère la connexion à `ws://localhost:8765` avec :
- Auto-reconnect (backoff exponentiel)
- Callback `onMessage` pour dispatcher les messages
- État de connexion exposé aux composants

### Build & dev

```powershell
cd gui
npm run dev      # Dev server http://localhost:3000 (proxy WS → 8765)
npm run build    # Production dans gui/dist/
npm run preview  # Preview du build
```

---

## 🎨 Interface QML

Interface Material Design radiale intégrée au moteur C++.

### Fichiers principaux

- `main_radial.qml` — Interface principale avec menu radial
- `main.qml` — Interface alternative standard

### Composants (12)

| Composant | Rôle |
|-----------|------|
| AssistantInterface | Vue principale de l'assistant |
| ChatSection | Conversation avec Claude |
| ConfigurationSection | Paramètres utilisateur |
| MaisonSection | Contrôle domotique |
| MediasSection | Lecteur multimédia |
| AgendaSection | Agenda |
| ColorWheel | Sélecteur de couleur |
| ThemeEditor | Éditeur de thème |
| StatusBar | Barre de statut |
| VoiceVisualizer | Visualiseur audio |
| TouchButton | Bouton tactile |
| CloseButton | Bouton fermeture |

---

## ⚙️ Configuration

### Fichiers de configuration

| Fichier | Portée | Description |
|---------|--------|-------------|
| `.env` | Secrets | Clés API et tokens (non versionné) |
| `config/assistant.conf` | Défaut | Paramètres par défaut (lecture seule) |
| `%APPDATA%\EXOAssistant\user_config.ini` | Utilisateur | Préférences (prioritaire) |

### Variables d'environnement (`.env`)

```ini
# Anthropic — obligatoire
CLAUDE_API_KEY=sk-ant-api03-...

# OpenWeatherMap — obligatoire pour la météo
OWM_API_KEY=...

# Home Assistant — optionnel
HA_URL=http://localhost:8123
HA_TOKEN=votre-token-longue-duree
```

### Structure `assistant.conf`

```ini
[Claude]
api_key=${CLAUDE_API_KEY}
model=claude-3-haiku-20240307
base_url=https://api.anthropic.com/v1/messages
max_tokens=4096
temperature=0.7

[OpenWeatherMap]
api_key=${OWM_API_KEY}
city=Paris
update_interval=600000

[Voice]
wake_word=EXO
language=fr-FR
voice_rate=-0.3
voice_pitch=-0.1
voice_volume=0.9
```

### Système de priorité

```
.env (secrets) → assistant.conf (défauts) → user_config.ini (prefs utilisateur)
                                              ↑ Priorité maximale
```

Chaque modification depuis l'interface est immédiatement persistée dans `user_config.ini` via QSettings.

---

## 🎤 Reconnaissance vocale

### Pipeline

1. **Capture** : QAudioSource @ 16 kHz, mono, Int16
2. **Détection wake word** : Porcupine (DLL dynamique), sensibilité 0.7
3. **Buffer clearing** : vidage du tampon audio à la détection
4. **Écoute commande** : jusqu'à 30 secondes max
5. **Analyse patterns** : énergie (seuils 800/450/280), durée, fréquence
6. **Envoi à Claude** : avec contexte conversationnel
7. **TTS** : réponse vocale française

### Porcupine

- **DLL** : `lib/porcupine/libpv_porcupine.dll` (chargement dynamique via pointeurs de fonctions)
- **Headers** : `include/porcupine/`
- **Modèles** : `resources/porcupine/` (17 wake words disponibles)
- **Chargement** : résolution runtime de `pv_porcupine_init`, `pv_porcupine_process`, `pv_porcupine_delete`

### Configuration TTS

- **Voix** : Microsoft Hortense, Julie, Paul (françaises)
- **Rate** : -0.3 (plus lent et clair)
- **Pitch** : -0.1 (légèrement plus grave)
- **Volume** : 0.9

---

## 🌤️ Météo & Géolocalisation

### OpenWeatherMap

- Données temps réel (température, conditions, humidité, vent)
- Mise à jour automatique toutes les 10 minutes
- Conseils vestimentaires intelligents

### Géolocalisation IP

1. Requête HTTPS vers ip-api.com
2. Récupération : ville, région, pays
3. Mise à jour automatique de la ville météo
4. Sauvegarde persistante dans `user_config.ini`

Activation : Interface → Configuration → "Géolocalisation Automatique" → Détecter ma Position.

---

## 💾 Mémoire persistante

### Stockage

- **Chemin** : `%APPDATA%\EXOAssistant\exa_memory.json`
- **Format** : JSON (écritures atomiques : write tmp → rename)
- **Capacité** : 100 conversations (rotation automatique / buffer circulaire)
- **Contexte** : 5 dernières conversations envoyées à Claude

### API C++ (Q_INVOKABLE)

```cpp
void addConversation(QString userMessage, QString assistantResponse);
QString getConversationContext(int maxEntries = 5);
void updateUserPreference(QString key, QVariant value);
QVariant getUserPreference(QString key);
void clearAllMemory();
void clearConversationHistory();
```

---

## 🤖 Claude API

### Modèles supportés

| Modèle | Usage |
|--------|-------|
| claude-3-haiku-20240307 | Rapide, recommandé pour l'usage quotidien |
| claude-3-sonnet | Équilibré performance/qualité |
| claude-3-opus | Qualité maximale |

### Workflow

1. Wake word détecté → commande audio analysée
2. Contexte construit (5 dernières conversations + préférences)
3. Requête POST à `https://api.anthropic.com/v1/messages`
4. Réponse parsée, sauvegardée en mémoire
5. Synthèse vocale + affichage interface
6. Si action domotique détectée → dispatch vers `ha_actions.py`

### Sécurité

- Clé API stockée dans `.env` uniquement (jamais dans le code)
- Rate limiting : 50 requêtes/minute
- Timeout + retry automatique

---

## 🏠 Home Assistant — Détail technique

### Connexion

| Protocole | URL | Usage |
|-----------|-----|-------|
| WebSocket | `ws://HA_URL/api/websocket` | Événements temps réel, commandes |
| REST | `http://HA_URL/api/...` | Opérations ponctuelles |

Authentification par token longue durée (`HA_TOKEN` dans `.env`).

### Événements souscrits

| Événement | Effet |
|-----------|-------|
| `state_changed` | MAJ cache entité + push GUI |
| `device_registry_updated` | Refresh registre appareils |
| `area_registry_updated` | Rebuild mappings pièces |
| `entity_registry_updated` | Refresh registre entités |

### Flux de données

```
HA event → HomeBridge.EventBus → managers (entities/devices/areas)
                                       ↓
                               SyncManager → GUI broadcast (ws://8765)
```

### Persistance locale

- `%APPDATA%\EXOAssistant\ha_devices.json` — cache appareils (fallback offline)

---

## 🧪 Tests

### Tests Python (92)

```powershell
python -m pytest src/integrations/tests/ -v
```

| Fichier | Tests | Couverture |
|---------|-------|------------|
| `test_home_bridge.py` | EventBus, init, ws_command, dispatch | Connexion WS |
| `test_entities.py` | Bootstrap, requêtes, live update, summary | Cache entités |
| `test_devices.py` | Bootstrap, MAC/IP matching, search, mapping | Appareils |
| `test_areas.py` | Bootstrap, assignation, plan sync, summary | Pièces |
| `test_actions.py` | 13 tools validation, turn/brightness/color/media | Actions LLM |
| `test_sync.py` | Plan sync, network matching, snapshot, topology | Synchronisation |

Configuration pytest dans `pyproject.toml` : `asyncio_mode = "auto"`.

### Scripts PowerShell

| Script | Description |
|--------|-------------|
| `scripts/test_environment.ps1` | Vérification complète de l'environnement |
| `scripts/verify_project.ps1` | Validation de la structure du projet |
| `scripts/check_dependencies.ps1` | Vérification des dépendances |
| `scripts/quick_build.ps1` | Compilation rapide |
| `scripts/install_dependencies.ps1` | Installation automatique |
| `scripts/cleanup.ps1` | Nettoyage des artefacts |

---

## 🐛 Dépannage

### L'application ne se lance pas

Vérifier que le dossier de travail est correct :
```powershell
cd C:\Users\aalou\Exo\build\Debug
.\RaspberryAssistant.exe
```

### Configuration non trouvée

Copier le dossier config à côté de l'exécutable :
```powershell
Copy-Item -Path "config" -Destination "build\Debug\" -Recurse -Force
```

### TTS ne fonctionne pas

Vérifier la présence de voix françaises dans les logs :
```
Voix française trouvée: Microsoft Hortense
Voix française trouvée: Microsoft Julie
Voix française trouvée: Microsoft Paul
```

### EXO ne m'entend pas

- Vérifier que le micro est actif et sélectionné comme périphérique par défaut
- Vérifier les logs audio : `[VOICE] Audio level: ...`
- Les seuils d'énergie calibrés sont : 800 (fort), 450 (moyen), 280 (faible)

### Géolocalisation échoue

- Pas de connexion Internet
- Service ip-api.com indisponible
- Firewall bloquant les requêtes HTTPS

### Backend Python ne se connecte pas à HA

- Vérifier `HA_URL` et `HA_TOKEN` dans `.env`
- Vérifier que Home Assistant est accessible depuis la machine
- Vérifier les logs : `python src/exo_server.py` affiche les erreurs de connexion

---

## 📝 Changelog

### v3.0 — Juillet 2025
- ✅ **GUI React complète** — 5 écrans (Home, Plans, NetworkMap, Devices, Settings)
- ✅ **Backend Python Home Assistant** — 6 modules + serveur WebSocket
- ✅ **13 actions LLM Function Calling** — contrôle domotique par la voix
- ✅ **92 tests unitaires Python** — couverture complète HA
- ✅ **Audit sécurité** — 12 correctifs (API keys, HTTPS, atomic writes, double-delete, QElapsedTimer)
- ✅ **Fix audio** — buffer clearing + calibration seuils
- ✅ **Renommage Henri → EXO** — toute la codebase

### v2.1 — Octobre 2025
- ✅ Géolocalisation automatique IP
- ✅ Persistance météo corrigée (Settings hybrides)
- ✅ Architecture unifiée (60% réduction doublons)
- ✅ Interface améliorée (section géolocalisation)
- ✅ Code optimisé (debug conditionnel)

### v2.0
- ✅ Interface radiale Material Design
- ✅ Intégration Claude API complète
- ✅ Système de mémoire persistante
- ✅ Reconnaissance vocale Porcupine + TTS
- ✅ Météo temps réel OpenWeatherMap
- ✅ Configuration modulaire

---

## 🔮 Roadmap

- [ ] **Whisper API** — reconnaissance vocale complète (→ remplacer l'analyse de patterns)
- [ ] **Google Calendar** — agenda intelligent + rappels
- [ ] **Streaming musical** — Spotify / Tidal
- [ ] **Déploiement Raspberry Pi 5** — version ARM optimisée
- [ ] **Interface mobile** — companion app
- [ ] **Multi-langues** — support international
- [ ] **Auto-update** — mise à jour automatique
- [ ] **Docker** — déploiement containerisé

---

## Contact

- **Développeur** : Alexandre VDF
- **Repository** : [github.com/AlexanderVDF/EXO](https://github.com/AlexanderVDF/EXO)

---

**EXO Assistant v3.0** — C++ / Qt 6.9.3 · Python · React 18