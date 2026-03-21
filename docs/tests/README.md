# Tests — Guide complet

## Vue d'ensemble

EXO dispose de **180 tests automatisés** répartis en 2 suites :

| Suite | Framework | Nombre | Durée | Commande |
|-------|-----------|--------|-------|----------|
| C++ | Qt Test + CTest | 7 | ~0.6s | `ctest --test-dir build -C Debug --output-on-failure` |
| Python | pytest | 173+ | ~2.2s | `.venv\Scripts\python.exe -m pytest tests/ -v --tb=short` |

## Prérequis

### C++
```powershell
# Build avec tests activés
cmake -B build -G "Visual Studio 17 2022" ^
  -DCMAKE_PREFIX_PATH="C:/Qt/6.9.3/msvc2022_64" ^
  -DBUILD_TESTS=ON
cmake --build build --config Debug
```

### Python
```powershell
# Environnement virtuel principal
.venv\Scripts\Activate.ps1
pip install pytest pytest-asyncio
```

## Tests C++ (Qt Test)

Tous les tests C++ utilisent le framework **Qt Test** (`QTest`) et sont exécutés via **CTest**.

### Liste des tests

| Test | Fichier | Ce qu'il teste |
|------|---------|---------------|
| `test_configmanager` | `tests/cpp/test_configmanager.cpp` | Chargement config INI, fusion 3 couches, valeurs par défaut, surcharges utilisateur |
| `test_pipelineevent` | `tests/cpp/test_pipelineevent.cpp` | Bus d'événements typés, corrélation par ID, snapshots module, événements récents |
| `test_circularaudiobuffer` | `tests/cpp/test_circularaudiobuffer.cpp` | Ring buffer write/read/peek, wraparound, overflow, capacité |
| `test_audiopreprocessor` | `tests/cpp/test_audiopreprocessor.cpp` | Filtre high-pass 150Hz, noise gate, AGC, normalisation RMS |
| `test_tts_dsp` | `tests/cpp/test_tts_dsp.cpp` | Equalizer 3kHz, compresseur dynamique, normalisation -16dBFS |
| `test_pipelinetracer` | `tests/cpp/test_pipelinetracer.cpp` | Assemblage timeline, détection anomalies (latence, gaps, boucles) |
| `test_healthcheck` | `tests/cpp/test_healthcheck.cpp` | État initial, enums santé, configure sans crash, start/stop, signaux |

### Architecture des tests C++

```
tests/cpp/
├── CMakeLists.txt           # Configuration CTest + librairie partagée
├── test_configmanager.cpp
├── test_pipelineevent.cpp
├── test_circularaudiobuffer.cpp
├── test_audiopreprocessor.cpp
├── test_tts_dsp.cpp
├── test_pipelinetracer.cpp
└── test_healthcheck.cpp
```

La bibliothèque `exo_testlib` compile tous les modules C++ testables en une lib statique partagée par tous les tests. Chaque test est un exécutable indépendant.

### Exécution

```powershell
# Tous les tests
ctest --test-dir build -C Debug --output-on-failure

# Un test spécifique
ctest --test-dir build -C Debug -R test_configmanager --output-on-failure

# Rebuild + test d'un seul
cmake --build build --config Debug --target test_healthcheck
build\tests\cpp\Debug\test_healthcheck.exe
```

## Tests Python (pytest)

### Liste des fichiers de test

| Fichier | Nombre | Ce qu'il teste |
|---------|--------|---------------|
| `test_nlu_server.py` | ~25 | Classification d'intentions (8 intents), extraction d'entités, confiance, routage Claude |
| `test_actions.py` | ~20 | 13 handlers d'actions HA (light, cover, climate, media, sensor, scene) |
| `test_entities.py` | ~15 | Chargement entités HA, cache, requêtes par domaine/area |
| `test_devices.py` | ~12 | Synchronisation appareils HA, métadonnées, localisation |
| `test_areas.py` | ~8 | Gestion pièces/zones HA |
| `test_home_bridge.py` | ~10 | Connexion WS HA, gestion événements |
| `test_sync.py` | ~10 | Détection drift d'état, réconciliation, snapshot GUI |
| `test_memory_server.py` | ~10 | FAISS add/search/remove, embeddings, stockage |
| `test_tts_server.py` | ~10 | PhraseCache LRU, protocole synthesize/cancel/voices |
| `test_stt_server.py` | ~8 | Détection hallucinations, protocole start/end/config |
| `test_vad_server.py` | ~5 | Protocole VAD, conversion PCM16, taille chunks |
| `test_healthcheck_protocol.py` | ~10 | Ping/pong format, dispatch par serveur, robustesse |

### Fixtures (conftest.py)

Le fichier `tests/python/conftest.py` fournit des fixtures pytest :
- `fake_entities` : données d'entités HA simulées
- `fake_devices` : appareils simulés
- `fake_areas` : pièces simulées
- Mocks pour WebSocket, HTTP, etc.

### Exécution

```powershell
# Tous les tests
.venv\Scripts\python.exe -m pytest tests/ -v --tb=short

# Un fichier spécifique
.venv\Scripts\python.exe -m pytest tests/python/test_nlu_server.py -v

# Un test spécifique
.venv\Scripts\python.exe -m pytest tests/python/test_nlu_server.py::TestIntentClassifier::test_weather_intent -v

# Avec couverture (si pytest-cov installé)
.venv\Scripts\python.exe -m pytest tests/ --cov=python --cov-report=term-missing
```

## Convention de nommage

| Langue | Pattern | Exemple |
|--------|---------|---------|
| C++ | `test_<module>.cpp` → classe avec méthodes `test<Nom>()` | `testInitialState()` |
| Python | `test_<module>.py` → classes `Test<Module>` → méthodes `test_<desc>` | `test_weather_intent` |

## Ajout d'un nouveau test

### C++
1. Créer `tests/cpp/test_nouveau.cpp` (hérite de `QObject`, macro `QTEST_MAIN`)
2. Ajouter dans `tests/cpp/CMakeLists.txt` : `exo_add_test(test_nouveau)`
3. Si nouvelles sources nécessaires, les ajouter à `exo_testlib`

### Python
1. Créer `tests/python/test_nouveau.py`
2. Pytest le détecte automatiquement (prefix `test_`)
3. Utiliser les fixtures de `conftest.py` si besoin

## CI locale

Exécuter les deux suites pour validation complète :

```powershell
# Build
cmake --build build --config Debug

# Tests C++
ctest --test-dir build -C Debug --output-on-failure

# Tests Python
.venv\Scripts\python.exe -m pytest tests/ -v --tb=short
```

Résultat attendu : **7/7 CTest + 173/173 pytest = 180 tests verts**
