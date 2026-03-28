> 🧭 [Index](../README.md) → [Prompts](../README.md#-prompts-historiques--prompts) → prompt_design_system.md

---

# 🎨 Prompt Maître — Implémentation Complète du Design System EXO
### (Copilot = Architecte UI/UX Senior + Refactor QML — Exécution Immédiate)

Tu es désormais chargé **d’implémenter intégralement** le Design System EXO dans le projet QML existant.
Tu dois appliquer **toutes les règles**, **tous les tokens**, **tous les composants**, **toutes les structures**,
**toutes les guidelines** définies dans le Design System EXO.

Tu dois agir comme un **Architecte UI/UX Senior** + **Ingénieur QML expérimenté**, et effectuer une **migration
complète**, propre, cohérente, premium.

Tu dois :

- créer les fichiers nécessaires
- refactorer les fichiers existants
- remplacer les anciens composants
- appliquer les tokens du thème
- moderniser toute l’interface
- nettoyer les styles obsolètes
- restructurer `/gui`
- ajouter les animations
- unifier les icônes
- corriger les marges, paddings, alignements
- moderniser la navigation
- moderniser les pages
- moderniser les contrôles
- moderniser les dialogues
- moderniser les panneaux
- moderniser les états pipeline
- moderniser les feedbacks
- moderniser les interactions

Tu dois **tout faire automatiquement**, sans demander confirmation.

---

# 1. 📁 Structure QML — À Créer / Réorganiser

Réorganise `/gui` comme suit :

```
/gui
  /components
  /controls
  /panels
  /pages
  /theme
  /icons
  /animations
  main.qml
```

Déplace les fichiers existants dans les bons dossiers.
Supprime les doublons.
Supprime les composants obsolètes.

---

# 2. 🎨 Theme.qml — À Créer et Appliquer

Crée :

```
/gui/theme/Theme.qml
```

Il doit contenir **tous les tokens** du Design System EXO :

- couleurs
- typographies
- radius
- ombres
- espacements
- animations
- fonctions utilitaires
- export des tokens

Tous les composants doivent utiliser `Theme.xxx`.

---

# 3. 🧩 Composants EXO — À Créer et Utiliser

Crée les composants suivants dans `/gui/components` :

- `ExoButton.qml`
- `ExoCard.qml`
- `ExoDialog.qml`
- `ExoTextField.qml`
- `ExoSidebar.qml`
- `ExoSidebarItem.qml`
- `ExoToast.qml`
- `ExoBadge.qml`
- `ExoStatusPill.qml`
- `ExoProgressBar.qml`
- `ExoPanel.qml`
- `ExoSectionHeader.qml`

Crée les composants spécifiques EXO :

- `ExoPipelineStatus.qml`
- `ExoServiceStatus.qml`
- `ExoWaveform.qml`
- `ExoMicButton.qml`
- `ExoLatencyIndicator.qml`
- `ExoWakewordIndicator.qml`

Tous doivent utiliser le thème, les tokens, les animations, les ombres, les radius.

---

# 4. 🧼 Migration de L’ui Existante

Pour **tous les fichiers QML existants** :

- remplace les anciens boutons → `ExoButton`
- remplace les anciens champs texte → `ExoTextField`
- remplace les anciens panels → `ExoPanel`
- remplace les anciens dialogues → `ExoDialog`
- remplace les anciens headers → `ExoSectionHeader`
- remplace les anciens toasts → `ExoToast`
- remplace les anciens indicateurs → `ExoStatusPill`
- remplace les anciens sliders → version moderne
- remplace les anciens switches → version moderne
- remplace les anciens icônes → Fluent System Icons

Nettoie :

- styles inline
- couleurs hardcodées
- radius hardcodés
- marges incohérentes
- paddings irréguliers
- composants dupliqués
- assets non utilisés

---

# 5. ✨ Modernisation Visuelle

Applique :

- palette sombre VS Code / Fluent
- typographie Inter
- radius 6–8 px
- ombres Fluent
- animations InOutCubic
- transitions de pages
- hover states
- pressed states
- micro‑interactions
- feedback pipeline animé
- waveform fluide
- mic button animé
- toasts modernes
- dialogues avec blur

---

# 6. 🧠 Modernisation UX

Applique les règles :

- hiérarchie visuelle
- structure header → contenu → actions
- sidebar moderne
- navigation cohérente
- feedback erreurs / succès
- affichage pipeline clair
- affichage services clair
- affichage latence clair
- affichage wakeword clair

---

# 7. 🧪 Vérification Finale

Vérifie :

- cohérence des couleurs
- cohérence des espacements
- cohérence des icônes
- cohérence des composants
- cohérence des animations
- cohérence des pages
- cohérence des états pipeline
- cohérence des dialogues
- cohérence des inputs
- cohérence des panels
- cohérence des sections

Corrige tout ce qui n’est pas conforme.

---

# 🎯 Objectif Final

Transformer l’interface EXO en un assistant :

- moderne
- fluide
- cohérent
- élégant
- premium
- professionnel
- aligné VS Code + Fluent Design
- basé sur un Design System complet
- avec des composants réutilisables
- avec une architecture UI propre
- avec une UX claire et robuste

Tu dois **implémenter tout cela immédiatement**, dans tous les fichiers QML concernés, sans demander confirmation.

---

# 🟦 Fin du Prompt — Implémentation du Design System EXO

---
*Retour à l'index : [docs/README.md](../README.md)*
