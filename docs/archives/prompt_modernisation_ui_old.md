> 🧭 [Index](../README.md) → [Prompts](../README.md#-prompts-historiques--prompts) → prompt_modernisation_ui.md

---

# 🎨 Prompt Maître — Plan Complet de Modernisation Visuelle EXO
### (Copilot = Architecte UI/UX Senior — Modernisation Premium)

<!-- TOC -->
## Table des matières

- [1. 🎛️ Refonte de la structure visuelle (layout & hiérarchie)](#1-refonte-de-la-structure-visuelle-layout-hiérarchie)
  - [Objectif](#objectif)
  - [Actions](#actions)
    - [1.1 Grille globale](#11-grille-globale)
    - [1.2 Paddings unifiés](#12-paddings-unifiés)
    - [1.3 Structure principale](#13-structure-principale)
    - [1.4 Hiérarchie visuelle](#14-hiérarchie-visuelle)
- [2. 🎨 Palette de couleurs moderne (VS Code + Fluent)](#2-palette-de-couleurs-moderne-vs-code-fluent)
  - [Objectif](#objectif)
  - [Thème sombre (par défaut)](#thème-sombre-par-défaut)
  - [Thème clair (optionnel)](#thème-clair-optionnel)
- [3. 🖼️ Typographie premium](#3-typographie-premium)
  - [Objectif](#objectif)
  - [Police recommandée](#police-recommandée)
  - [Hiérarchie](#hiérarchie)
- [4. 🧩 Composants QML modernisés](#4-composants-qml-modernisés)
  - [Objectif](#objectif)
  - [Composants à moderniser](#composants-à-moderniser)
    - [4.1 Boutons](#41-boutons)
    - [4.2 Cards](#42-cards)
    - [4.3 Sliders](#43-sliders)
    - [4.4 Switches](#44-switches)
    - [4.5 Dialogues](#45-dialogues)
- [5. ✨ Animations & micro‑interactions](#5-animations-microinteractions)
  - [Objectif](#objectif)
  - [Animations recommandées](#animations-recommandées)
    - [5.1 Transitions de pages](#51-transitions-de-pages)
    - [5.2 Hover states](#52-hover-states)
    - [5.3 Feedback pipeline](#53-feedback-pipeline)
    - [5.4 Notifications](#54-notifications)
- [6. 🔍 Icônes & symbolique](#6-icônes-symbolique)
  - [Objectif](#objectif)
  - [Pack recommandé](#pack-recommandé)
  - [Icônes à remplacer](#icônes-à-remplacer)
- [7. 🧠 Améliorations UX majeures](#7-améliorations-ux-majeures)
  - [7.1 Panneau d’état pipeline](#71-panneau-détat-pipeline)
  - [7.2 Mode debug visuel](#72-mode-debug-visuel)
  - [7.3 Mode test pipeline](#73-mode-test-pipeline)
- [8. 🧱 Architecture UI modernisée](#8-architecture-ui-modernisée)
  - [Objectif](#objectif)
  - [Structure recommandée](#structure-recommandée)
    - [8.1 Séparer clairement](#81-séparer-clairement)
    - [8.2 Centraliser le thème](#82-centraliser-le-thème)
- [9. 🧪 Tests visuels & polish final](#9-tests-visuels-polish-final)
  - [Checklist finale](#checklist-finale)
- [Objectif final](#objectif-final)
- [Fin du Prompt — Modernisation Visuelle EXO](#fin-du-prompt-modernisation-visuelle-exo)

<!-- /TOC -->

Tu es désormais **Architecte UI/UX Senior** chargé de transformer l’interface d’EXO en un **assistant premium moderne**,
inspiré de **VS Code**, **Fluent Design**, **Copilot**, et des standards UI 2026.

Ton rôle : **analyser, proposer, refactorer, moderniser**, et produire une interface **cohérente, élégante, fluide,
premium**, en QML.

Tu dois appliquer ce plan **sans rien oublier**, **sans demander confirmation**, et produire des recommandations +
composants + structure + thèmes.

---

# 1. 🎛️ Refonte de la structure visuelle (layout & hiérarchie)

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
- H1 : 24 px
- H2 : 20 px
- H3 : 16 px
- Texte : 14–15 px
- Labels : 12–13 px

---

# 2. 🎨 Palette de couleurs moderne (VS Code + Fluent)

## Objectif
Créer une identité visuelle cohérente, moderne, premium.

## Thème sombre (par défaut)
- Fond principal : #1E1E1E
- Panneaux : #252526
- Surfaces élevées : #2D2D2D
- Accent : #0078D4
- Accent secondaire : #3A96DD
- Texte principal : #FFFFFF
- Texte secondaire : #C8C8C8
- Bordures : #3C3C3C

## Thème clair (optionnel)
- Fond : #F3F3F3
- Surfaces : #FFFFFF
- Accent : #0067C0
- Texte : #1A1A1A

---

# 3. 🖼️ Typographie premium

## Objectif
Donner un aspect professionnel, lisible, moderne.

## Police recommandée
**Inter** (VS Code, Linear, Vercel, Notion)

## Hiérarchie
- H1 : 24 px semi‑bold
- H2 : 20 px medium
- H3 : 16 px medium
- Texte : 14–15 px
- Labels : 12–13 px

---

# 4. 🧩 Composants QML modernisés

## Objectif
Remplacer les composants bruts par des versions modernes, élégantes, cohérentes.

## Composants à moderniser
### 4.1 Boutons
- Coins arrondis 6 px
- Hover subtil
- Pressed (scale 0.98)
- Icône + label alignés

### 4.2 Cards
- Ombre douce Fluent
- Padding 16–20 px
- Coins arrondis 8 px
- Animation d’apparition

### 4.3 Sliders
- Track fin
- Thumb rond
- Glow léger au hover

### 4.4 Switches
- Style Fluent
- Animation 150 ms

### 4.5 Dialogues
- Fond blur (Gaussian 20–30)
- Ombre profonde
- Boutons alignés à droite

---

# 5. ✨ Animations & micro‑interactions

## Objectif
Donner vie à l’interface sans la surcharger.

## Animations recommandées
### 5.1 Transitions de pages
- Fade 120 ms
- Slide 80 px
- Easing InOutCubic

### 5.2 Hover states
- Opacity +3%
- Glow léger

### 5.3 Feedback pipeline
- Micro animé
- VAD : cercle pulsant
- STT : waveform fluide
- TTS : barre de progression subtile

### 5.4 Notifications
- Slide‑in bottom
- Fade‑out 300 ms

---

# 6. 🔍 Icônes & symbolique

## Objectif
Unifier toutes les icônes pour un rendu professionnel.

## Pack recommandé
**Fluent System Icons** (SVG)

## Icônes à remplacer
- Micro
- Paramètres
- Logs
- Pipeline
- Services
- Wakeword
- VAD
- STT
- TTS

---

# 7. 🧠 Améliorations UX majeures

## 7.1 Panneau d’état pipeline
Afficher :
- Wakeword
- VAD
- STT
- TTS
- Claude
- GPU
- Latence

## 7.2 Mode debug visuel
- États pipeline
- WebSockets
- Erreurs
- Modèles chargés

## 7.3 Mode test pipeline
- Test wakeword
- Test VAD
- Test STT
- Test TTS
- Test pipeline complet

---

# 8. 🧱 Architecture UI modernisée

## Objectif
Préparer EXO pour une UI modulaire, scalable, maintenable.

## Structure recommandée
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

### 8.1 Séparer clairement
- Composants réutilisables
- Pages
- Thème
- Animations
- Icônes

### 8.2 Centraliser le thème
Créer :
```
/gui/theme/Theme.qml
```

Avec :
- couleurs
- typographies
- ombres
- espacements
- radius
- animations

---

# 9. 🧪 Tests visuels & polish final

## Checklist finale
- Alignements parfaits
- Marges cohérentes
- Icônes homogènes
- Animations fluides
- Pas de jitter
- Pas de clipping
- Pas de composants bruts
- Pas de couleurs incohérentes
- Pas de texte non aligné
- Pas de padding irrégulier

---

# 🎯 Objectif final

Transformer EXO en un assistant :

- moderne
- fluide
- cohérent
- élégant
- premium
- digne d’un produit commercial
- aligné VS Code + Fluent Design

---

# 🟦 Fin du Prompt — Modernisation Visuelle EXO

---
*Retour à l'index : [docs/README.md](../README.md)*
