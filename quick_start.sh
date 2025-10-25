#!/bin/bash

# =============================================================================
# Script de démarrage rapide - Assistant Domotique v2.0
# Usage: ./quick_start.sh [--dev|--prod|--test]
# =============================================================================

set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
CONFIG_DIR="$PROJECT_ROOT/config"
PYTHON_DIR="$PROJECT_ROOT/python"
LOG_FILE="/tmp/assistant_quick_start.log"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Mode par défaut
MODE="auto"
if [[ "$1" == "--dev" ]]; then
    MODE="development"
elif [[ "$1" == "--prod" ]]; then
    MODE="production"
elif [[ "$1" == "--test" ]]; then
    MODE="test"
fi

# Logging
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
    echo "[$(date +'%H:%M:%S')] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    echo "[ERROR] $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
    echo "[WARNING] $1" >> "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
    echo "[INFO] $1" >> "$LOG_FILE"
}

log_header() {
    echo -e "${PURPLE}
╔═══════════════════════════════════════════════════════════╗
║           🏠 Assistant Domotique Intelligent v2.0        ║
║     Claude Haiku • Henri TTS • EZVIZ • Streaming         ║
╚═══════════════════════════════════════════════════════════╝${NC}"
}

# Détection de l'architecture
detect_platform() {
    if [[ $(uname -m) == "aarch64" ]] && [[ -f /proc/cpuinfo ]] && grep -q "Raspberry Pi" /proc/cpuinfo; then
        PLATFORM="raspberry-pi"
        log "🍓 Raspberry Pi 5 détecté"
    elif [[ $(uname -s) == "Linux" ]]; then
        PLATFORM="linux"
        log "🐧 Linux desktop détecté"
    elif [[ $(uname -s) == "Darwin" ]]; then
        PLATFORM="macos"
        log "🍎 macOS détecté"
    else
        PLATFORM="windows"
        log "🪟 Windows détecté (via WSL/Git Bash)"
    fi
}

# Vérification des prérequis
check_prerequisites() {
    log "Vérification des prérequis..."
    
    # Qt 6
    if ! command -v qmake6 &> /dev/null && ! command -v qmake &> /dev/null; then
        log_error "Qt 6 non trouvé. Installez Qt 6.5+ avec modules 3D"
        exit 1
    fi
    
    # CMake
    if ! command -v cmake &> /dev/null; then
        log_error "CMake non trouvé. Installation requise"
        exit 1
    fi
    
    # Python 3.11+
    if ! python3 --version | grep -E "3\.(11|12)" &> /dev/null; then
        log_warning "Python 3.11+ recommandé pour les performances optimales"
    fi
    
    # Compilateur
    if ! command -v gcc &> /dev/null && ! command -v clang &> /dev/null; then
        log_error "Compilateur C++ non trouvé (gcc/clang requis)"
        exit 1
    fi
    
    log "✓ Prérequis vérifiés"
}

# Chargement de la configuration
load_configuration() {
    log "Chargement de la configuration..."
    
    # Créer config par défaut si inexistant
    if [[ ! -f "$CONFIG_DIR/api_keys.conf" ]]; then
        log_warning "Configuration API manquante, création du template"
        mkdir -p "$CONFIG_DIR"
        
        cat > "$CONFIG_DIR/api_keys.conf" << 'EOF'
# =============================================================================
# Configuration API - Assistant Domotique v2.0
# Remplacez les valeurs par vos vraies clés d'API
# =============================================================================

# Claude Haiku (Anthropic) - OBLIGATOIRE
# Obtenez votre clé sur: https://console.anthropic.com/
ANTHROPIC_API_KEY=sk-ant-api03-VOTRE_CLE_ICI

# Microsoft Azure TTS (Optionnel - fallback sur espeak)
# Guide: https://azure.microsoft.com/services/cognitive-services/text-to-speech/
AZURE_TTS_KEY=VOTRE_CLE_AZURE
AZURE_TTS_REGION=francecentral

# EZVIZ Smart Home (Optionnel)
# Configuration sur: https://open.ys7.com/
EZVIZ_APP_KEY=VOTRE_APP_KEY
EZVIZ_APP_SECRET=VOTRE_APP_SECRET
EZVIZ_ACCOUNT=votre_email@example.com
EZVIZ_PASSWORD=votre_mot_de_passe

# Spotify (Optionnel)
# App Spotify: https://developer.spotify.com/dashboard/
SPOTIFY_CLIENT_ID=VOTRE_CLIENT_ID
SPOTIFY_CLIENT_SECRET=VOTRE_CLIENT_SECRET

# Tidal (Optionnel)
# Contact Tidal pour API access
TIDAL_CLIENT_ID=VOTRE_CLIENT_ID
TIDAL_CLIENT_SECRET=VOTRE_CLIENT_SECRET

# Google Services (Optionnel)
# Google Cloud Console: https://console.cloud.google.com/
GOOGLE_CLIENT_ID=VOTRE_CLIENT_ID
GOOGLE_CLIENT_SECRET=VOTRE_CLIENT_SECRET
GOOGLE_API_KEY=VOTRE_API_KEY
EOF
        
        log_info "📝 Configuration créée dans: $CONFIG_DIR/api_keys.conf"
        log_info "Éditez ce fichier avec vos vraies clés d'API"
    fi
    
    # Charger les variables
    if [[ -f "$CONFIG_DIR/api_keys.conf" ]]; then
        source "$CONFIG_DIR/api_keys.conf"
        
        # Vérifier au moins Claude
        if [[ "$ANTHROPIC_API_KEY" == "sk-ant-api03-VOTRE_CLE_ICI" ]] || [[ -z "$ANTHROPIC_API_KEY" ]]; then
            log_warning "⚠️  Clé API Claude non configurée - fonctionnalités limitées"
            log_info "Éditez $CONFIG_DIR/api_keys.conf avec votre clé Anthropic"
        else
            log "✓ Configuration API Claude chargée"
        fi
    fi
}

# Configuration de l'environnement Python
setup_python_env() {
    log "Configuration de l'environnement Python..."
    
    cd "$PYTHON_DIR"
    
    # Créer environnement virtuel si nécessaire
    if [[ ! -d "venv" ]]; then
        log_info "Création de l'environnement virtuel Python"
        python3 -m venv venv
    fi
    
    # Activer l'environnement
    source venv/bin/activate
    
    # Installer/mettre à jour les dépendances
    if [[ ! -f "requirements_installed.lock" ]] || [[ "requirements.txt" -nt "requirements_installed.lock" ]]; then
        log_info "Installation des dépendances Python..."
        pip install --upgrade pip
        pip install -r requirements.txt
        touch requirements_installed.lock
    fi
    
    log "✓ Environnement Python prêt"
    cd "$PROJECT_ROOT"
}

# Compilation du projet
build_project() {
    log "Compilation du projet..."
    
    # Créer répertoire de build
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Configuration CMake selon la plateforme
    CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=Release"
    
    if [[ "$PLATFORM" == "raspberry-pi" ]]; then
        CMAKE_FLAGS="$CMAKE_FLAGS -DRASPBERRY_PI=ON"
        MAKE_JOBS=4  # RPi5 a 4 cœurs
    else
        CMAKE_FLAGS="$CMAKE_FLAGS -DCMAKE_BUILD_TYPE=Debug"
        MAKE_JOBS=$(nproc 2>/dev/null || echo 4)
    fi
    
    # Configuration CMake
    if [[ ! -f "Makefile" ]] || [[ "$PROJECT_ROOT/CMakeLists.txt" -nt "Makefile" ]]; then
        log_info "Configuration CMake..."
        cmake .. $CMAKE_FLAGS
    fi
    
    # Compilation
    if [[ ! -f "RaspberryAssistant" ]] || find "$PROJECT_ROOT/src" -name "*.cpp" -newer "RaspberryAssistant" | grep -q .; then
        log_info "Compilation en cours (${MAKE_JOBS} jobs)..."
        make -j$MAKE_JOBS
    else
        log "✓ Projet déjà compilé et à jour"
    fi
    
    cd "$PROJECT_ROOT"
}

# Test des services
test_services() {
    log "Test des services..."
    
    # Test service Claude
    cd "$PYTHON_DIR"
    source venv/bin/activate
    
    if python3 -c "import anthropic; print('✓ Module Anthropic disponible')" 2>/dev/null; then
        log "✓ Service Claude prêt"
    else
        log_warning "Service Claude non disponible (vérifiez la clé API)"
    fi
    
    # Test Qt
    cd "$BUILD_DIR"
    if [[ -f "RaspberryAssistant" ]]; then
        if [[ "$MODE" == "test" ]]; then
            log_info "Test rapide de l'interface..."
            timeout 10s ./RaspberryAssistant --test-mode --no-audio &>/dev/null && log "✓ Interface Qt fonctionnelle" || log_warning "Test interface échoué"
        fi
    fi
    
    cd "$PROJECT_ROOT"
}

# Configuration audio (Raspberry Pi)
setup_audio() {
    if [[ "$PLATFORM" == "raspberry-pi" ]]; then
        log "Configuration audio Raspberry Pi..."
        
        # Démarrer PulseAudio si nécessaire
        if ! pgrep -x "pulseaudio" > /dev/null; then
            pulseaudio --start &>/dev/null || true
        fi
        
        # Volume par défaut
        amixer set Master 70% unmute &>/dev/null || true
        
        log "✓ Audio configuré"
    fi
}

# Démarrage du service Claude
start_claude_service() {
    log "Démarrage du service Claude..."
    
    cd "$PYTHON_DIR"
    source venv/bin/activate
    
    # Vérifier si déjà en cours
    if pgrep -f "claude_service.py" > /dev/null; then
        log "✓ Service Claude déjà en cours"
    else
        # Démarrer en arrière-plan
        python3 claude_service.py --daemon --port 8001 &
        sleep 2
        
        if pgrep -f "claude_service.py" > /dev/null; then
            log "✓ Service Claude démarré"
        else
            log_warning "Échec démarrage service Claude"
        fi
    fi
    
    cd "$PROJECT_ROOT"
}

# Initialisation base de données
init_database() {
    log "Initialisation de la base de données..."
    
    mkdir -p data
    
    if [[ ! -f "data/memory.db" ]]; then
        log_info "Création de la base de données SQLite..."
        sqlite3 data/memory.db << 'EOF'
CREATE TABLE IF NOT EXISTS user_preferences (
    id INTEGER PRIMARY KEY,
    key TEXT UNIQUE,
    value TEXT,
    category TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS conversations (
    id INTEGER PRIMARY KEY,
    user_message TEXT,
    assistant_response TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    context TEXT
);

CREATE TABLE IF NOT EXISTS routines (
    id INTEGER PRIMARY KEY,
    name TEXT,
    pattern TEXT,
    confidence REAL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT OR IGNORE INTO user_preferences (key, value, category) VALUES 
    ('language', 'fr-FR', 'general'),
    ('voice_speed', '1.0', 'tts'),
    ('voice_volume', '0.8', 'tts'),
    ('first_run', 'true', 'system');
EOF
        log "✓ Base de données initialisée"
    else
        log "✓ Base de données existante"
    fi
}

# Démarrage de l'interface
start_interface() {
    log "Démarrage de l'interface utilisateur..."
    
    cd "$BUILD_DIR"
    
    # Configuration Qt selon plateforme et mode
    export QT_LOGGING_RULES="*.debug=false;qt.qml.binding.removal.info=true"
    
    case "$PLATFORM" in
        "raspberry-pi")
            if [[ "$MODE" == "development" ]]; then
                export QT_QPA_PLATFORM="xcb"
                log_info "Mode développement RPi: interface fenêtrée"
                ./RaspberryAssistant --windowed --debug
            else
                export QT_QPA_PLATFORM="eglfs"
                export QT_QPA_EGLFS_ALWAYS_SET_MODE=1
                export QT_QPA_EGLFS_WIDTH=1920
                export QT_QPA_EGLFS_HEIGHT=1080
                log_info "Mode production RPi: interface plein écran"
                ./RaspberryAssistant --fullscreen
            fi
            ;;
        *)
            if [[ "$MODE" == "test" ]]; then
                log_info "Mode test: interface minimale"
                ./RaspberryAssistant --test-mode --windowed --no-audio
            else
                log_info "Mode développement desktop: interface fenêtrée"
                ./RaspberryAssistant --windowed --debug
            fi
            ;;
    esac
}

# Nettoyage à l'arrêt
cleanup() {
    log "Nettoyage à l'arrêt..."
    
    # Arrêter service Claude si démarré par ce script
    pkill -f "claude_service.py" &>/dev/null || true
    
    log "Assistant arrêté proprement"
}

# Gestionnaire de signaux
trap cleanup EXIT INT TERM

# Fonction principale
main() {
    log_header
    
    log "🚀 Démarrage rapide - Mode: $MODE"
    log "📁 Répertoire: $PROJECT_ROOT"
    
    # Étapes d'initialisation
    detect_platform
    check_prerequisites
    load_configuration
    
    # Configuration environnement
    setup_python_env
    init_database
    
    # Compilation et tests
    build_project
    test_services
    
    # Services système
    setup_audio
    start_claude_service
    
    # Démarrage interface
    log "🎉 Tout est prêt ! Démarrage de l'assistant..."
    sleep 1
    
    start_interface
}

# Aide
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "🏠 Assistant Domotique Intelligent v2.0 - Démarrage Rapide"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --dev       Mode développement (interface fenêtrée + debug)"
    echo "  --prod      Mode production (plein écran, optimisé)"
    echo "  --test      Mode test (interface minimale, pas d'audio)"
    echo "  --help      Afficher cette aide"
    echo ""
    echo "Fonctionnalités:"
    echo "  ✓ Claude Haiku IA conversationnelle"
    echo "  ✓ Microsoft Henri TTS français"
    echo "  ✓ Domotique EZVIZ complète"
    echo "  ✓ Designer 3D d'appartement"
    echo "  ✓ Streaming Tidal/Spotify"
    echo "  ✓ Services Google intégrés"
    echo "  ✓ Mémoire AI persistante"
    echo ""
    echo "Configuration: Éditez config/api_keys.conf avec vos clés d'API"
    exit 0
fi

# Exécution
main "$@"