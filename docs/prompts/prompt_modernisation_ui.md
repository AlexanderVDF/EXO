> 🧭 [Index](../README.md) → [Prompts](../README.md#-prompts-historiques--prompts) → prompt_modernisation_ui.md

---


# 🎨 Prompt Maître — Modernisation Visuelle & Design System EXO
### (Copilot = Architecte UI/UX Senior + Ingénieur QML — Exécution Immédiate)

> ℹ️ Ce document fusionne le plan de modernisation visuelle et le prompt d'implémentation du Design System EXO.
> Référence associée : [design_system.md](../ui/design_system.md) (documentation complète des tokens et spécifications)

<!-- TOC -->
## Table des matières

- [1. 🎛️ Refonte de la structure visuelle](#1-refonte-de-la-structure-visuelle)
  - [Objectif](#objectif)
  - [Actions](#actions)
    - [1.1 Grille globale](#11-grille-globale)
    - [1.2 Paddings unifiés](#12-paddings-unifiés)
    - [1.3 Structure principale](#13-structure-principale)
    - [1.4 Hiérarchie visuelle](#14-hiérarchie-visuelle)
- [2. 🎨 Palette de couleurs moderne](#2-palette-de-couleurs-moderne)
  - [Objectif](#objectif)
  - [Thème sombre (par défaut)](#thème-sombre-par-défaut)
  - [Thème clair (optionnel)](#thème-clair-optionnel)
- [3. 🖼️ Typographie premium](#3-typographie-premium)
  - [Police recommandée](#police-recommandée)
  - [Hiérarchie](#hiérarchie)
- [4. 📁 Structure QML — À créer](#4-structure-qml-à-créer)
- [5. 🎨 Theme.qml](#5-themeqml)
- [6. 🧩 Composants EXO — À créer](#6-composants-exo-à-créer)
    - [Composants de base (`/gui/components`)](#composants-de-base-guicomponents)
    - [Composants spécifiques EXO](#composants-spécifiques-exo)
    - [Contrôles (`/gui/controls`)](#contrôles-guicontrols)
- [7. 🧼 Migration de l'UI existante](#7-migration-de-lui-existante)
    - [Remplacements](#remplacements)
    - [Nettoyage](#nettoyage)
- [8. ✨ Animations & micro-interactions](#8-animations-micro-interactions)
    - [8.1 Transitions de pages](#81-transitions-de-pages)
    - [8.2 Hover states](#82-hover-states)
    - [8.3 Feedback pipeline](#83-feedback-pipeline)
    - [8.4 Notifications](#84-notifications)
- [9. 🔍 Icônes & symbolique](#9-icônes-symbolique)
  - [Pack recommandé](#pack-recommandé)
  - [Icônes à remplacer](#icônes-à-remplacer)
- [10. 🧠 Améliorations UX majeures](#10-améliorations-ux-majeures)
    - [10.1 Panneau d'état pipeline](#101-panneau-détat-pipeline)
    - [10.2 Mode debug visuel](#102-mode-debug-visuel)
    - [10.3 Mode test pipeline](#103-mode-test-pipeline)
- [11. 🧪 Vérification finale](#11-vérification-finale)
  - [Checklist](#checklist)
- [Objectif final](#objectif-final)
- [Fin du Prompt — Modernisation Visuelle & Design System EXO](#fin-du-prompt-modernisation-visuelle-design-system-exo)

<!-- /TOC -->

Tu es désormais **Architecte UI/UX Senior** + **Ingénieur QML expérimenté** chargé de transformer l'interface d'EXO en
un **assistant premium moderne**, inspiré de **VS Code**, **Fluent Design**, **Copilot**, et des standards UI 2026.

Tu dois :

- **Implémenter intégralement** le Design System EXO dans le projet QML existant
- Appliquer **toutes les règles**, **tous les tokens**, **tous les composants**, **toutes les guidelines**
- Effectuer une **migration complète**, propre, cohérente, premium
- Agir **sans demander confirmation** — tout faire automatiquement

---

# 1. 🎛️ Refonte de la structure visuelle

## Objectif
Créer une ossature visuelle premium, lisible, moderne.

## Actions

### 1.1 Grille globale
- Marges horizontales : 24 px
- Marges verticales : 20 px
- Espacement interne : 12–16 px
- Grille 8 px

### 1.2 Paddings unifiés
- Boutons : 10–14 px
- Cards : 16–20 px
- Sections : 24 px

### 1.3 Structure principale
- Sidebar fixe (icônes + labels)
- Zone centrale fluide
- Header minimaliste
- Footer optionnel (état pipeline, latence, GPU, micro)

### 1.4 Hiérarchie visuelle
- H1 : 24 px semi-bold
- H2 : 20 px medium
- H3 : 16 px medium
- Texte : 14–15 px
- Labels : 12–13 px

---

# 2. 🎨 Palette de couleurs moderne

## Objectif
Créer une identité visuelle cohérente, moderne, premium.

## Thème sombre (par défaut)
- Fond principal : #1E1E1E
- Panneaux : #252526
- Surfaces élevées : #2D2D2D
- Accent : #0078D4
- Accent secondaire : #3A96DD
- Texte principal : #E0E0E0
- Texte secondaire : #A0A0A0
- Bordures : #3C3C3C

## Thème clair (optionnel)
- Fond : #F3F3F3
- Surfaces : #FFFFFF
- Accent : #0067C0
- Texte : #1A1A1A

> 📋 Palette complète (sémantique, pipeline, états vocaux, splash) : voir [design_system.md](../ui/design_system.md#11-couleurs-thème-sombre)

---

# 3. 🖼️ Typographie premium

## Police recommandée
**Inter** (VS Code, Linear, Vercel, Notion)

## Hiérarchie
- H1 : 24 px semi-bold
- H2 : 20 px medium
- H3 : 16 px medium
- Texte : 14–15 px
- Labels : 12–13 px

---

# 4. 📁 Structure QML — À créer

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

# 5. 🎨 Theme.qml

Crée `/gui/theme/Theme.qml` contenant **tous les tokens** du Design System EXO :

- Couleurs (fond, accent, texte, bordures, sémantique, pipeline, états vocaux)
- Typographies (familles, tailles, poids)
- Radius (6–8 px standard, 12 px cards)
- Ombres Fluent (subtle, default, heavy)
- Espacements (grille 8 px)
- Animations (durées, easings)
- Fonctions utilitaires

Tous les composants doivent utiliser `Theme.xxx`.

---

# 6. 🧩 Composants EXO — À créer

### Composants de base (`/gui/components`)

| Composant | Description |
|-----------|-------------|
| `ExoButton.qml` | Coins arrondis 6 px, hover subtil, pressed (scale 0.98), icône + label |
| `ExoCard.qml` | Ombre douce Fluent, padding 16–20 px, coins arrondis 8 px, animation apparition |
| `ExoDialog.qml` | Fond blur (Gaussian 20–30), ombre profonde, boutons alignés à droite |
| `ExoTextField.qml` | Champs de saisie avec focus ring accent |
| `ExoSidebar.qml` | Navigation latérale fixe |
| `ExoSidebarItem.qml` | Élément de sidebar avec icône + label |
| `ExoToast.qml` | Notification slide-in bottom, fade-out 300 ms |
| `ExoBadge.qml` | Badge de statut |
| `ExoStatusPill.qml` | Indicateur d'état (success/warning/error/info) |
| `ExoProgressBar.qml` | Barre de progression |
| `ExoPanel.qml` | Panneau générique avec bordure et header |
| `ExoSectionHeader.qml` | Header de section |

### Composants spécifiques EXO

| Composant | Description |
|-----------|-------------|
| `ExoPipelineStatus.qml` | Affichage état pipeline complet |
| `ExoServiceStatus.qml` | Affichage état d'un service |
| `ExoWaveform.qml` | Waveform fluide |
| `ExoMicButton.qml` | Bouton micro animé |
| `ExoLatencyIndicator.qml` | Indicateur de latence |
| `ExoWakewordIndicator.qml` | Indicateur de wake word |

### Contrôles (`/gui/controls`)

| Composant | Description |
|-----------|-------------|
| Sliders | Track fin, thumb rond, glow léger au hover |
| Switches | Style Fluent, animation 150 ms |

---

# 7. 🧼 Migration de l'UI existante

Pour **tous les fichiers QML existants** :

### Remplacements
- Anciens boutons → `ExoButton`
- Anciens champs texte → `ExoTextField`
- Anciens panels → `ExoPanel`
- Anciens dialogues → `ExoDialog`
- Anciens headers → `ExoSectionHeader`
- Anciens toasts → `ExoToast`
- Anciens indicateurs → `ExoStatusPill`
- Anciens sliders → version moderne
- Anciens switches → version moderne
- Anciens icônes → Fluent System Icons

### Nettoyage
- Styles inline
- Couleurs hardcodées
- Radius hardcodés
- Marges incohérentes
- Paddings irréguliers
- Composants dupliqués
- Assets non utilisés

---

# 8. ✨ Animations & micro-interactions

### 8.1 Transitions de pages
- Fade 120 ms
- Slide 80 px
- Easing InOutCubic

### 8.2 Hover states
- Opacity +3%
- Glow léger

### 8.3 Feedback pipeline
- Micro animé
- VAD : cercle pulsant
- STT : waveform fluide
- TTS : barre de progression subtile

### 8.4 Notifications
- Slide-in bottom
- Fade-out 300 ms

---

# 9. 🔍 Icônes & symbolique

## Pack recommandé
**Fluent System Icons** (SVG)

## Icônes à remplacer
- Micro, Paramètres, Logs, Pipeline, Services, Wakeword, VAD, STT, TTS

---

# 10. 🧠 Améliorations UX majeures

### 10.1 Panneau d'état pipeline
Afficher : Wakeword, VAD, STT, TTS, Claude, GPU, Latence

### 10.2 Mode debug visuel
États pipeline, WebSockets, Erreurs, Modèles chargés

### 10.3 Mode test pipeline
Test wakeword, Test VAD, Test STT, Test TTS, Test pipeline complet

---

# 11. 🧪 Vérification finale

## Checklist
- Alignements parfaits
- Marges cohérentes
- Icônes homogènes
- Animations fluides
- Pas de jitter ni clipping
- Pas de composants bruts
- Pas de couleurs incohérentes
- Pas de texte non aligné
- Pas de padding irrégulier
- Cohérence : couleurs, espacements, composants, animations, pages, états pipeline, dialogues, inputs, panels, sections

---

# 🎯 Objectif final

Transformer EXO en un assistant :

- Moderne, fluide, cohérent, élégant, premium, professionnel
- Aligné VS Code + Fluent Design
- Basé sur un Design System complet
- Avec des composants réutilisables
- Avec une architecture UI propre
- Avec une UX claire et robuste

---

# 🟦 Fin du Prompt — Modernisation Visuelle & Design System EXO

---
*Retour à l'index : [docs/README.md](../README.md)*
