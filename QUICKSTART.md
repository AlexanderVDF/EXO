# 🚀 Guide de Démarrage Rapide - Assistant Domotique v2.0

## Étapes pour commencer le développement MAINTENANT

### 1. 📋 Configuration des clés API (5 minutes)

Créez le fichier de configuration principal :
```bash
# Créer le fichier de configuration
cp config/assistant.conf.example config/assistant.conf
nano config/assistant.conf
```

Ajoutez vos clés API :
```ini
# Configuration Assistant Domotique v2.0

# Claude Haiku (Obligatoire) - https://console.anthropic.com/
ANTHROPIC_API_KEY=sk-ant-api03-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Microsoft Azure TTS Henri (Optionnel) - https://azure.microsoft.com/cognitive-services/
AZURE_TTS_KEY=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
AZURE_TTS_REGION=francecentral

# EZVIZ Smart Home (Optionnel) - https://open.ys7.com/
EZVIZ_APP_KEY=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
EZVIZ_APP_SECRET=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
EZVIZ_ACCOUNT=votre.email@exemple.com
EZVIZ_PASSWORD=votre_mot_de_passe

# Spotify (Optionnel) - https://developer.spotify.com/
SPOTIFY_CLIENT_ID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
SPOTIFY_CLIENT_SECRET=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Tidal (Optionnel) - https://developer.tidal.com/
TIDAL_CLIENT_ID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
TIDAL_CLIENT_SECRET=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Google Services (Optionnel) - https://console.cloud.google.com/
GOOGLE_CLIENT_ID=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
GOOGLE_API_KEY=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### 2. 🔧 Installation des dépendances (sur Windows)

```powershell
# Installer Qt 6.5+ (si pas déjà fait)
winget install Qt.OnlineInstaller

# Installer CMake
winget install Kitware.CMake

# Installer Python 3.11+
winget install Python.Python.3.11

# Installer Visual Studio Build Tools
winget install Microsoft.VisualStudio.2022.BuildTools
```

### 3. 🏗️ Compilation rapide (Mode développement)

```bash
# 1. Créer le dossier de build
mkdir build
cd build

# 2. Configurer CMake
cmake .. -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTS=ON

# 3. Compiler (utilise tous les CPU)
cmake --build . --parallel

# 4. Tester la compilation
ctest --output-on-failure
```

### 4. 🎯 Test rapide des modules

```bash
# Tester l'application de base
cd build
./RaspberryAssistant --test-mode

# Tester le service Claude Python
cd ../python
python claude_service.py --test

# Tester la synthèse vocale Henri (si configurée)
cd ../build
./test_microsoft_tts "Bonjour, je suis Henri, votre assistant!"
```

### 5. 🏠 Première exécution

```bash
# Mode développement avec debug
export QT_LOGGING_RULES="*=true"
./RaspberryAssistant --debug

# Ou mode normal
./RaspberryAssistant
```

## 🎮 Fonctionnalités à tester immédiatement

### Interface QML
- [ ] Interface tactile 5 vues
- [ ] Contrôle vocal permanent
- [ ] Notifications intelligentes
- [ ] Widgets de contrôle rapide

### Claude Haiku
- [ ] "Bonjour Claude, présente-toi"
- [ ] "Quelle heure est-il ?"
- [ ] "Raconte-moi l'état du système"

### Microsoft Henri TTS (si configuré)
- [ ] Test voix Henri en français
- [ ] Émotions : joyeux, sérieux, affectueux
- [ ] Cache audio intelligent

### EZVIZ Domotique (si configuré)
- [ ] "Montre-moi les caméras"
- [ ] "Allume les lumières du salon"
- [ ] "Active le mode sécurité"

### Designer 3D
- [ ] Visualisation 3D d'une pièce
- [ ] Placement de meubles
- [ ] Navigation immersive

### Streaming Musical (si configuré)
- [ ] "Joue ma playlist du matin"
- [ ] Contrôle Spotify/Tidal
- [ ] Audio multi-room

### Services Google (si configuré)
- [ ] "Quels sont mes emails ?"
- [ ] "Ajoute un événement au calendrier"
- [ ] "Navigue vers le bureau"

## 🐛 Résolution des problèmes courants

### Compilation échoue
```bash
# Vérifier les dépendances Qt
qmake --version
cmake --version

# Nettoyer et recompiler
rm -rf build/*
cmake .. -DCMAKE_BUILD_TYPE=Debug
make clean && make -j4
```

### Service Claude ne démarre pas
```bash
# Vérifier la clé API
echo $ANTHROPIC_API_KEY

# Tester la connectivité
curl -H "x-api-key: $ANTHROPIC_API_KEY" https://api.anthropic.com/v1/messages

# Logs détaillés
python claude_service.py --debug
```

### Interface QML ne s'affiche pas
```bash
# Mode debug Qt
export QT_LOGGING_RULES="qt.qml*=true"
./RaspberryAssistant

# Tester QML seul
qmlscene qml/main.qml
```

## 📈 Prochaines étapes de développement

1. **Tests complets** de chaque module
2. **Optimisation** pour Raspberry Pi 5
3. **Déploiement** sur hardware réel
4. **Personnalisation** des fonctionnalités
5. **Tests utilisateur** et feedback

---

**🎯 Objectif : Avoir un assistant domotique fonctionnel en 30 minutes !**