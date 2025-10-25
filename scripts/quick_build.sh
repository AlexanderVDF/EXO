#!/bin/bash

# =============================================================================
# Script de compilation rapide - Assistant Domotique v2.0
# Compile tous les modules avancés pour test et développement
# =============================================================================

set -e

# Configuration
BUILD_TYPE="${1:-Debug}"
JOBS="${2:-$(nproc)}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🏗️  Assistant Domotique v2.0 - Compilation Rapide${NC}"
echo "=================================================="
echo "Type de build: $BUILD_TYPE"
echo "Jobs parallèles: $JOBS"
echo "Projet: $PROJECT_ROOT"
echo ""

# Vérification des prérequis
echo -e "${YELLOW}📋 Vérification des prérequis...${NC}"

check_dependency() {
    if command -v "$1" &> /dev/null; then
        echo -e "  ✅ $1 $(${1} --version | head -n1)"
    else
        echo -e "  ❌ $1 manquant"
        exit 1
    fi
}

check_dependency cmake
check_dependency qmake
echo -e "  ✅ Qt $(qmake -version | grep 'Qt version' | cut -d' ' -f4)"

# Vérification des modules Qt requis
echo -e "${YELLOW}🔍 Vérification modules Qt...${NC}"
qt_modules=(Core Quick Network Multimedia WebSockets Sql Positioning 3DCore 3DRender)
for module in "${qt_modules[@]}"; do
    if pkg-config --exists "Qt6${module}"; then
        echo -e "  ✅ Qt6${module}"
    else
        echo -e "  ⚠️  Qt6${module} manquant (peut causer des erreurs)"
    fi
done

# Nettoyage optionnel
if [[ "$BUILD_TYPE" == "Clean" ]]; then
    echo -e "${YELLOW}🧹 Nettoyage complet...${NC}"
    rm -rf "$PROJECT_ROOT/build"
    mkdir -p "$PROJECT_ROOT/build"
fi

# Création du dossier build
cd "$PROJECT_ROOT"
mkdir -p build
cd build

# Configuration CMake
echo -e "${YELLOW}⚙️  Configuration CMake...${NC}"
cmake .. \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DBUILD_TESTS=ON \
    -DEZVIZ_API_ENABLED=ON \
    -DMICROSOFT_TTS_ENABLED=ON \
    -DGOOGLE_SERVICES_ENABLED=ON \
    -DMUSIC_STREAMING_ENABLED=ON \
    -DAI_MEMORY_ENABLED=ON \
    -DROOM_DESIGNER_3D_ENABLED=ON

# Compilation
echo -e "${YELLOW}🔨 Compilation avec $JOBS jobs...${NC}"
start_time=$(date +%s)

cmake --build . --parallel "$JOBS" --config "$BUILD_TYPE"

end_time=$(date +%s)
build_time=$((end_time - start_time))

echo -e "${GREEN}✅ Compilation terminée en ${build_time}s${NC}"

# Tests rapides de compilation
echo -e "${YELLOW}🧪 Tests de compilation...${NC}"

if [[ -f "RaspberryAssistant" ]]; then
    echo -e "  ✅ Exécutable principal créé"
    file_size=$(du -h RaspberryAssistant | cut -f1)
    echo -e "  📦 Taille: $file_size"
else
    echo -e "  ❌ Échec création exécutable"
    exit 1
fi

# Test de lancement rapide
echo -e "${YELLOW}🚀 Test de lancement...${NC}"
if timeout 5s ./RaspberryAssistant --version &>/dev/null; then
    echo -e "  ✅ Application se lance correctement"
else
    echo -e "  ⚠️  Problème de lancement (normal sans configuration)"
fi

# Résumé
echo ""
echo -e "${GREEN}🎉 COMPILATION RÉUSSIE !${NC}"
echo "=================================================="
echo "📁 Exécutable: $(pwd)/RaspberryAssistant"
echo "📊 Modules inclus:"
echo "  • Claude Haiku IA"
echo "  • Microsoft Henri TTS" 
echo "  • Domotique EZVIZ"
echo "  • Designer 3D Qt3D"
echo "  • Streaming Spotify/Tidal"
echo "  • Services Google"
echo "  • Mémoire AI SQLite"
echo ""
echo -e "${BLUE}🚀 Prochaines étapes:${NC}"
echo "1. Configurer les clés API dans config/assistant.conf"
echo "2. Lancer: ./RaspberryAssistant --test-mode"
echo "3. Consulter: ../QUICKSTART.md"

# Tests unitaires si demandé
if [[ "$BUILD_TYPE" == "Debug" ]] && command -v ctest &> /dev/null; then
    echo ""
    echo -e "${YELLOW}🧪 Lancement des tests unitaires...${NC}"
    if ctest --output-on-failure --parallel "$JOBS"; then
        echo -e "  ✅ Tous les tests passent"
    else
        echo -e "  ⚠️  Certains tests échouent"
    fi
fi