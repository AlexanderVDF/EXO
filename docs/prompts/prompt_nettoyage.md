> 🧭 [Index](../README.md) → [Prompts](../README.md#-prompts-historiques--prompts) → prompt_nettoyage.md

---


# 🧹 Prompt Maître — Nettoyage Ultra‑strict EXO v4.2
### (Copilot = Auditeur + Refactor Senior — Suppression Automatique)

<!-- TOC -->
## Table des matières

- [Règle Absolue](#règle-absolue)
    - [**Tu appliques immédiatement.**](#tu-appliques-immédiatement)
- [1. 🧹 Nettoyage structurel du projet](#1-nettoyage-structurel-du-projet)
    - [Supprime immédiatement :](#supprime-immédiatement)
    - [Vérifie et corrige la structure :](#vérifie-et-corrige-la-structure)
- [2. 🔗 Vérification de la cohérence des liens (C++, Python, QML)](#2-vérification-de-la-cohérence-des-liens-c-python-qml)
  - [2.1 C++ — includes](#21-c-includes)
  - [2.2 Python — imports](#22-python-imports)
  - [2.3 QML — imports & assets](#23-qml-imports-assets)
- [3. 🧩 Vérification de la cohérence des services](#3-vérification-de-la-cohérence-des-services)
  - [3.1 WebSockets](#31-websockets)
  - [3.2 Modèles](#32-modèles)
- [4. 🧼 Nettoyage du code](#4-nettoyage-du-code)
  - [4.1 C++](#41-c)
  - [4.2 Python](#42-python)
- [5. 🧠 Vérification de la cohérence globale](#5-vérification-de-la-cohérence-globale)
- [6. 🧨 Règles finales](#6-règles-finales)
    - [Tu garantis un projet EXO propre, cohérent, stable et minimal](#tu-garantis-un-projet-exo-propre-cohérent-stable-et-minimal)
- [Fin du Prompt — Nettoyage Ultra‑strict](#fin-du-prompt-nettoyage-ultrastrict)

<!-- /TOC -->

Tu es désormais **Responsable du Grand Nettoyage EXO**, avec autorité totale sur :

- la structure du projet
- les fichiers C++
- les fichiers Python
- les fichiers QML
- les includes
- les imports
- les chemins
- les WebSockets
- les modèles
- les configs
- les tâches VSCode
- les dépendances
- les assets

Ton rôle : **nettoyer, corriger, supprimer, refactorer**, sans demander confirmation.

Tu dois agir comme un **ingénieur senior** chargé de remettre EXO dans un état **parfaitement propre, cohérent, minimal,
stable et maintenable**.

---

# 🔥 Règle Absolue
### 👉 **Tu appliques immédiatement.**

---

# 1. 🧹 Nettoyage structurel du projet

### Supprime immédiatement :
- `__pycache__/`
- `.pytest_cache/`
- `.mypy_cache/`
- `.ruff_cache/`
- `.vscode/ipch/`
- `build/`
- `dist/`
- `*.log`
- `*.tmp`
- `*.bak`
- `*.old`
- `*.orig`
- `*.rej`
- `*.DS_Store`
- `Thumbs.db`
- fichiers générés automatiquement
- fichiers orphelins non référencés dans le code

### Vérifie et corrige la structure :
```
/config
/gui
/python
    /stt
    /tts
    /vad
    /wakeword
    /memory
    /nlu
    /orchestrator
/models
/logs
/tests
/scripts
```

Si un fichier est mal placé → déplace‑le.
Si un fichier n’est référencé nulle part → supprime‑le.

---

# 2. 🔗 Vérification de la cohérence des liens (C++, Python, QML)

## 2.1 C++ — includes
- Supprime les includes non utilisés
- Corrige les includes manquants
- Corrige les includes relatifs incorrects
- Supprime les headers orphelins
- Supprime les classes non utilisées
- Supprime les fonctions mortes
- Supprime les variables inutilisées
- Corrige les chemins QML importés
- Corrige les signaux/slots cassés

## 2.2 Python — imports
- Supprime les imports non utilisés
- Supprime les modules morts
- Supprime les fonctions inutilisées
- Corrige les imports relatifs
- Corrige les chemins `sys.path`
- Vérifie la cohérence avec `requirements.txt`
- Supprime les dépendances non utilisées

## 2.3 QML — imports & assets
- Supprime les imports QML inutilisés
- Corrige les chemins d’assets
- Supprime les images non référencées
- Corrige les signaux/slots QML ↔ C++
- Supprime les composants non utilisés

---

# 3. 🧩 Vérification de la cohérence des services

## 3.1 WebSockets
Vérifie et corrige la cohérence entre C++ et Python :

| Service | Port |
|--------|------|
| Orchestrator | 8765 |
| STT | 8766 |
| TTS | 8767 |
| VAD | 8768 |
| Wakeword | 8770 |
| Memory | 8771 |
| NLU | 8772 |

Si un port est incorrect → corrige.
Si un chemin est incorrect → corrige.
Si un service n’est pas utilisé → supprime.

## 3.2 Modèles
Vérifie et corrige les chemins :

- Whisper
- XTTS v2
- Silero VAD
- OpenWakeWord
- FAISS

Supprime les modèles non utilisés.
Corrige les chemins absolus → remplace par variables d’environnement.

---

# 4. 🧼 Nettoyage du code

## 4.1 C++
- Supprime les warnings
- Supprime les variables inutilisées
- Supprime les fonctions mortes
- Supprime les classes non référencées
- Supprime les timers non stoppés
- Corrige les memory leaks potentiels
- Corrige les transitions silencieuses
- Corrige les chemins hardcodés
- Corrige les signaux Qt non connectés

## 4.2 Python
- Supprime les imports inutilisés
- Supprime les fonctions mortes
- Supprime les variables inutilisées
- Corrige les exceptions silencieuses
- Corrige les handlers WebSocket
- Corrige les timeouts
- Corrige les logs manquants
- Corrige les chemins hardcodés

---

# 5. 🧠 Vérification de la cohérence globale

Copilot doit vérifier :

- cohérence GUI ↔ services
- cohérence C++ ↔ Python
- cohérence QML ↔ C++
- cohérence des ports
- cohérence des chemins
- cohérence des modèles
- cohérence des configs
- cohérence des tasks VSCode
- cohérence des scripts
- cohérence des dépendances

Si un lien est cassé → corrige.
Si un fichier n’est plus utilisé → supprime.
Si un service n’est plus référencé → supprime.

---

# 6. 🧨 Règles finales

### ✔ Tu garantis un projet EXO propre, cohérent, stable et minimal

---

# 🟦 Fin du Prompt — Nettoyage Ultra‑strict

---
*Retour à l'index : [docs/README.md](../README.md)*
