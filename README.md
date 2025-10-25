# 🤖 EXO - Assistant Personnel Intelligent

Un assistant personnel moderne avec intelligence artificielle intégrée, reconnaissance vocale "EXO" et fonctionnalités météo en temps réel.

![Qt 6.9.3](https://img.shields.io/badge/Qt-6.9.3-green?logo=qt)
![Claude Haiku](https://img.shields.io/badge/Claude-Haiku-blue?logo=anthropic)
![C++17](https://img.shields.io/badge/C++-17-blue?logo=cplusplus)
![Windows](https://img.shields.io/badge/Windows-11-blue?logo=windows)

## ✨ Fonctionnalités Actuelles

### 🧠 Intelligence Artificielle
- **Claude Haiku API** : IA conversationnelle rapide et efficace
- **Traitement langage naturel** : Compréhension contextuelle avancée
- **Réponses intelligentes** : Génération de texte naturel

### 🎙️ Reconnaissance Vocale
- **Mot d'activation "EXO"** : Détection automatique du mot clé
- **Microphone intégré** : Capture audio temps réel avec Qt Multimedia
- **Feedback audio** : Confirmation "Oui ?" lors de la détection
- **Synthèse vocale** : Qt TextToSpeech avec 3 voix françaises optimisées

### 🌤️ Météo Intelligente
- **OpenWeatherMap API** : Données météo temps réel Paris
- **Prévisions** : Températures actuelles et conseils vestimentaires
- **Mise à jour automatique** : Rafraîchissement toutes les 10 minutes
- **Commandes vocales** : "Henri, quel temps fait-il ?"

### 🎨 Interface Moderne
- **Material Design** : Interface QML moderne et responsive
- **Chat intégré** : Conversation fluide avec Claude
- **Contrôles vocaux** : Boutons démarrer/arrêter écoute
- **Feedback visuel** : Statuts temps réel et animations

## 🏗️ Architecture (Version Nettoyée)

```
Henri/
├── 📁 src/                    # Code source principal
│   ├── main.cpp              # Point d'entrée unifié
│   ├── assistantmanager.*   # Coordinateur simplifié
│   ├── claudeapi.*          # Interface Claude Haiku
│   ├── voicemanager.*       # Reconnaissance vocale "Exo"
│   └── weathermanager.*     # Gestionnaire météo
│
├── 📁 qml/                   # Interface utilisateur
│   └── main.qml             # Interface Material Design
│
├── 📁 config/                # Configuration
│   ├── assistant.conf       # Clés API et paramètres
│   └── assistant.conf.example
│
├── 📁 build/                 # Compilation
│   └── Release/
│       └── RaspberryAssistant.exe
│
├── 📁 modules_advanced/      # Modules futurs (désactivés)
│   ├── modules/              # Fonctionnalités avancées
│   ├── speechmanager.*      # Ancien gestionnaire vocal
│   └── systemmonitor.*      # Monitoring système
│
├── 📁 tests/                 # Tests et scripts
│   └── test_*.ps1           # Scripts de validation
│
└── 📁 scripts/               # Utilitaires et déploiement
    ├── install_*.ps1        # Installation automatique
    └── build_*.ps1          # Scripts de compilation
```

## 🚀 Démarrage Rapide

### Prérequis
- **Windows 11** avec PowerShell
- **Qt 6.9.3 MSVC 2022 x64** installé
- **CMake 3.16+** et **Visual Studio Build Tools**
- **Clés API** Claude et OpenWeatherMap

### Installation

1. **Clone et configuration**
```powershell
git clone <repository>
cd Henri
cp config/assistant.conf.example config/assistant.conf
# Éditer les clés API dans config/assistant.conf
```

2. **Compilation**
```powershell
cmake -B build -S .
cmake --build build --config Release
```

3. **Lancement**
```powershell
.\build\Release\RaspberryAssistant.exe
```

## 🎮 Utilisation

### Commandes Vocales
1. **Activation** : Dites "Exo" → Henri répond "Oui ?"
2. **Commande** : Posez votre question ou donnez une instruction
3. **Réponse** : Henri traite avec Claude et répond vocalement

### Exemples de Commandes
- "Henri, bonjour !"
- "Henri, comment allez-vous ?"
- "Henri, quel temps fait-il ?"
- "Henri, raconte-moi une blague"

### Interface Graphique
- **Chat en direct** avec Claude Haiku
- **Bouton Écouter** : Active/désactive la reconnaissance vocale
- **Messages** : Historique de conversation
- **Statut** : Indicateurs visuels d'activité

## ⚙️ Configuration

### Clés API (config/assistant.conf)
```ini
[Claude]
api_key=sk-ant-api03-...votre-clé...
model=claude-3-haiku-20240307
base_url=https://api.anthropic.com/v1/messages

[OpenWeatherMap]
api_key=...votre-clé...
city=Paris
update_interval=600000

[Voice]
wake_word=Exo
language=fr-FR
voice_rate=-0.3
voice_pitch=-0.1
voice_volume=0.9
```

### Paramètres Vocaux Optimisés
- **Rate**: -0.3 (parole plus lente et claire)
- **Pitch**: -0.1 (voix légèrement plus grave)
- **Volume**: 0.9 (volume élevé mais pas saturé)

## 🔧 Architecture Technique

### Composants Principaux

#### AssistantManager (simplifié)
- Coordination entre Claude API, Voice et Weather
- Gestion des connexions et signaux Qt
- Interface QML exposée

#### VoiceManager
- Détection du mot d'activation "Exo"
- Capture audio avec QAudioSource
- Synthèse avec Qt TextToSpeech
- Feedback "Oui ?" automatique

#### ClaudeAPI
- Communication HTTP avec Anthropic
- Gestion timeout et retry automatique
- Traitement JSON des réponses

#### WeatherManager
- Intégration OpenWeatherMap
- Cache et mise à jour automatique
- Conseils vestimentaires intelligents

### Technologies Utilisées
- **Qt 6.9.3** : Framework principal C++/QML
- **Qt Multimedia** : Capture et traitement audio
- **Qt TextToSpeech** : Synthèse vocale française
- **Qt Network** : Communications API REST
- **CMake** : Système de build moderne

## 🧪 Tests et Validation

### Scripts de Test
```powershell
# Test complet de l'environnement
.\tests\test_environment.ps1

# Test de compilation rapide
.\scripts\build_simple.ps1
```

### Debugging Vocal
- **Console Qt** : Messages détaillés de reconnaissance
- **Niveaux audio** : Affichage du volume microphone
- **États** : Suivi des transitions wake word → commande

## 🔮 Roadmap

### Version Actuelle (v2.0)
✅ Claude Haiku intégré et fonctionnel  
✅ Reconnaissance vocale "Exo" opérationnelle  
✅ Météo temps réel Paris avec conseils  
✅ Interface QML Material Design  
✅ Architecture nettoyée et optimisée  

### Prochaines Fonctionnalités
🔄 **Contrôle domotique** : Philips Hue, prises connectées  
🔄 **Streaming musical** : Spotify/Tidal integration  
🔄 **Agenda intelligent** : Google Calendar et rappels  
🔄 **Sécurité EZVIZ** : Surveillance caméras  
🔄 **Déploiement RPi5** : Version Raspberry Pi optimisée  

## 📝 Développement

### Structure de Code
- **C++ moderne** : Standards C++17, smart pointers
- **Qt patterns** : Signaux/slots, propriétés Q_PROPERTY
- **RAII** : Gestion automatique ressources
- **Threading** : Traitement asynchrone API

### Contributions
1. Fork le projet
2. Créer une branche feature
3. Tester les modifications
4. Soumettre une Pull Request

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

---

**Henri - Votre assistant personnel intelligent avec Claude Haiku** 🤖✨

*Développé avec ❤️ et Qt 6.9.3*