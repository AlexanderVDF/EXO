#!/bin/bash

# =============================================================================
# Script de démarrage automatique - Assistant Domotique Intelligent
# Pour Raspberry Pi 5 avec interface complète
# =============================================================================

set -e

# Configuration
ASSISTANT_HOME="/opt/raspberry-assistant"
USER_HOME="/home/pi"
LOG_FILE="/var/log/raspberry-assistant.log"
PID_FILE="/var/run/raspberry-assistant.pid"

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction de logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
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

# Vérification des prérequis système
check_system() {
    log "Vérification du système..."
    
    # Vérifier que nous sommes sur Raspberry Pi
    if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        log_error "Ce script est conçu pour Raspberry Pi"
        exit 1
    fi
    
    # Vérifier la mémoire disponible (minimum 2GB)
    total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    if [ "$total_mem" -lt 2000000 ]; then
        log_warning "Mémoire insuffisante détectée (<2GB). Performance réduite possible."
    fi
    
    # Vérifier l'espace disque (minimum 1GB libre)
    available_space=$(df / | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 1000000 ]; then
        log_error "Espace disque insuffisant (<1GB libre)"
        exit 1
    fi
    
    log "✓ Système compatible détecté"
}

# Configuration de l'environnement
setup_environment() {
    log "Configuration de l'environnement..."
    
    # Variables d'environnement pour Qt
    export QT_QPA_PLATFORM="eglfs"
    export QT_QPA_EGLFS_ALWAYS_SET_MODE=1
    export QT_QPA_EGLFS_WIDTH=1920
    export QT_QPA_EGLFS_HEIGHT=1080
    export QT_LOGGING_RULES="*.debug=false;qt.qml.binding.removal.info=true"
    
    # Configuration audio
    export ALSA_CARD=1  # Carte audio USB/I2S
    export PULSE_RUNTIME_PATH="/run/user/1000/pulse"
    
    # Configuration GPU (VideoCore VII)
    if [ -f /boot/config.txt ]; then
        # Vérifier la configuration GPU
        if ! grep -q "gpu_mem=256" /boot/config.txt; then
            log_warning "GPU memory non optimisée. Recommandé: gpu_mem=256"
        fi
    fi
    
    # Configuration réseau pour APIs
    export PYTHONUNBUFFERED=1
    export PYTHONIOENCODING=utf-8
    
    log "✓ Environnement configuré"
}

# Configuration audio ALSA/PulseAudio
setup_audio() {
    log "Configuration du système audio..."
    
    # Démarrer PulseAudio si nécessaire
    if ! pgrep -x "pulseaudio" > /dev/null; then
        sudo -u pi pulseaudio --start --exit-idle-time=-1 &
        sleep 2
    fi
    
    # Configurer le volume par défaut
    sudo -u pi amixer set Master 70% unmute 2>/dev/null || true
    sudo -u pi pactl set-sink-volume @DEFAULT_SINK@ 70% 2>/dev/null || true
    
    # Test rapide du son
    if command -v speaker-test >/dev/null; then
        log_info "Test audio: speaker-test disponible"
    fi
    
    log "✓ Audio configuré"
}

# Démarrage du service Python Claude
start_claude_service() {
    log "Démarrage du service Claude Haiku..."
    
    cd "$ASSISTANT_HOME/python" || exit 1
    
    # Activer l'environnement virtuel Python
    if [ -f "venv/bin/activate" ]; then
        source venv/bin/activate
        log "✓ Environnement Python activé"
    else
        log_error "Environnement Python virtuel non trouvé"
        exit 1
    fi
    
    # Vérifier la configuration Claude
    if [ ! -f "../config/assistant.conf" ]; then
        log_error "Fichier de configuration manquant: config/assistant.conf"
        exit 1
    fi
    
    # Démarrer le service Claude en arrière-plan
    python3 claude_service.py --daemon --port 8001 &
    CLAUDE_PID=$!
    
    # Attendre que le service soit prêt
    sleep 3
    if ps -p $CLAUDE_PID > /dev/null; then
        log "✓ Service Claude démarré (PID: $CLAUDE_PID)"
        echo $CLAUDE_PID > /var/run/claude-service.pid
    else
        log_error "Échec du démarrage du service Claude"
        exit 1
    fi
}

# Vérification des services externes
check_external_services() {
    log "Vérification des services externes..."
    
    # Test de connectivité Internet
    if ! ping -c 1 google.com &> /dev/null; then
        log_warning "Pas de connexion Internet détectée"
        log_warning "Les services cloud (Claude, Azure TTS, etc.) seront indisponibles"
    else
        log "✓ Connexion Internet disponible"
    fi
    
    # Test API Claude (si configurée)
    if [ -f "$ASSISTANT_HOME/config/assistant.conf" ]; then
        if grep -q "ANTHROPIC_API_KEY=" "$ASSISTANT_HOME/config/assistant.conf"; then
            log_info "Configuration API Claude détectée"
        fi
    fi
    
    # Test configuration Azure TTS
    if grep -q "AZURE_TTS_KEY=" "$ASSISTANT_HOME/config/assistant.conf" 2>/dev/null; then
        log_info "Configuration Azure TTS détectée"
    fi
    
    log "✓ Services externes vérifiés"
}

# Démarrage de l'application principale
start_main_application() {
    log "Démarrage de l'Assistant Domotique Intelligent..."
    
    cd "$ASSISTANT_HOME/bin" || exit 1
    
    # Attendre que X11/Wayland soit prêt (si applicable)
    sleep 2
    
    # Démarrer l'application Qt avec gestion des erreurs
    ./RaspberryAssistant --platform eglfs --fullscreen &
    MAIN_PID=$!
    
    # Sauvegarder le PID principal
    echo $MAIN_PID > "$PID_FILE"
    
    # Vérifier que l'application a démarré
    sleep 5
    if ps -p $MAIN_PID > /dev/null; then
        log "✓ Application principale démarrée (PID: $MAIN_PID)"
    else
        log_error "Échec du démarrage de l'application principale"
        exit 1
    fi
}

# Monitoring et surveillance
setup_monitoring() {
    log "Configuration du monitoring système..."
    
    # Script de surveillance en arrière-plan
    {
        while true; do
            # Vérifier l'utilisation CPU
            cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
            if (( $(echo "$cpu_usage > 90" | bc -l) )); then
                log_warning "Utilisation CPU élevée: ${cpu_usage}%"
            fi
            
            # Vérifier la température
            temp=$(vcgencmd measure_temp | cut -d'=' -f2 | cut -d"'" -f1)
            if (( $(echo "$temp > 70" | bc -l) )); then
                log_warning "Température SoC élevée: ${temp}°C"
            fi
            
            # Vérifier la mémoire
            mem_usage=$(free | grep Mem | awk '{printf("%.1f"), $3/$2 * 100.0}')
            if (( $(echo "$mem_usage > 90" | bc -l) )); then
                log_warning "Utilisation mémoire élevée: ${mem_usage}%"
            fi
            
            sleep 60  # Vérifier toutes les minutes
        done
    } &
    
    log "✓ Monitoring système activé"
}

# Nettoyage et optimisation
cleanup_and_optimize() {
    log "Nettoyage et optimisation..."
    
    # Nettoyer les logs anciens (>7 jours)
    find /var/log -name "*.log" -mtime +7 -delete 2>/dev/null || true
    
    # Optimiser la base de données SQLite
    if [ -f "$ASSISTANT_HOME/data/memory.db" ]; then
        sqlite3 "$ASSISTANT_HOME/data/memory.db" "VACUUM;" 2>/dev/null || true
        log_info "Base de données optimisée"
    fi
    
    # Nettoyer le cache TTS
    if [ -d "$USER_HOME/.cache/tts" ]; then
        find "$USER_HOME/.cache/tts" -name "*.mp3" -mtime +1 -delete 2>/dev/null || true
    fi
    
    log "✓ Nettoyage terminé"
}

# Gestionnaire de signaux pour arrêt propre
cleanup_on_exit() {
    log "Arrêt de l'Assistant Domotique..."
    
    # Arrêter l'application principale
    if [ -f "$PID_FILE" ]; then
        MAIN_PID=$(cat "$PID_FILE")
        if ps -p $MAIN_PID > /dev/null; then
            kill -TERM $MAIN_PID
            sleep 5
            if ps -p $MAIN_PID > /dev/null; then
                kill -KILL $MAIN_PID
            fi
        fi
        rm -f "$PID_FILE"
    fi
    
    # Arrêter le service Claude
    if [ -f "/var/run/claude-service.pid" ]; then
        CLAUDE_PID=$(cat "/var/run/claude-service.pid")
        if ps -p $CLAUDE_PID > /dev/null; then
            kill -TERM $CLAUDE_PID
        fi
        rm -f "/var/run/claude-service.pid"
    fi
    
    log "Assistant arrêté proprement"
    exit 0
}

# Configuration des gestionnaires de signaux
trap cleanup_on_exit SIGTERM SIGINT

# Fonction principale
main() {
    log "=== Démarrage Assistant Domotique Intelligent v2.0 ==="
    log "Raspberry Pi 5 • Claude Haiku • Microsoft Henri • EZVIZ • Streaming"
    
    # Vérifications préalables
    check_system
    setup_environment
    setup_audio
    
    # Optimisation système
    cleanup_and_optimize
    
    # Démarrage des services
    check_external_services
    start_claude_service
    
    # Démarrage de l'application
    start_main_application
    
    # Surveillance
    setup_monitoring
    
    log "=== Assistant Domotique démarré avec succès ==="
    log "Interface disponible sur l'écran tactile"
    log "Services: Claude IA • Azure TTS Henri • EZVIZ • Spotify/Tidal • Google"
    
    # Boucle principale de surveillance
    while true; do
        # Vérifier que l'application principale fonctionne
        if [ -f "$PID_FILE" ]; then
            MAIN_PID=$(cat "$PID_FILE")
            if ! ps -p $MAIN_PID > /dev/null; then
                log_error "Application principale s'est arrêtée. Redémarrage..."
                start_main_application
            fi
        fi
        
        sleep 30
    done
}

# Gestion des arguments en ligne de commande
case "${1:-}" in
    "start")
        main
        ;;
    "stop")
        cleanup_on_exit
        ;;
    "restart")
        cleanup_on_exit
        sleep 2
        main
        ;;
    "status")
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            if ps -p $PID > /dev/null; then
                echo "Assistant Domotique en cours d'exécution (PID: $PID)"
                exit 0
            else
                echo "Assistant Domotique arrêté"
                exit 1
            fi
        else
            echo "Assistant Domotique non démarré"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        echo ""
        echo "Assistant Domotique Intelligent v2.0"
        echo "Contrôle du service principal"
        exit 1
        ;;
esac