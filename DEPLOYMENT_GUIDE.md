# 🚀 Guide de Déploiement Rapide - Assistant Domotique v2.0

## 📋 Prérequis de Développement

### 🖥️ **Windows (Développement)**
```powershell
# Qt 6.5+ avec modules 3D
winget install Qt.QtCreator

# CMake et outils build
winget install Kitware.CMake
winget install Microsoft.VisualStudio.2022.BuildTools

# Python 3.11+
winget install Python.Python.3.11
```

### 🍓 **Raspberry Pi 5 (Production)**
```bash
# Système de base
sudo apt update && sudo apt full-upgrade -y

# Qt 6 avec modules avancés
sudo apt install -y qt6-base-dev qt6-qml-dev qt6-quick-dev \
                    qt6-multimedia-dev qt6-3d-dev qt6-websockets-dev \
                    qt6-positioning-dev libqt6sql6-sqlite

# Dépendances système
sudo apt install -y cmake build-essential ninja-build \
                    python3-pip python3-venv python3-dev \
                    libasound2-dev pulseaudio alsa-utils \
                    libsqlite3-dev pkg-config
```

## ⚡ Compilation Rapide

### 🏗️ **Build Local (Test Windows)**
```powershell
# Dans le répertoire du projet
mkdir build
cd build

# Configuration CMake
cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Debug

# Compilation
ninja -j4

# Test local (sans Raspberry Pi)
.\RaspberryAssistant.exe --test-mode
```

### 🍓 **Build Raspberry Pi 5**
```bash
# Sur le Raspberry Pi
git clone <votre-repo>
cd raspberry-assistant

# Installation Python
python3 -m venv venv
source venv/bin/activate
pip install -r python/requirements.txt

# Compilation optimisée ARM64
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DRASPBERRY_PI=ON
make -j4

# Installation système
sudo make install
```

## 🔑 Configuration des API

### 📝 **Fichier de Configuration Principal**
```bash
# Créer config/api_keys.conf
cat > config/api_keys.conf << EOF
# Claude Haiku (Anthropic)
ANTHROPIC_API_KEY=sk-ant-api03-votre_clé_ici

# Microsoft Azure TTS
AZURE_TTS_KEY=votre_clé_azure
AZURE_TTS_REGION=francecentral

# EZVIZ Smart Home  
EZVIZ_APP_KEY=votre_app_key
EZVIZ_APP_SECRET=votre_app_secret
EZVIZ_ACCOUNT=votre_email
EZVIZ_PASSWORD=votre_mot_de_passe

# Spotify
SPOTIFY_CLIENT_ID=votre_client_id
SPOTIFY_CLIENT_SECRET=votre_client_secret

# Tidal
TIDAL_CLIENT_ID=votre_client_id  
TIDAL_CLIENT_SECRET=votre_client_secret

# Google Services
GOOGLE_CLIENT_ID=votre_client_id
GOOGLE_CLIENT_SECRET=votre_client_secret
GOOGLE_API_KEY=votre_api_key
EOF
```

### 🔒 **Sécurisation**
```bash
# Permissions restrictives
chmod 600 config/api_keys.conf
chown pi:pi config/api_keys.conf

# Variables d'environnement
source config/api_keys.conf
export $(cat config/api_keys.conf | xargs)
```

## 🎯 Tests Rapides

### 🧪 **Test des Modules**
```bash
# Test service Claude
cd python
python3 claude_service.py --test

# Test TTS Microsoft Henri
python3 -c "
from src.microsofttts import MicrosoftTTSManager
tts = MicrosoftTTSManager()
tts.testConfiguration()
"

# Test base de données
sqlite3 data/memory.db ".tables"
```

### 🎤 **Test Audio**
```bash
# Test microphone
arecord -d 5 -f cd test_mic.wav && aplay test_mic.wav

# Test haut-parleurs
speaker-test -t sine -f 1000 -l 2

# Test TTS
echo "Bonjour Henri" | espeak-ng -v fr
```

## 🖥️ Interface et Démarrage

### 🎨 **Mode Développement**
```bash
# Démarrage avec debug complet
export QT_LOGGING_RULES="*.debug=true"
./RaspberryAssistant --platform xcb --windowed --debug

# Interface avancée
./RaspberryAssistant --interface advanced --fullscreen
```

### 🎯 **Mode Production RPi5**
```bash
# Configuration EGLFS (sans X11)
export QT_QPA_PLATFORM=eglfs
export QT_QPA_EGLFS_ALWAYS_SET_MODE=1

# Démarrage automatique
sudo systemctl enable raspberry-assistant
sudo systemctl start raspberry-assistant

# Logs temps réel
journalctl -u raspberry-assistant -f
```

## 📊 Monitoring et Debug

### 🔍 **Surveillance Système**
```bash
# Ressources RPi5
htop -p $(pgrep RaspberryAssistant)

# Température et throttling
watch -n 1 "vcgencmd measure_temp && vcgencmd get_throttled"

# Métriques réseau
sudo netstat -tulnp | grep 8001  # Service Claude
```

### 🐛 **Debug Interface**
```bash
# Mode debug QML
QML_IMPORT_TRACE=1 ./RaspberryAssistant

# Inspection QML
qml-inspect --port 9999 &

# Performance 3D
export QT_3D_RENDERER=opengl
export QT_OPENGL_DEBUG=1
```

## 🚀 Démarrage Rapide Complet

### 📱 **Script All-in-One**
```bash
#!/bin/bash
# quick_start.sh - Démarrage complet en une commande

echo "🏠 Assistant Domotique - Démarrage Rapide"

# 1. Configuration environnement
source config/api_keys.conf
export $(cat config/api_keys.conf | xargs)

# 2. Démarrage service Claude
cd python && python3 claude_service.py --daemon &
cd ..

# 3. Initialisation base de données
mkdir -p data
sqlite3 data/memory.db < scripts/init_database.sql

# 4. Configuration audio
sudo systemctl --user start pulseaudio
amixer set Master 70%

# 5. Démarrage interface
if [[ $(uname -m) == "aarch64" ]]; then
    # Raspberry Pi 5
    export QT_QPA_PLATFORM=eglfs
    ./build/RaspberryAssistant --fullscreen
else
    # Développement desktop
    ./build/RaspberryAssistant --windowed --debug
fi
```

### 🎯 **Commandes Essentielles**
```bash
# Compilation rapide
make -j4 && sudo make install

# Test complet
./scripts/run_tests.sh

# Sauvegarde configuration
tar -czf backup_config.tar.gz config/ data/

# Mise à jour depuis Git
git pull && make -j4 && sudo systemctl restart raspberry-assistant
```

## 📋 Checklist de Développement

### ✅ **Avant Premier Démarrage**
- [ ] Qt 6.5+ installé avec modules 3D
- [ ] Python 3.11+ avec venv configuré
- [ ] Clés API obtenues (Claude, Azure, EZVIZ, Spotify, Google)
- [ ] Audio testé (micro + haut-parleurs)
- [ ] Compilation réussie sans erreurs

### ✅ **Test Fonctionnalités**
- [ ] Interface QML s'affiche correctement
- [ ] Service Claude répond aux requêtes
- [ ] TTS Henri fonctionne (synthèse vocale française)
- [ ] Connexion EZVIZ établie (si appareils disponibles)
- [ ] Streaming musical configuré (Spotify/Tidal)
- [ ] Services Google authentifiés

### ✅ **Optimisation Production**
- [ ] Mode EGLFS configuré pour RPi5
- [ ] Service systemd activé
- [ ] Monitoring système fonctionnel
- [ ] Sauvegarde automatique des données
- [ ] Log rotation configurée

## 🎉 Prêt pour le Développement !

Votre assistant domotique avancé est maintenant prêt avec :

- 🤖 **Intelligence Claude Haiku** avec mémoire persistante
- 🎙️ **Synthèse vocale Henri** naturelle française  
- 🏡 **Contrôle domotique EZVIZ** complet
- 🏗️ **Designer 3D** pour l'aménagement
- 🎵 **Streaming musical** Tidal/Spotify multi-room
- 📱 **Services Google** intégrés
- 🧠 **Apprentissage IA** des habitudes

**Commande de démarrage :**
```bash
chmod +x quick_start.sh
./quick_start.sh
```

Bon développement ! 🚀