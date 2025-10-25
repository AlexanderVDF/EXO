# 🎤 Guide des Commandes Vocales - Assistant Henri

## 🎯 Mot d'Activation : "Exo"

### 🔊 Fonctionnement
1. **Démarrage écoute** : Cliquez sur "🎤 Écouter" dans l'interface
2. **Activation** : Dites "Exo" clairement
3. **Commande** : Énoncez votre demande après la confirmation
4. **Réponse** : Henri traite avec Claude et répond vocalement

### 📱 Interface Utilisateur

#### Indicateurs de Statut
- 🟢 **Claude IA** : API Claude opérationnelle
- 🟢 **Voice 'Exo'** : Système vocal actif
- 🔴 **Rouge** : Service non disponible

#### Contrôles Vocaux
- **🎤 Écouter** : Active la reconnaissance du mot "Exo"
- **🔴 Arrêter** : Désactive l'écoute vocale
- **État affiché** : 
  - 💤 En attente
  - 👂 En écoute du mot 'Exo'...
  - 🗣️ Henri parle...

### 🗣️ Exemples de Commandes

#### Domotique
- "Exo, allume les lumières du salon"
- "Exo, quelle est la température ?"
- "Exo, éteins la musique"

#### Information
- "Exo, quel temps fait-il ?"
- "Exo, raconte-moi une blague"
- "Exo, dis bonjour Claude"

#### Système
- "Exo, quel est ton statut ?"
- "Exo, peux-tu m'aider ?"
- "Exo, arrête l'écoute"

### 🛠️ Mode Développement

#### Simulation Reconnaissance
- La détection "Exo" est simulée (1 chance sur 3)
- Les commandes sont générées aléatoirement pour les tests
- Les réponses TTS sont simulées avec durée calculée

#### Logs Debug
```
🎤 Début d'écoute pour le mot d'activation: Exo
🎯 Parole détectée, écoute du mot d'activation...
🎉 Mot d'activation 'Exo' détecté !
📤 Envoi audio pour reconnaissance vocale (xxxx bytes)
🧠 Traitement de la reconnaissance vocale...
✅ Commande reconnue: [commande]
🎯 Commande vocale reçue: [commande]
🗣️ Henri répond: [réponse Claude]
🗣️ TTS terminé, reprise de l'écoute...
```

### 🔧 Configuration Technique

#### Format Audio
- **Fréquence** : 16 kHz
- **Canaux** : Mono (1 canal)
- **Format** : 16-bit PCM
- **Seuil parole** : 1000 (ajustable)

#### Timeouts
- **Enregistrement max** : 5 secondes
- **Silence après "Exo"** : 500ms
- **Redémarrage après TTS** : 500ms

#### API Intégration
- **Reconnaissance** : Google Speech-to-Text / Azure (simulé)
- **Synthèse** : Azure TTS Henri (simulé)
- **IA** : Claude Haiku (opérationnel)

### 🚀 Évolutions Prévues

#### Reconnaissance Vocale Réelle
1. **Porcupine** pour détection "Exo"
2. **Whisper** pour reconnaissance générale
3. **VAD** (Voice Activity Detection) avancé

#### Synthèse Vocale Premium
1. **Azure TTS Henri** avec voix française naturelle
2. **Émotions** dans les réponses
3. **Vitesse/ton ajustables**

#### Commandes Avancées
1. **Contrôle domotique** direct (Philips Hue, Nest)
2. **Musique** (Spotify, Deezer)
3. **Agenda** et rappels
4. **Smart home routines**

### 🔍 Dépannage

#### Problèmes Courants
- **Pas de microphone** : Vérifier les périphériques audio
- **"Exo" non détecté** : Parler plus fort et distinctement
- **Pas de réponse** : Vérifier la connexion Claude API
- **Audio coupé** : Vérifier les permissions microphone

#### Commandes de Test
```powershell
# Test API Claude
python test_claude.py

# Lancement avec debug
.\RaspberryAssistant.exe --debug

# Vérification audio
.\RaspberryAssistant.exe --list-audio
```

---
*Assistant Henri - Version Commandes Vocales 1.0*  
*Mot d'activation : "Exo" - IA : Claude Haiku - Interface : Qt Material Design*