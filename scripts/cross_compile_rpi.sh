#!/bin/bash
# Script de compilation croisée pour Raspberry Pi 5 (ARM64)
# À exécuter sur machine de développement Windows/Linux

set -e  # Arrêt en cas d'erreur

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build-rpi"
INSTALL_DIR="$PROJECT_ROOT/install-rpi"
TARGET_ARCH="aarch64-linux-gnu"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonctions utilitaires
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    log_info "Vérification des dépendances de cross-compilation..."
    
    # Vérifier cmake
    if ! command -v cmake &> /dev/null; then
        log_error "CMake non trouvé. Installez CMake 3.21+."
        exit 1
    fi
    
    local cmake_version=$(cmake --version | head -n1 | sed 's/cmake version //')
    log_info "CMake version: $cmake_version"
    
    # Vérifier le toolchain cross-compilation
    if ! command -v ${TARGET_ARCH}-gcc &> /dev/null; then
        log_warning "Toolchain ${TARGET_ARCH} non trouvé."
        log_info "Installation du toolchain..."
        
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt-get update
            sudo apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
        elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
            log_error "Sous Windows, utilisez WSL2 ou installez MSYS2 avec mingw-w64"
            exit 1
        else
            log_error "OS non supporté pour cross-compilation: $OSTYPE"
            exit 1
        fi
    fi
    
    log_success "Dépendances vérifiées"
}

download_qt_rpi() {
    log_info "Configuration Qt pour Raspberry Pi..."
    
    local qt_dir="$PROJECT_ROOT/qt-rpi"
    
    if [ ! -d "$qt_dir" ]; then
        log_info "Téléchargement de Qt 6 pour Raspberry Pi..."
        
        # Option 1: Qt pré-compilé pour RPi (si disponible)
        # mkdir -p "$qt_dir"
        # wget -O qt6-rpi.tar.xz "https://download.qt.io/online/qtsdkrepository/linux_x64/desktop/qt6_600/qt.qt6.600.gcc_64/"
        
        # Option 2: Utiliser Qt système (plus simple)
        log_warning "Utilisation de Qt système sur la cible"
        mkdir -p "$qt_dir"
        
        # Créer un fichier de configuration Qt
        cat > "$qt_dir/qt.conf" << EOF
[Paths]
Prefix=/usr
Libraries=/usr/lib/aarch64-linux-gnu
Plugins=/usr/lib/aarch64-linux-gnu/qt6/plugins
Qml2Imports=/usr/lib/aarch64-linux-gnu/qt6/qml
EOF
        
    else
        log_info "Qt pour RPi déjà configuré"
    fi
}

setup_sysroot() {
    log_info "Configuration du sysroot Raspberry Pi..."
    
    local sysroot_dir="$PROJECT_ROOT/rpi-sysroot"
    
    if [ ! -d "$sysroot_dir" ]; then
        log_warning "Sysroot RPi non trouvé. Cross-compilation limitée."
        log_info "Pour une cross-compilation complète:"
        log_info "1. Montez le système de fichiers RPi via NFS/SSH"
        log_info "2. Ou copiez /usr, /lib de votre RPi dans rpi-sysroot/"
        
        # Créer un sysroot minimal
        mkdir -p "$sysroot_dir/usr/include"
        mkdir -p "$sysroot_dir/usr/lib/aarch64-linux-gnu"
        
        return 0
    fi
    
    log_success "Sysroot configuré: $sysroot_dir"
}

create_toolchain_file() {
    log_info "Création du fichier toolchain CMake..."
    
    local toolchain_file="$BUILD_DIR/rpi-toolchain.cmake"
    
    cat > "$toolchain_file" << EOF
# Toolchain pour cross-compilation Raspberry Pi 5 (ARM64)
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# Spécifier le compilateur
set(CMAKE_C_COMPILER ${TARGET_ARCH}-gcc)
set(CMAKE_CXX_COMPILER ${TARGET_ARCH}-g++)

# Spécifier le sysroot (optionnel)
set(CMAKE_SYSROOT $PROJECT_ROOT/rpi-sysroot)

# Chercher les programmes seulement sur l'hôte
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)

# Chercher les bibliothèques et headers seulement dans le sysroot
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Configuration spécifique Raspberry Pi 5
set(CMAKE_CXX_FLAGS "\${CMAKE_CXX_FLAGS} -mcpu=cortex-a76 -mtune=cortex-a76")
set(CMAKE_C_FLAGS "\${CMAKE_C_FLAGS} -mcpu=cortex-a76 -mtune=cortex-a76")

# Configuration Qt (si sysroot disponible)
if(EXISTS "\${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/cmake/Qt6")
    set(Qt6_DIR "\${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/cmake/Qt6")
endif()

# Variables pour le packaging
set(CPACK_SYSTEM_NAME "RaspberryPi5-ARM64")
set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "arm64")
EOF

    log_success "Toolchain créé: $toolchain_file"
}

configure_build() {
    log_info "Configuration du build avec CMake..."
    
    # Nettoyer le répertoire de build
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$INSTALL_DIR"
    
    cd "$BUILD_DIR"
    
    # Créer le fichier toolchain
    create_toolchain_file
    
    # Configuration CMake avec cross-compilation
    local cmake_args=(
        -DCMAKE_TOOLCHAIN_FILE="$BUILD_DIR/rpi-toolchain.cmake"
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"
        -DRASPBERRY_PI=ON
        -DQt6_DIR="$PROJECT_ROOT/qt-rpi"
        "$PROJECT_ROOT"
    )
    
    log_info "Commande CMake: cmake ${cmake_args[*]}"
    
    if cmake "${cmake_args[@]}"; then
        log_success "Configuration CMake réussie"
    else
        log_error "Échec de la configuration CMake"
        exit 1
    fi
}

build_project() {
    log_info "Compilation du projet..."
    
    cd "$BUILD_DIR"
    
    # Compilation avec parallélisation
    local cpu_count=$(nproc 2>/dev/null || echo 4)
    
    if make -j$cpu_count; then
        log_success "Compilation réussie"
    else
        log_error "Échec de la compilation"
        exit 1
    fi
}

package_for_rpi() {
    log_info "Packaging pour Raspberry Pi..."
    
    cd "$BUILD_DIR"
    
    # Installation dans le répertoire d'install
    if make install; then
        log_success "Installation locale réussie"
    else
        log_error "Échec de l'installation"
        exit 1
    fi
    
    # Création d'un package tar.gz
    local package_name="raspberry-assistant-rpi5-$(date +%Y%m%d-%H%M%S).tar.gz"
    local package_path="$PROJECT_ROOT/$package_name"
    
    cd "$INSTALL_DIR"
    
    if tar -czf "$package_path" .; then
        log_success "Package créé: $package_path"
    else
        log_error "Échec de la création du package"
        exit 1
    fi
    
    # Créer le script d'installation pour RPi
    create_install_script "$package_name"
}

create_install_script() {
    local package_name="$1"
    local script_path="$PROJECT_ROOT/install-on-rpi.sh"
    
    log_info "Création du script d'installation RPi..."
    
    cat > "$script_path" << EOF
#!/bin/bash
# Script d'installation sur Raspberry Pi 5

set -e

PACKAGE_NAME="$package_name"
INSTALL_PREFIX="/opt/raspberry-assistant"

echo "🤖 Installation Assistant Personnel sur Raspberry Pi 5"
echo "=================================================="

# Vérification des prérequis
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 non trouvé"
    exit 1
fi

# Installation des dépendances système
echo "📦 Installation des dépendances..."
sudo apt-get update
sudo apt-get install -y qt6-base-dev qt6-declarative-dev espeak-ng python3-pip

# Extraction du package
echo "📂 Extraction des fichiers..."
sudo mkdir -p \$INSTALL_PREFIX
sudo tar -xzf \$PACKAGE_NAME -C \$INSTALL_PREFIX

# Installation des dépendances Python
echo "🐍 Installation dépendances Python..."
pip3 install aiohttp psutil SpeechRecognition pyttsx3

# Configuration des permissions
sudo chown -R pi:pi \$INSTALL_PREFIX
sudo chmod +x \$INSTALL_PREFIX/bin/*

# Configuration du service systemd
echo "🚀 Configuration du service..."
sudo cp \$INSTALL_PREFIX/config/raspberry-assistant.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable raspberry-assistant

echo "✅ Installation terminée!"
echo ""
echo "Configuration finale:"
echo "1. Configurez votre clé API: export ANTHROPIC_API_KEY='your_key'"
echo "2. Démarrez le service: sudo systemctl start raspberry-assistant"
echo "3. Ou lancez manuellement: \$INSTALL_PREFIX/bin/RaspberryAssistant"
EOF

    chmod +x "$script_path"
    log_success "Script d'installation créé: $script_path"
}

show_summary() {
    log_success "Compilation croisée terminée avec succès!"
    echo ""
    echo "📁 Fichiers générés:"
    echo "   - Binaires: $INSTALL_DIR/"
    echo "   - Package: $PROJECT_ROOT/raspberry-assistant-rpi5-*.tar.gz"
    echo "   - Script d'installation: $PROJECT_ROOT/install-on-rpi.sh"
    echo ""
    echo "📤 Déploiement sur Raspberry Pi:"
    echo "1. Copiez le package .tar.gz et install-on-rpi.sh sur votre RPi"
    echo "2. Sur le RPi: chmod +x install-on-rpi.sh && ./install-on-rpi.sh"
    echo ""
    echo "🔧 Alternative - Installation manuelle:"
    echo "   scp raspberry-assistant-rpi5-*.tar.gz pi@your-rpi:~/"
    echo "   ssh pi@your-rpi"
    echo "   sudo tar -xzf raspberry-assistant-rpi5-*.tar.gz -C /opt/"
}

# Point d'entrée principal
main() {
    echo "🤖 Compilation croisée - Assistant Personnel Raspberry Pi 5"
    echo "=========================================================="
    
    # Vérifications préliminaires
    check_dependencies
    
    # Téléchargement et configuration
    download_qt_rpi
    setup_sysroot
    
    # Compilation
    configure_build
    build_project
    
    # Packaging
    package_for_rpi
    
    # Résumé
    show_summary
}

# Options de ligne de commande
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h          Affiche cette aide"
        echo "  --clean             Nettoie les dossiers de build"
        echo "  --deps-only         Installe seulement les dépendances"
        echo ""
        echo "Ce script compile l'Assistant Personnel pour Raspberry Pi 5"
        echo "en utilisant la cross-compilation ARM64."
        exit 0
        ;;
    --clean)
        log_info "Nettoyage des dossiers de build..."
        rm -rf "$BUILD_DIR" "$INSTALL_DIR"
        rm -f "$PROJECT_ROOT"/raspberry-assistant-rpi5-*.tar.gz
        rm -f "$PROJECT_ROOT/install-on-rpi.sh"
        log_success "Nettoyage terminé"
        exit 0
        ;;
    --deps-only)
        check_dependencies
        download_qt_rpi
        setup_sysroot
        log_success "Dépendances configurées"
        exit 0
        ;;
    "")
        # Exécution normale
        main
        ;;
    *)
        log_error "Option inconnue: $1"
        echo "Utilisez --help pour voir les options disponibles"
        exit 1
        ;;
esac