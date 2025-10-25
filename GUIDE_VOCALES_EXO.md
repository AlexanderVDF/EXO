# 🎙️ Guide Commandes Vocales - Assistant Henri

## 🎯 Activation Vocale "Exo"

### 🔊 Mot d'activation
**"Exo"** - Prononcez clairement pour activer l'assistant

### 📱 Interface Utilisateur

#### Contrôles Vocaux
- **🎤 Bouton Écoute** : Active/désactive la reconnaissance vocale
- **🔊 Bouton Parole** : Active/désactive la synthèse vocale
- **Indicateur statut** : Voyant vert = actif, rouge = inactif

#### États Visuels
- **🟢 Écoute active** : "Dites 'Exo' pour commencer..."
- **🟡 Enregistrement** : "Parlez maintenant..."
- **🟠 Traitement** : "Henri analyse votre demande..."
- **🟣 Réponse** : Henri parle et affiche la réponse

## 🗣️ Exemples de Commandes

### 🏠 Commandes Domotiques
```
"Exo, allume les lumières du salon"
"Exo, règle la température à 21 degrés"
"Exo, lance ma playlist détente"
"Exo, ferme les volets de la chambre"
```

### 💬 Chat avec Claude
```
"Exo, parle-moi de la météo"
"Exo, raconte-moi une blague"
"Exo, aide-moi à organiser ma journée"
"Exo, explique-moi l'IoT simplement"
```

### ⚙️ Contrôles Système
```
"Exo, quel est ton statut ?"
"Exo, arrête l'écoute"
"Exo, recommence"
"Exo, mode silencieux"
```

## 🔧 Configuration Technique

### 📊 Paramètres Audio
- **Fréquence d'échantillonnage** : 16 kHz
- **Format** : PCM 16 bits mono
- **Seuil de silence** : 500ms
- **Durée max** : 5 secondes

### 🤖 IA Intégrées
- **Claude Haiku** : Traitement langage naturel
- **Azure TTS Henri** : Synthèse vocale française
- **Reconnaissance vocale** : Engine Windows/Qt

### 🎛️ Réglages Disponibles

#### Sensibilité Microphone
```cpp
// Dans VoiceManager
setVolume(0.8f);        // 80% sensibilité
setThreshold(0.3f);     // Seuil de détection
```

#### Vitesse de Parole
```cpp
// Dans TTS
setSpeechRate(0.5f);    // Vitesse normale
setPitch(0.0f);         // Ton neutre
```

## 🚀 Utilisation Pratique

### 📋 Séquence Typique
1. **👀 Vérifiez** l'indicateur vert "En ligne"
2. **🎤 Cliquez** "Démarrer Écoute" 
3. **🗣️ Dites** "Exo" clairement
4. **⏱️ Attendez** le signal sonore
5. **💬 Parlez** votre commande naturellement
6. **👂 Écoutez** la réponse d'Henri

### ⚡ Raccourcis Interface
- **Espace** : Toggle écoute on/off
- **Enter** : Envoyer message écrit
- **Boutons emoji** : Commandes rapides (💡🌡️🏠)

## 🔍 Dépannage

### ❌ Problèmes Fréquents

#### "Exo ne m'entend pas"
- ✅ Vérifiez le microphone (paramètres Windows)
- ✅ Rapprochez-vous du micro (< 1 mètre)
- ✅ Parlez plus fort et articulez
- ✅ Redémarrez l'application

#### "Henri ne répond pas vocalement"
- ✅ Vérifiez les haut-parleurs
- ✅ Volume système > 50%
- ✅ Bouton "Parole" activé (vert)
- ✅ Patience (traitement 1-3s)

#### "Commandes non reconnues"
- ✅ Toujours commencer par "Exo"
- ✅ Phrases simples et claires
- ✅ Éviter le bruit ambiant
- ✅ Accent français standard

### 🐛 Mode Debug
Lancez avec debug pour voir les logs :
```powershell
.\RaspberryAssistant.exe --debug --verbose
```

## 📈 Performances

### 🎯 Temps de Réponse
- **Détection "Exo"** : < 500ms
- **Reconnaissance** : 1-2 secondes  
- **Traitement Claude** : 2-4 secondes
- **Synthèse vocale** : 1-2 secondes
- **Total moyen** : 4-8 secondes

### 💾 Ressources
- **RAM utilisée** : ~80 MB
- **CPU (écoute)** : 5-10%
- **CPU (traitement)** : 20-40%
- **Réseau** : 10-50 KB/requête

---
*Assistant Henri avec Claude IA - Commandes Vocales "Exo"*  
*Version 1.0 - Octobre 2025*