#!/bin/bash
# Script de création d'image microSD personnalisée pour Raspberry Pi 5
# Basé sur Raspberry Pi OS avec l'Assistant pré-installé

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WORK_DIR="$PROJECT_ROOT/image-build"
IMAGE_NAME="raspberry-assistant-$(date +%Y%m%d).img"
FINAL_IMAGE="$PROJECT_ROOT/$IMAGE_NAME"

# Tailles (en MB)
BOOT_SIZE=512
ROOT_SIZE=8192  # 8GB pour laisser de la place
TOTAL_SIZE=$((BOOT_SIZE + ROOT_SIZE + 512))  # +512MB de marge

# URLs et fichiers
RPI_OS_URL="https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2024-03-15/2024-03-15-raspios-bookworm-arm64-lite.img.xz"
RPI_OS_FILE="rpi-os-lite.img.xz"
RPI_OS_IMG="rpi-os-lite.img"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_dependencies() {
    log_info "Vérification des dépendances..."
    
    local deps=("wget" "unxz" "parted" "kpartx" "mount" "chroot" "qemu-arm-static")
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Dépendance manquante: $dep"
            
            if [[ "$dep" == "qemu-arm-static" ]]; then
                log_info "Installez: sudo apt-get install qemu-user-static"
            fi
            
            exit 1
        fi
    done
    
    # Vérifier les permissions root
    if [[ $EUID -ne 0 ]]; then
        log_error "Ce script doit être exécuté avec sudo"
        exit 1
    fi
    
    log_success "Dépendances vérifiées"
}

download_base_image() {
    log_info "Téléchargement de l'image Raspberry Pi OS..."
    
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    if [[ ! -f "$RPI_OS_FILE" ]]; then
        log_info "Téléchargement depuis $RPI_OS_URL"
        wget -O "$RPI_OS_FILE" "$RPI_OS_URL" || {
            log_error "Échec du téléchargement"
            exit 1
        }
    else
        log_info "Image déjà téléchargée"
    fi
    
    if [[ ! -f "$RPI_OS_IMG" ]]; then
        log_info "Décompression de l'image..."
        unxz -k "$RPI_OS_FILE"
    fi
    
    log_success "Image de base prête"
}

resize_image() {
    log_info "Redimensionnement de l'image..."
    
    cd "$WORK_DIR"
    
    # Créer une copie de travail
    cp "$RPI_OS_IMG" "work-image.img"
    
    # Ajouter de l'espace à l'image
    local current_size=$(stat -c %s "work-image.img")
    local add_size=$((4 * 1024 * 1024 * 1024))  # Ajouter 4GB
    
    dd if=/dev/zero bs=1 count=0 seek=$((current_size + add_size)) of="work-image.img"
    
    # Redimensionner la partition root
    log_info "Redimensionnement de la partition root..."
    
    # Utiliser parted pour étendre la partition
    parted -s "work-image.img" resizepart 2 100%
    
    log_success "Image redimensionnée"
}

mount_image() {
    log_info "Montage de l'image..."
    
    cd "$WORK_DIR"
    
    # Créer les points de montage
    mkdir -p mnt/boot mnt/root
    
    # Mapper les partitions avec kpartx
    local loop_device=$(kpartx -av "work-image.img" | head -n1 | awk '{print $3}' | sed 's/p1//')
    echo "$loop_device" > loop_device.txt
    
    # Attendre que les devices soient prêts
    sleep 2
    
    # Monter les partitions
    mount "/dev/mapper/${loop_device}p1" mnt/boot
    mount "/dev/mapper/${loop_device}p2" mnt/root
    
    log_success "Image montée"
}

setup_chroot() {
    log_info "Configuration de l'environnement chroot..."
    
    local root_dir="$WORK_DIR/mnt/root"
    
    # Copier qemu-arm-static pour l'émulation
    cp /usr/bin/qemu-aarch64-static "$root_dir/usr/bin/"
    
    # Monter les pseudo-filesystems
    mount -t proc proc "$root_dir/proc"
    mount -t sysfs sysfs "$root_dir/sys"
    mount -o bind /dev "$root_dir/dev"
    mount -o bind /dev/pts "$root_dir/dev/pts"
    
    # Copier les résolveurs DNS
    cp /etc/resolv.conf "$root_dir/etc/resolv.conf"
    
    log_success "Chroot configuré"
}

install_assistant() {
    log_info "Installation de l'Assistant Personnel..."
    
    local root_dir="$WORK_DIR/mnt/root"
    
    # Copier les sources du projet
    mkdir -p "$root_dir/tmp/assistant-install"
    cp -r "$PROJECT_ROOT"/* "$root_dir/tmp/assistant-install/"
    
    # Script d'installation dans le chroot
    cat > "$root_dir/tmp/install_assistant.sh" << 'EOF'
#!/bin/bash
set -e

echo "🤖 Installation Assistant Personnel dans l'image..."

# Mise à jour du système
apt-get update
apt-get upgrade -y

# Installation des dépendances système
apt-get install -y \
    qt6-base-dev qt6-declarative-dev qt6-multimedia-dev \
    espeak-ng alsa-utils pulseaudio \
    python3-pip python3-pyaudio \
    cmake build-essential git \
    htop curl wget vim

# Configuration des services audio
systemctl enable pulseaudio

# Installation de l'assistant
cd /tmp/assistant-install
python3 scripts/install_dependencies.py

# Compilation du projet
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
make install

# Configuration des services
systemctl enable raspberry-assistant

# Nettoyage
rm -rf /tmp/assistant-install
apt-get autoremove -y
apt-get clean

echo "✅ Assistant installé dans l'image"
EOF
    
    chmod +x "$root_dir/tmp/install_assistant.sh"
    
    # Exécuter l'installation dans le chroot
    chroot "$root_dir" /tmp/install_assistant.sh
    
    log_success "Assistant installé"
}

configure_system() {
    log_info "Configuration système personnalisée..."
    
    local root_dir="$WORK_DIR/mnt/root"
    local boot_dir="$WORK_DIR/mnt/boot"
    
    # Configuration boot pour mode headless avec écran tactile
    cat >> "$boot_dir/config.txt" << EOF

# Configuration Assistant Personnel
# Écran tactile DSI
dtoverlay=vc4-kms-v3d
gpu_mem=128
hdmi_force_hotplug=1

# Audio
dtparam=audio=on

# Interface camera (optionnel)
camera_auto_detect=1

# Performance
arm_boost=1
EOF
    
    # Configuration système
    cat > "$root_dir/etc/systemd/system/assistant-init.service" << EOF
[Unit]
Description=Assistant Personnel - Configuration initiale
After=network.target
Before=raspberry-assistant.service

[Service]
Type=oneshot
ExecStart=/opt/raspberry-assistant/scripts/first_boot_setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Script de première configuration
    mkdir -p "$root_dir/opt/raspberry-assistant/scripts"
    cat > "$root_dir/opt/raspberry-assistant/scripts/first_boot_setup.sh" << 'EOF'
#!/bin/bash
# Configuration au premier démarrage

# Étendre le système de fichiers
raspi-config --expand-rootfs

# Configuration audio par défaut
amixer set Master 70%
amixer set PCM 70%

# Configuration réseau WiFi (sera configuré par l'utilisateur)
# Message de bienvenue
cat > /etc/motd << EOL

🤖 Assistant Personnel Raspberry Pi 5
====================================

Configuration initiale:
1. Configurez WiFi: sudo raspi-config
2. Définissez votre clé API Claude:
   export ANTHROPIC_API_KEY="your_key_here"
   echo 'export ANTHROPIC_API_KEY="your_key"' >> ~/.bashrc
3. Démarrez l'assistant: sudo systemctl start raspberry-assistant

Pour plus d'aide: /opt/raspberry-assistant/README.md

EOL

echo "Configuration initiale terminée" > /var/log/assistant-init.log
EOF
    
    chmod +x "$root_dir/opt/raspberry-assistant/scripts/first_boot_setup.sh"
    
    # Activer le service d'initialisation
    chroot "$root_dir" systemctl enable assistant-init
    
    # Configuration SSH (optionnel, pour debug)
    chroot "$root_dir" systemctl enable ssh
    
    log_success "Configuration système appliquée"
}

create_user_guide() {
    log_info "Création du guide utilisateur..."
    
    local root_dir="$WORK_DIR/mnt/root"
    
    cat > "$root_dir/home/pi/ASSISTANT_GUIDE.md" << 'EOF'
# Guide d'utilisation - Assistant Personnel Raspberry Pi 5

## 🚀 Première utilisation

1. **Branchez et démarrez** votre Raspberry Pi 5
2. **Connectez-vous** (utilisateur: `pi`, pas de mot de passe par défaut)
3. **Configurez WiFi**: `sudo raspi-config` → Network Options → Wi-Fi
4. **Configurez votre clé API Claude**:
   ```bash
   export ANTHROPIC_API_KEY="votre_clé_anthropic"
   echo 'export ANTHROPIC_API_KEY="votre_clé"' >> ~/.bashrc
   ```

## 🎤 Utilisation vocale

- **Démarrer l'écoute**: "Hey Assistant" ou touchez l'écran
- **Commandes vocales**: Parlez naturellement
- **Arrêter**: "Stop" ou touchez à nouveau

## 🖥️ Interface tactile

- **Bouton micro**: Activer/désactiver l'écoute
- **Zone de texte**: Saisie manuelle
- **Paramètres**: Réglages système et volume
- **Statut**: Informations CPU, mémoire, batterie

## 🔧 Commandes système

```bash
# Démarrer l'assistant
sudo systemctl start raspberry-assistant

# Arrêter l'assistant
sudo systemctl stop raspberry-assistant

# Statut du service
sudo systemctl status raspberry-assistant

# Logs
journalctl -u raspberry-assistant -f

# Mode test interactif
/opt/raspberry-assistant/python/main_service.py --interactive
```

## 🛠️ Dépannage

### Audio ne fonctionne pas
```bash
# Tester la sortie audio
speaker-test -t sine -f 1000 -l 2

# Ajuster le volume
amixer set Master 80%
```

### Interface ne s'affiche pas
```bash
# Vérifier l'affichage
export QT_QPA_PLATFORM=eglfs
/opt/raspberry-assistant/bin/RaspberryAssistant
```

### Problème réseau Claude
```bash
# Tester la connectivité
curl -I https://api.anthropic.com

# Vérifier la clé API
echo $ANTHROPIC_API_KEY
```

## 📚 Plus d'informations

- Configuration: `/opt/raspberry-assistant/config/`
- Logs: `/tmp/assistant_service.log`
- Documentation: `/opt/raspberry-assistant/README.md`

Bon usage de votre Assistant Personnel ! 🤖
EOF
    
    chown pi:pi "$root_dir/home/pi/ASSISTANT_GUIDE.md"
    
    log_success "Guide utilisateur créé"
}

cleanup_chroot() {
    log_info "Nettoyage de l'environnement chroot..."
    
    local root_dir="$WORK_DIR/mnt/root"
    
    # Nettoyer les fichiers temporaires
    rm -f "$root_dir/tmp/install_assistant.sh"
    rm -f "$root_dir/etc/resolv.conf"
    rm -f "$root_dir/usr/bin/qemu-aarch64-static"
    
    # Démonter les pseudo-filesystems
    umount "$root_dir/dev/pts" || true
    umount "$root_dir/dev" || true
    umount "$root_dir/sys" || true
    umount "$root_dir/proc" || true
    
    log_success "Chroot nettoyé"
}

unmount_image() {
    log_info "Démontage de l'image..."
    
    cd "$WORK_DIR"
    
    # Démonter les partitions
    umount mnt/boot || true
    umount mnt/root || true
    
    # Supprimer les mappings
    if [[ -f loop_device.txt ]]; then
        local loop_device=$(cat loop_device.txt)
        kpartx -d "/dev/$loop_device" || true
        losetup -d "/dev/$loop_device" || true
    fi
    
    log_success "Image démontée"
}

finalize_image() {
    log_info "Finalisation de l'image..."
    
    cd "$WORK_DIR"
    
    # Compresser l'image finale
    log_info "Compression de l'image finale..."
    
    # Copier vers la destination finale
    cp "work-image.img" "$FINAL_IMAGE"
    
    # Calculer les checksums
    sha256sum "$FINAL_IMAGE" > "$FINAL_IMAGE.sha256"
    
    # Créer un fichier d'informations
    cat > "$FINAL_IMAGE.info" << EOF
Assistant Personnel Raspberry Pi 5 - Image SD
===========================================

Image: $IMAGE_NAME
Créée: $(date)
Taille: $(du -h "$FINAL_IMAGE" | cut -f1)

Basée sur: Raspberry Pi OS Lite (ARM64)
Inclut: Assistant Personnel avec Claude Haiku

Installation:
1. Flasher l'image sur microSD (256GB recommandé)
2. Brancher sur Raspberry Pi 5
3. Suivre le guide dans /home/pi/ASSISTANT_GUIDE.md

⚠️  N'oubliez pas de configurer votre clé API Anthropic
EOF
    
    log_success "Image finalisée: $FINAL_IMAGE"
}

cleanup() {
    log_info "Nettoyage final..."
    
    # Nettoyage en cas d'interruption
    cleanup_chroot
    unmount_image
    
    # Supprimer le répertoire de travail (optionnel)
    if [[ -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
    fi
}

show_summary() {
    log_success "Création d'image terminée avec succès!"
    echo ""
    echo "📁 Fichiers créés:"
    echo "   - Image: $FINAL_IMAGE"
    echo "   - Checksum: $FINAL_IMAGE.sha256" 
    echo "   - Informations: $FINAL_IMAGE.info"
    echo ""
    echo "💾 Installation:"
    echo "1. Flasher l'image sur microSD 256GB avec Raspberry Pi Imager"
    echo "2. Insérer dans Raspberry Pi 5 et démarrer"
    echo "3. Suivre le guide de configuration initial"
    echo ""
    echo "🔑 Important: Configurez votre clé API Anthropic au premier démarrage"
    echo "   export ANTHROPIC_API_KEY='votre_clé_ici'"
}

# Gestion des signaux pour nettoyage
trap cleanup EXIT INT TERM

main() {
    echo "🤖 Création d'image microSD - Assistant Personnel Raspberry Pi 5"
    echo "=============================================================="
    
    check_dependencies
    download_base_image
    resize_image
    mount_image
    setup_chroot
    install_assistant
    configure_system
    create_user_guide
    cleanup_chroot
    unmount_image
    finalize_image
    
    show_summary
}

# Options de ligne de commande
case "${1:-}" in
    --help|-h)
        echo "Usage: sudo $0 [options]"
        echo ""
        echo "Ce script crée une image microSD complète avec l'Assistant Personnel"
        echo "pré-installé pour Raspberry Pi 5."
        echo ""
        echo "⚠️  Attention: Nécessite sudo et plusieurs GB d'espace disque"
        echo ""
        echo "Options:"
        echo "  --help, -h    Affiche cette aide"
        echo "  --clean       Nettoie les fichiers temporaires"
        exit 0
        ;;
    --clean)
        log_info "Nettoyage des fichiers temporaires..."
        rm -rf "$WORK_DIR"
        rm -f "$PROJECT_ROOT"/raspberry-assistant-*.img*
        log_success "Nettoyage terminé"
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log_error "Option inconnue: $1"
        echo "Utilisez --help pour l'aide"
        exit 1
        ;;
esac