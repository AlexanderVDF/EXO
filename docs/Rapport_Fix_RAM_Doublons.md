# Rapport Final — Fix RAM & Doublons Microservices

**Date** : 2025-03-21  
**Version** : EXO v4.2.0  
**Plateforme** : Windows 11 — AMD Radeon RX 6750 XT — 16 GB RAM  

---

## 1. Diagnostic Initial

### Processus détectés avant nettoyage

| Catégorie | Instances | RAM totale |
|-----------|-----------|------------|
| Python (microservices) | **14** (7 légitimes + 7 doublons) | ~6.7 GB |
| whisper-server.exe | **7** (1 légitime + 6 doublons) | ~2.0 GB |
| **TOTAL** | **21 processus** | **~8.7 GB** |

### Cause racine
- **Aucun** des 7 microservices n'avait de protection anti-doublon
- `websockets.serve()` se lie au port mais ne vérifie pas s'il est déjà occupé
- Les relances successives via VS Code `launch_all` accumulaient des instances orphelines
- Les doublons provenaient de l'ancienne arborescence `src/` (Python311) + la nouvelle `python/` (venv)

---

## 2. Corrections Appliquées

### A. Protection singleton — `python/shared/singleton_guard.py`

Module partagé avec `ensure_single_instance(port, service_name)` :
- Tente une connexion TCP sur `127.0.0.1:port` avec timeout 1s
- Si connexion réussie → port occupé → `sys.exit(0)` immédiat
- Si `ConnectionRefusedError` → port libre → continue normalement
- Appelé **AVANT** le chargement des modèles lourds (évite le gaspillage RAM)

### B. Microservices patchés (7/7)

| Service | Port | Fichier | Statut |
|---------|------|---------|--------|
| exo_server | 8765 | `python/orchestrator/exo_server.py` | ✅ Protégé |
| stt_server | 8766 | `python/stt/stt_server.py` | ✅ Protégé |
| tts_server | 8767 | `python/tts/tts_server.py` | ✅ Protégé |
| vad_server | 8768 | `python/vad/vad_server.py` | ✅ Protégé |
| wakeword_server | 8770 | `python/wakeword/wakeword_server.py` | ✅ Protégé |
| memory_server | 8771 | `python/memory/memory_server.py` | ✅ Protégé |
| nlu_server | 8772 | `python/nlu/nlu_server.py` | ✅ Protégé |

### C. Script de nettoyage — `scripts/auto_kill_zombies.py`

- Détecte les doublons Python, whisper-server, Node watchers excessifs, Code Helpers
- Utilise WMIC (pas de dépendance psutil)
- Filtre intelligent : ignore les shims venv (< 10 MB + `.venv` dans le chemin)
- Mode dry-run par défaut, `--kill` pour exécuter
- Garde l'instance avec la plus haute RAM (la plus active)

### D. Optimisation VS Code — `.vscode/settings.json`

- `files.watcherExclude` : build/, whisper.cpp/, rtaudio/, .venv*/, __pycache__/
- `search.exclude` : mêmes dossiers lourds
- `C_Cpp.intelliSenseMemoryLimit` : 1024 MB
- `C_Cpp.codeAnalysis.runAutomatically` : false
- `editor.minimap.enabled` : false

---

## 3. Résultats du Nettoyage

### Zombies éliminés

| Phase | Processus tués | RAM libérée |
|-------|---------------|-------------|
| 1ère passe (auto_kill_zombies.py) | 12 (6 Python + 6 whisper-server) | 2 155 MB |
| 2ème passe (manuels, ancien `src/`) | 5 | ~35 MB |
| 3ème passe (whisper-server restants) | 2 | ~1 222 MB |
| **TOTAL** | **19 processus** | **~3.4 GB** |

### État final des ports

```
Port   Service          PID     RAM      Statut
8765   exo_server       19584    46 MB   ✅ LISTENING
8766   stt_server       64956   229 MB   ✅ LISTENING
8767   tts_server       55760  2354 MB   ✅ LISTENING
8768   vad_server        2272   187 MB   ✅ LISTENING
8769   whisper-server   40444  2028 MB   ✅ LISTENING
8770   wakeword_server  50696   191 MB   ✅ LISTENING
8771   memory_server    33736   350 MB   ✅ LISTENING
8772   nlu_server       31060    28 MB   ✅ LISTENING
```

**8/8 services opérationnels — 1 instance unique par service**

---

## 4. Bilan RAM

| Métrique | Avant | Après | Gain |
|----------|-------|-------|------|
| Processus Python | 14 | 7 (+7 shims venv) | -7 doublons |
| Processus whisper-server | 7 | 1 | -6 doublons |
| RAM totale EXO | ~8 700 MB | **5 412 MB** | **-3 288 MB (-38%)** |
| RAM Python (réels) | — | 3 384 MB | — |
| RAM whisper-server | — | 2 028 MB | — |

> **Note** : 5.4 GB est le minimum incompressible pour charger les 7 modèles AI (XTTS v2 = 2.3 GB, Whisper large-v3 = 2 GB, FAISS = 350 MB, Silero VAD/Wakeword = 378 MB).

---

## 5. Validation Anti-Doublon

### Test singleton guard

```
$ python python/nlu/nlu_server.py
2025-03-21 17:48:07 [NLU] nlu_server: port 8772 already in use — duplicate prevented, exiting.
```

✅ Le 2e lancement est immédiatement rejeté — aucun modèle chargé, aucune RAM gaspillée.

### Test auto_kill_zombies.py (dry-run post-nettoyage)

```
Total zombie/duplicate processes: 0
Total RAM occupied: 0 MB (0.0 GB)
```

✅ Zéro doublon détecté.

---

## 6. Fichiers Modifiés/Créés

### Créés
- `python/shared/singleton_guard.py` — module de protection anti-doublon
- `scripts/auto_kill_zombies.py` — script de nettoyage automatique
- `docs/Rapport_Fix_RAM_Doublons.md` — ce rapport

### Modifiés
- `python/orchestrator/exo_server.py` — ajout singleton guard
- `python/stt/stt_server.py` — ajout singleton guard
- `python/tts/tts_server.py` — ajout singleton guard + `import sys`
- `python/vad/vad_server.py` — ajout singleton guard + `from pathlib import Path`
- `python/wakeword/wakeword_server.py` — ajout singleton guard
- `python/memory/memory_server.py` — ajout singleton guard + `import sys`
- `python/nlu/nlu_server.py` — ajout singleton guard + `import sys` + `from pathlib import Path`
- `.vscode/settings.json` — optimisations watcherExclude, search.exclude, C++ limits

---

## 7. Recommandations

1. **Utiliser `scripts/auto_kill_zombies.py --kill`** avant chaque session de développement pour nettoyer d'éventuels orphelins
2. **Ne jamais tuer les processus venv "stub"** (4 MB, `.venv\Scripts\python.exe`) — ce sont les parents des vrais processus ; les tuer tue aussi le service
3. **Privilégier `launch_all`** depuis VS Code pour les lancements groupés — le singleton guard empêchera les doublons même en cas de double-clic
