#!/usr/bin/env python3
"""
Script de build rapide pour développement local
Compilation et test sur Windows avant cross-compilation
"""

import os
import subprocess
import sys
import shutil
from pathlib import Path
import argparse

# Configuration
PROJECT_ROOT = Path(__file__).parent.parent
BUILD_DIR = PROJECT_ROOT / "build"
INSTALL_DIR = PROJECT_ROOT / "install"

def run_command(cmd, cwd=None, shell=True):
    """Exécute une commande"""
    print(f"Exécution: {cmd}")
    try:
        result = subprocess.run(cmd, shell=shell, cwd=cwd, check=True, 
                               capture_output=True, text=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"❌ Erreur: {e}")
        print(f"Sortie: {e.stdout}")
        print(f"Erreur: {e.stderr}")
        return None

def check_qt():
    """Vérifie la disponibilité de Qt"""
    print("🔍 Vérification de Qt...")
    
    # Essayer de trouver Qt
    qt_paths = [
        "C:/Qt/6.5.0/msvc2022_64",
        "C:/Qt/6.6.0/msvc2022_64", 
        "C:/Qt/Tools/CMake_64/bin",
    ]
    
    qt_dir = None
    for path in qt_paths:
        if Path(path).exists():
            qt_dir = path
            break
    
    if qt_dir:
        print(f"✅ Qt trouvé: {qt_dir}")
        return qt_dir
    else:
        print("❌ Qt non trouvé. Installez Qt 6.5+ avec Qt Creator")
        return None

def clean_build():
    """Nettoie les répertoires de build"""
    print("🧹 Nettoyage...")
    
    for dir_path in [BUILD_DIR, INSTALL_DIR]:
        if dir_path.exists():
            shutil.rmtree(dir_path)
            print(f"   Supprimé: {dir_path}")
    
    print("✅ Nettoyage terminé")

def configure_cmake(qt_dir=None, build_type="Debug"):
    """Configure le projet avec CMake"""
    print(f"⚙️ Configuration CMake ({build_type})...")
    
    BUILD_DIR.mkdir(exist_ok=True)
    
    cmake_args = [
        "cmake",
        f"-DCMAKE_BUILD_TYPE={build_type}",
        f"-DCMAKE_INSTALL_PREFIX={INSTALL_DIR}",
        "-DCMAKE_PREFIX_PATH=" + (qt_dir if qt_dir else ""),
        str(PROJECT_ROOT)
    ]
    
    if run_command(" ".join(cmake_args), cwd=BUILD_DIR):
        print("✅ Configuration réussie")
        return True
    else:
        print("❌ Échec de la configuration")
        return False

def build_project():
    """Compile le projet"""
    print("🔨 Compilation...")
    
    if sys.platform == "win32":
        build_cmd = "cmake --build . --config Debug"
    else:
        build_cmd = "make -j$(nproc)"
    
    if run_command(build_cmd, cwd=BUILD_DIR):
        print("✅ Compilation réussie")
        return True
    else:
        print("❌ Échec de la compilation")
        return False

def install_project():
    """Installe le projet"""
    print("📦 Installation...")
    
    install_cmd = "cmake --build . --target install"
    
    if run_command(install_cmd, cwd=BUILD_DIR):
        print("✅ Installation réussie")
        return True
    else:
        print("❌ Échec de l'installation")
        return False

def setup_python_env():
    """Configure l'environnement Python"""
    print("🐍 Configuration Python...")
    
    # Vérifier Python
    python_version = run_command("python --version")
    if not python_version:
        print("❌ Python non trouvé")
        return False
    
    print(f"   {python_version.strip()}")
    
    # Installer les dépendances
    requirements = [
        "aiohttp",
        "psutil", 
        "SpeechRecognition",
        "pyttsx3",
    ]
    
    for req in requirements:
        print(f"   Installation de {req}...")
        if not run_command(f"pip install {req}"):
            print(f"❌ Échec installation {req}")
            return False
    
    print("✅ Environnement Python configuré")
    return True

def test_python_services():
    """Test des services Python"""
    print("🧪 Test des services Python...")
    
    # Test du service Claude
    claude_script = PROJECT_ROOT / "python" / "claude_service.py"
    if claude_script.exists():
        print("   Test service Claude...")
        result = run_command(f"python {claude_script} --test", 
                           cwd=PROJECT_ROOT)
        if result and "success" in result.lower():
            print("   ✅ Service Claude OK")
        else:
            print("   ⚠️  Service Claude - vérifiez la clé API")
    
    # Test monitoring système
    monitor_script = PROJECT_ROOT / "python" / "system_monitor.py" 
    if monitor_script.exists():
        print("   Test monitoring système...")
        result = run_command(f"python {monitor_script} --stats", 
                           cwd=PROJECT_ROOT)
        if result:
            print("   ✅ Monitoring système OK")
    
    print("✅ Tests Python terminés")

def run_application():
    """Lance l'application"""
    print("🚀 Lancement de l'application...")
    
    if sys.platform == "win32":
        exe_path = BUILD_DIR / "Debug" / "RaspberryAssistant.exe"
    else:
        exe_path = BUILD_DIR / "RaspberryAssistant"
    
    if exe_path.exists():
        print(f"Lancement: {exe_path}")
        # Lancer sans attendre la fin
        subprocess.Popen([str(exe_path)], cwd=BUILD_DIR)
        print("✅ Application lancée")
    else:
        print(f"❌ Exécutable non trouvé: {exe_path}")

def show_summary():
    """Affiche le résumé"""
    print("\n" + "="*50)
    print("📋 Résumé du build")
    print("="*50)
    
    print(f"Projet: {PROJECT_ROOT}")
    print(f"Build: {BUILD_DIR}")
    print(f"Install: {INSTALL_DIR}")
    
    if BUILD_DIR.exists():
        print("\n📁 Fichiers générés:")
        for file in BUILD_DIR.rglob("*.exe"):
            print(f"   {file}")
        for file in BUILD_DIR.rglob("RaspberryAssistant"):
            if file.is_file():
                print(f"   {file}")
    
    print("\n🎯 Prochaines étapes:")
    print("1. Testez l'application localement")
    print("2. Configurez votre clé API Claude:")
    print("   set ANTHROPIC_API_KEY=your_key")
    print("3. Pour Raspberry Pi:")
    print("   ./scripts/cross_compile_rpi.sh")

def main():
    parser = argparse.ArgumentParser(description="Build Assistant Personnel")
    parser.add_argument("--clean", action="store_true", 
                       help="Nettoyer avant build")
    parser.add_argument("--release", action="store_true",
                       help="Build en mode Release")
    parser.add_argument("--no-python", action="store_true",
                       help="Ignorer la configuration Python")
    parser.add_argument("--no-run", action="store_true",
                       help="Ne pas lancer l'application")
    parser.add_argument("--test-only", action="store_true",
                       help="Tests seulement")
    
    args = parser.parse_args()
    
    print("🤖 Build Assistant Personnel - Version Développement")
    print("="*50)
    
    if args.clean:
        clean_build()
    
    if args.test_only:
        if not args.no_python:
            setup_python_env()
            test_python_services()
        return
    
    # Configuration Python
    if not args.no_python:
        if not setup_python_env():
            print("⚠️  Configuration Python échouée")
    
    # Vérification Qt
    qt_dir = check_qt()
    if not qt_dir:
        print("❌ Qt requis pour la compilation")
        return 1
    
    # Build
    build_type = "Release" if args.release else "Debug"
    
    if not configure_cmake(qt_dir, build_type):
        return 1
    
    if not build_project():
        return 1
    
    # Installation (optionnelle)
    # install_project()
    
    # Tests Python
    if not args.no_python:
        test_python_services()
    
    # Lancement
    if not args.no_run:
        run_application()
    
    show_summary()
    return 0

if __name__ == "__main__":
    sys.exit(main())