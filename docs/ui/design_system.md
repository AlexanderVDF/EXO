> 🧭 [Index](../README.md) → [Interface](../README.md#-interface--design--ui) → design_system.md

# 🎨 EXO Design System — Documentation Complète
> Documentation EXO v4.2 — Section : Interface
> Dernière mise à jour : Mars 2026

### v4.2 — Inspiré VS Code + Fluent Design + Copilot


<!-- TOC -->
## Table des matières

- [1. 🧱 Foundations — Tokens EXO](#1-foundations-tokens-exo)
  - [1.1 Couleurs (thème sombre)](#11-couleurs-thème-sombre)
    - [Fond](#fond)
    - [Accent](#accent)
    - [Texte](#texte)
    - [Bordures](#bordures)
    - [Sémantique (avec variantes hover/dim)](#sémantique-avec-variantes-hoverdim)
    - [Pipeline](#pipeline)
    - [États vocaux](#états-vocaux)
    - [Splash](#splash)
  - [1.2 Typographie](#12-typographie)
  - [1.3 Espacements (Grille 4/8 px)](#13-espacements-grille-48-px)
  - [1.4 Rayons de bord](#14-rayons-de-bord)
  - [1.5 Ombres (Fluent)](#15-ombres-fluent)
  - [1.6 Animations](#16-animations)
- [2. 🧩 Composants EXO — Kit Complet (19 composants)](#2-composants-exo-kit-complet-19-composants)
  - [2.1 Boutons](#21-boutons)
    - [`ExoButton`](#exobutton)
  - [2.2 Inputs](#22-inputs)
    - [`ExoTextField`](#exotextfield)
    - [`ExoSearchField`](#exosearchfield)
  - [2.3 Cards & Surfaces](#23-cards-surfaces)
    - [`ExoCard`](#exocard)
    - [`ExoPanelHeader`](#exopanelheader)
  - [2.4 Navigation](#24-navigation)
    - [`ExoTab`](#exotab)
  - [2.5 Contrôles](#25-contrôles)
    - [`ExoSwitch`](#exoswitch)
    - [`ExoSlider`](#exoslider)
  - [2.6 Feedback](#26-feedback)
    - [`ExoNotification` (Toast)](#exonotification-toast)
    - [`ExoBadge`](#exobadge)
    - [`ExoStatusPill`](#exostatuspill)
    - [`ExoProgressBar`](#exoprogressbar)
  - [2.7 Dialogues & Overlays](#27-dialogues-overlays)
    - [`ExoDialog`](#exodialog)
    - [`ExoConfirmDialog`](#exoconfirmdialog)
    - [`ExoSheet`](#exosheet)
  - [2.8 Composants spécifiques EXO](#28-composants-spécifiques-exo)
    - [`ExoPipelineStatus`](#exopipelinestatus)
    - [`ExoServiceStatus`](#exoservicestatus)
    - [`ExoMicButton`](#exomicbutton)
    - [`ExoWaveform`](#exowaveform)
- [3. 🎛️ Patterns D'interaction](#3-patterns-dinteraction)
  - [3.1 États pipeline — Couleurs & Animations](#31-états-pipeline-couleurs-animations)
  - [3.2 Feedback utilisateur](#32-feedback-utilisateur)
  - [3.3 Navigation](#33-navigation)
- [4. 🧠 Guidelines UX](#4-guidelines-ux)
    - [Quand utiliser quel bouton ?](#quand-utiliser-quel-bouton)
    - [Quand utiliser quel feedback ?](#quand-utiliser-quel-feedback)
    - [Structure d'une page](#structure-dune-page)
    - [Erreurs critiques](#erreurs-critiques)
- [5. 📁 Structure QML](#5-structure-qml)
- [6. 🎨 Theme.qml — Résumé](#6-themeqml-résumé)
- [7. 🧩 Composants QML — Inventaire (19)](#7-composants-qml-inventaire-19)
- [8. 🧪 Checklist Finale](#8-checklist-finale)

<!-- /TOC -->

# 1. 🧱 Foundations — Tokens EXO

## 1.1 Couleurs (thème sombre)

### Fond
| Token | Valeur | Usage |
|-------|--------|-------|
| `bgPrimary` | `#1E1E1E` | Fond principal de l'app |
| `bgSecondary` | `#252526` | Surfaces élevées (sidebar, panels) |
| `bgElevated` | `#2D2D2D` | Cards, dialogues, menus contextuels |
| `bgHover` | `#2A2D2E` | État hover des éléments interactifs |
| `bgActive` | `#37373D` | État pressed/sélectionné |
| `bgInput` | `#3C3C3C` | Fond des champs de saisie |

### Accent
| Token | Valeur | Usage |
|-------|--------|-------|
| `accent` | `#0078D4` | Couleur principale d'interaction |
| `accentLight` | `#3A96DD` | Variant claire (liens, surbrillance) |
| `accentDark` | `#005A9E` | État pressed |
| `accentHover` | `#1A86D9` | État hover |
| `accentActive` | `#094771` | Sélection de texte, focus ring dim |

### Texte
| Token | Valeur | Usage |
|-------|--------|-------|
| `textPrimary` | `#E0E0E0` | Texte principal |
| `textSecondary` | `#A0A0A0` | Texte secondaire, labels |
| `textMuted` | `#5A5A5A` | Placeholders, désactivé visuel |
| `textDisabled` | `#4A4A4A` | Éléments désactivés |
| `textAccent` | `#007ACC` | Titres de section, liens actifs |
| `textLink` | `#3A96DD` | Liens hypertexte |

### Bordures
| Token | Valeur | Usage |
|-------|--------|-------|
| `border` | `#3C3C3C` | Séparateurs, bordures standard |
| `borderLight` | `#505050` | Bordure élevée |
| `borderFocus` | `#007ACC` | Focus ring |
| `borderHover` | `#505050` | Bordure au hover |

### Sémantique (avec variantes hover/dim)
| Token | Valeur | Hover | Dim | Usage |
|-------|--------|-------|-----|-------|
| `success` | `#4EC9B0` | `#5FD4BC` | `#2E7A68` | OK, connecté, speaking |
| `warning` | `#DCDCAA` | `#E5E5BB` | `#8A8A5A` | Dégradé, processing |
| `error` | `#F44747` | `#F66A6A` | `#8B2020` | Erreur, déconnecté |
| `info` | `#569CD6` | `#6BADE0` | `#2D5273` | Information |

### Pipeline
| Token | Valeur | Usage |
|-------|--------|-------|
| `pipelineIdle` | `#3C3C3C` | En attente |
| `pipelineActive` | `#4EC9B0` | Actif |
| `pipelineProcessing` | `#DCDCAA` | En traitement |
| `pipelineError` | `#F44747` | Erreur |
| `pipelineUnavail` | `#5A5A5A` | Indisponible |

### États vocaux
| Token | Valeur | Usage |
|-------|--------|-------|
| `stateListening` | `#007ACC` | Écoute active |
| `stateTranscribing` | `#DCDCAA` | Transcription en cours |
| `stateThinking` | `#C586C0` | Réflexion IA |
| `stateSpeaking` | `#4EC9B0` | Synthèse vocale |
| `stateIdle` | `#5A5A5A` | Repos |

### Splash
| Token | Valeur |
|-------|--------|
| `splashBg` | `#1A1A2E` |
| `splashAccent` | `#E94560` |
| `splashPanel` | `#16213E` |

## 1.2 Typographie

| Style | Taille | Poids | Token |
|-------|--------|-------|-------|
| H1 | 24px | SemiBold (600) | `fontH1` |
| H2 | 20px | Medium (500) | `fontH2` |
| H3 | 16px | Medium (500) | `fontH3` |
| Body | 14px | Regular (400) | `fontBody` |
| Small | 13px | Regular (400) | `fontSmall` |
| Label | 12px | Medium (500) | `fontLabel` |
| Caption | 12px | Regular (400) | `fontCaption` |
| Micro | 11px | Regular (400) | `fontMicro` |
| Tiny | 10px | Regular (400) | `fontTiny` |

Polices :
- **Sans-serif** : `Inter, Segoe UI, Roboto, sans-serif`
- **Monospace** : `Cascadia Code, Fira Code, JetBrains Mono, Consolas`

## 1.3 Espacements (Grille 4/8 px)

| Token | Valeur |
|-------|--------|
| `spacing2` | 2px |
| `spacing4` | 4px |
| `spacing6` | 6px |
| `spacing8` | 8px |
| `spacing10` | 10px |
| `spacing12` | 12px |
| `spacing16` | 16px |
| `spacing20` | 20px |
| `spacing24` | 24px |
| `spacing32` | 32px |

Marges : `marginH: 24` · `marginV: 20` · `paddingBtn: 12` · `paddingCard: 16` · `paddingSection: 24`

## 1.4 Rayons de bord

| Token | Valeur | Usage |
|-------|--------|-------|
| `radiusSmall` | 4px | Inputs, tags |
| `radiusMedium` | 6px | Boutons, badges |
| `radiusLarge` | 8px | Cards, dialogues |
| `radiusXL` | 12px | Panneaux larges |
| `radiusRound` | 999px | Avatars, pills |

## 1.5 Ombres (Fluent)

| Niveau | Radius | Opacité | Usage |
|--------|--------|---------|-------|
| Small | 4px | 0.15 | Cards au repos |
| Medium | 8px | 0.20 | Cards hover, menus |
| Large | 16px | 0.30 | Dialogues, overlays |

## 1.6 Animations

| Token | Durée | Usage |
|-------|-------|-------|
| `animFast` | 80ms | Hover, color change |
| `animNormal` | 120ms | Transitions, toggles |
| `animSlow` | 200ms | Apparitions, dialogues |
| `animPage` | 150ms | Changements de page |

Easing par défaut : `Easing.OutCubic` (apparitions), `Easing.InOutCubic` (toggles)

---

# 2. 🧩 Composants EXO — Kit Complet (19 composants)

## 2.1 Boutons

### `ExoButton`
Variantes via propriétés :
- `primary: true` → fond accent bleu, texte blanc
- `destructive: true` → fond rouge (#F44747), texte blanc
- `flat: true` → fond transparent, hover subtil (ghost)
- défaut → fond `bgElevated`, bordure `border`

États : normal → hover (color shift) → pressed (scale 0.98) → disabled (opacity 0.4)

```qml
ExoButton { text: "Confirmer"; primary: true; onClicked: save() }
ExoButton { text: "Supprimer"; destructive: true }
ExoButton { iconText: "⚙"; flat: true }
```

## 2.2 Inputs

### `ExoTextField`
Champ de texte avec placeholder, focus ring `borderFocus`, sélection `accentActive`.

### `ExoSearchField`
Champ avec icône 🔍, bouton clear (✕), placeholder "Rechercher…".
```qml
ExoSearchField { placeholder: "Filtrer les logs…"; onTextChanged: filterModel(text) }
```

## 2.3 Cards & Surfaces

### `ExoCard`
Surface `bgSecondary`, bordure `border`, ombre Fluent, animation d'apparition fade-in.
- `hoverable: true` → bordure `borderHover` au survol
- `elevated: true` → ombre sous la carte

### `ExoPanelHeader`
En-tête de section : titre en `textAccent`, `UPPERCASE`, letter-spacing 1.5px, séparateur bas.
```qml
ExoPanelHeader { title: "PARAMÈTRES AUDIO" }
```

## 2.4 Navigation

### `ExoTab`
Barre d'onglets style VS Code avec indicateur bleu en haut de l'onglet actif.
```qml
ExoTab { model: ["Chat", "Settings", "Logs"]; onTabClicked: stackLayout.currentIndex = index }
```

## 2.5 Contrôles

### `ExoSwitch`
Toggle Fluent : thumb blanc glissant, track `bgInput` → `accent` quand activé.

### `ExoSlider`
Slider avec track 4px, thumb 16px glow au hover, `accent` fill progressif.

## 2.6 Feedback

### `ExoNotification` (Toast)
Slide-in par le haut, bordure colorée par level (success/warning/error/info), auto-dismiss.
```qml
ExoNotification { message: "Service STT connecté"; level: "success"; duration: 3000 }
```

### `ExoBadge`
Pastille numérique (compteur) ou dot simple. Apparition `OutBack`.
```qml
ExoBadge { count: 3; level: "error" }    // badge rouge "3"
ExoBadge { dot: true; level: "success" } // point vert
```

### `ExoStatusPill`
Indicateur pill avec dot coloré + texte. Fond en variante `dim`, bordure en couleur pleine.
```qml
ExoStatusPill { text: "Connecté"; level: "success" }
ExoStatusPill { text: "Timeout"; level: "warning" }
```

### `ExoProgressBar`
Barre déterminée (0–1) ou indéterminée (slider animé). Couleur par `level`.
```qml
ExoProgressBar { value: 0.7; level: "success" }
ExoProgressBar { indeterminate: true; level: "accent" }
```

## 2.7 Dialogues & Overlays

### `ExoDialog`
Modal Fluent : overlay sombre 50%, panneau centré `bgElevated`, ouverture scale+opacity, bouton ✕.
```qml
ExoDialog { title: "Configuration"; contentItem: Component { … }; onClosed: console.log("fermé") }
```

### `ExoConfirmDialog`
Dialogue de confirmation avec boutons Annuler/Confirmer. `destructive: true` pour les actions dangereuses.
```qml
ExoConfirmDialog {
    title: "Supprimer l'historique ?"
    message: "Cette action est irréversible."
    destructive: true
    onAccepted: clearHistory()
}
```

### `ExoSheet`
Panneau coulissant latéral (gauche ou droite), overlay sombre, animation `OutCubic`, ombre latérale.
```qml
ExoSheet { title: "Détails"; side: "right"; contentItem: Component { … } }
```

## 2.8 Composants spécifiques EXO

### `ExoPipelineStatus`
Indicateur d'état pipeline : dot pulsant + label coloré + latence optionnelle.
Flash coloré lors du changement d'état.
```qml
ExoPipelineStatus { state: assistantManager.pipelineState; latencyMs: tracer.lastLatency }
```

### `ExoServiceStatus`
Indicateur de santé d'un microservice : dot coloré + nom + port. Pulse si dégradé.
```qml
ExoServiceStatus { name: "STT"; status: healthCheck.sttStatus; port: 8766 }
```

### `ExoMicButton`
Bouton microphone principal 64px. Halo pulsant en écoute, ring de progression en transcription/thinking, couleur
dynamique par état pipeline.
```qml
ExoMicButton { pipelineState: assistantManager.state; onClicked: toggleListening() }
```

### `ExoWaveform`
Visualiseur d'onde audio : 5 barres animées, hauteur réactive au level audio, couleur par état.
```qml
ExoWaveform { level: audioLevel; state: pipelineState; barCount: 5 }
```

---

# 3. 🎛️ Patterns D'interaction

## 3.1 États pipeline — Couleurs & Animations

| État | Couleur | Animation |
|------|---------|-----------|
| **Idle** | `#5A5A5A` (gris) | Aucune |
| **Listening** | `#007ACC` (bleu) | Halo pulsant, waveform idle |
| **Transcribing** | `#DCDCAA` (jaune) | Ring rotation, dot pulse |
| **Thinking** | `#C586C0` (violet) | Ring rotation, dot pulse |
| **Speaking** | `#4EC9B0` (vert) | Waveform réactive |
| **Error** | `#F44747` (rouge) | Flash, icône ⚠ |

Transitions : `ColorAnimation { duration: 120ms; easing: OutCubic }`

## 3.2 Feedback utilisateur

| Événement | Composant | Détail |
|-----------|-----------|--------|
| Erreur réseau | `ExoNotification` level="error" + `ExoBadge` rouge | Auto-dismiss 5s |
| Succès connexion | `ExoNotification` level="success" | Auto-dismiss 3s |
| Service down | `ExoServiceStatus` dot rouge | Pulse si degraded |
| Pipeline occupé | `ExoPipelineStatus` + `ExoProgressBar` indeterminate | Ring + barre |
| Action irréversible | `ExoConfirmDialog` destructive=true | Bouton rouge |

## 3.3 Navigation

- **Sidebar** persistante (260px) avec navigation par icônes SVG
- Header minimaliste `ExoPanelHeader` pour chaque vue
- Structure : `ExoPanelHeader` → contenu scrollable → actions bas (optionnel)
- Raccourcis clavier : Space (écoute), Escape (stop), Ctrl+, (settings), Ctrl+H (history)

---

# 4. 🧠 Guidelines UX

### Quand utiliser quel bouton ?
- **Primary** : Action principale unique par vue (Sauvegarder, Confirmer, Envoyer)
- **Secondary** (défaut) : Actions secondaires (Annuler, Réinitialiser)
- **Ghost/Flat** : Actions tertiaires, icônes toolbar
- **Destructive** : Suppression, actions irréversibles

### Quand utiliser quel feedback ?
- **Toast** (`ExoNotification`) : Messages temporaires non-bloquants
- **Dialog** (`ExoDialog`) : Formulaires, configuration complexe
- **Confirm** (`ExoConfirmDialog`) : Actions destructives nécessitant validation
- **Badge** (`ExoBadge`) : Compteurs, indicateurs non-lus
- **Pill** (`ExoStatusPill`) : État permanent visible (healthy/degraded/down)

### Structure d'une page
```
┌─ ExoPanelHeader ──────────────────────┐
│  TITRE SECTION              [actions] │
├───────────────────────────────────────┤
│                                       │
│  Contenu scrollable                   │
│  (ExoCard, listes, formulaires)       │
│                                       │
└───────────────────────────────────────┘
```

### Erreurs critiques
1. État pipeline → `ExoPipelineStatus` en Error + couleur rouge
2. Toast rouge → `ExoNotification` level="error" (auto-dismiss 5s)
3. Sidebar → `ExoBadge` dot rouge sur l'onglet concerné
4. Service down → `ExoServiceStatus` dot rouge dans BottomBar

---

# 5. 📁 Structure QML

```
qml/
  MainWindow.qml           ← Point d'entrée, layout SplitView
  theme/
    Theme.qml              ← Singleton Design System (tokens)
    qmldir                 ← Module singleton
  components/              ← Kit de composants réutilisables
    ExoButton.qml
    ExoCard.qml
    ExoSwitch.qml
    ExoSlider.qml
    ExoTextField.qml
    ExoSearchField.qml
    ExoDialog.qml
    ExoConfirmDialog.qml
    ExoNotification.qml
    ExoPanelHeader.qml
    ExoSheet.qml
    ExoTab.qml
    ExoProgressBar.qml
    ExoBadge.qml
    ExoStatusPill.qml
    ExoPipelineStatus.qml
    ExoServiceStatus.qml
    ExoMicButton.qml
    ExoWaveform.qml
    qmldir                 ← Module composants
  vscode/                  ← Panneaux applicatifs
    Sidebar.qml
    BottomBar.qml
    TranscriptView.qml
    ResponseView.qml
    SettingsPanel.qml
    HistoryPanel.qml
    LogPanel.qml
    PipelineMonitor.qml
    SplashScreen.qml
    StatusIndicator.qml
    MicrophoneLevel.qml
    Visualizer.qml
  icons/                   ← 12 icônes SVG Fluent
    chat.svg, debug.svg, history.svg, logs.svg,
    microphone.svg, pipeline.svg, send.svg, settings.svg,
    stt.svg, tts.svg, vad.svg, wakeword.svg
```

---

# 6. 🎨 Theme.qml — Résumé

Fichier : `qml/theme/Theme.qml` — Singleton QML

| Section | Contenu |
|---------|---------|
| **Couleurs** | 26 tokens fond/accent/texte + 8 variantes sémantiques hover/dim + 5 pipeline + 5 états + 3 splash |
| **Typographie** | 2 familles + 9 tailles + 5 poids |
| **Espacement** | 10 valeurs (2–32px) + 5 marges/padding |
| **Rayons** | 5 niveaux (4–999px) |
| **Ombres** | 3 niveaux (radius + opacité) |
| **Animations** | 4 durées (80–200ms) |
| **Dimensions** | 12 constantes composants + 5 indicateurs |
| **Helpers** | `stateColor()`, `pipelineStateColor()`, `healthColor()`, `color()`, `semanticColor()` |

---

# 7. 🧩 Composants QML — Inventaire (19)

| # | Composant | Type | Propriétés clés |
|---|-----------|------|-----------------|
| 1 | `ExoButton` | Contrôle | text, primary, destructive, flat, iconText |
| 2 | `ExoCard` | Surface | hoverable, elevated |
| 3 | `ExoSwitch` | Contrôle | checked, enabled |
| 4 | `ExoSlider` | Contrôle | value, min, max |
| 5 | `ExoTextField` | Input | text, placeholder, readOnly |
| 6 | `ExoSearchField` | Input | text, placeholder, clearable |
| 7 | `ExoDialog` | Overlay | title, contentItem, showClose |
| 8 | `ExoConfirmDialog` | Overlay | title, message, destructive |
| 9 | `ExoNotification` | Feedback | message, level, duration |
| 10 | `ExoPanelHeader` | Layout | title, titleColor, rightContent |
| 11 | `ExoSheet` | Overlay | title, side, contentItem |
| 12 | `ExoTab` | Navigation | model, currentIndex |
| 13 | `ExoProgressBar` | Feedback | value, indeterminate, level |
| 14 | `ExoBadge` | Feedback | count, level, dot |
| 15 | `ExoStatusPill` | Feedback | text, level |
| 16 | `ExoPipelineStatus` | EXO | state, latencyMs |
| 17 | `ExoServiceStatus` | EXO | name, status, port |
| 18 | `ExoMicButton` | EXO | pipelineState, enabled |
| 19 | `ExoWaveform` | EXO | level, state, barCount |

Tous utilisent les tokens `Theme.*`, incluent `Behavior` animations Fluent, et suivent le design VS Code dark.

---

# 8. 🧪 Checklist Finale

| Critère | Statut |
|---------|--------|
| Cohérence couleurs (tokens Theme partout) | ✅ |
| Cohérence espacements (grille 4/8px) | ✅ |
| Cohérence icônes (12 SVG Fluent) | ✅ |
| Cohérence composants (19 briques design) | ✅ |
| Cohérence animations (Behavior + durées tokens) | ✅ |
| Cohérence états pipeline (6 états, couleurs, animations) | ✅ |
| Cohérence dialogues (Dialog, Confirm, Sheet) | ✅ |
| Cohérence inputs (TextField, SearchField) | ✅ |
| Cohérence navigation (Sidebar, Tabs) | ✅ |
| Build CMake sans erreur | ✅ |
| Singleton Theme.qml intégré | ✅ |

---
*Retour à l'index : [docs/README.md](../README.md)*
