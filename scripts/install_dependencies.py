#!/usr/bin/env python3
"""
Gestionnaire de requirements et dépendances pour Raspberry Pi 5
Installation automatique et optimisée
"""

import os
import subprocess
import sys
from pathlib import Path

# Dépendances Python requises
PYTHON_REQUIREMENTS = [
    "aiohttp>=3.8.0",
    "psutil>=5.9.0", 
    "SpeechRecognition>=3.10.0",
    "pyttsx3>=2.90",
    "asyncio-mqtt>=0.11.0",  # Pour extensions futures IoT
]

# Dépendances système Ubuntu/Debian pour Raspberry Pi OS
SYSTEM_PACKAGES = [
    # Audio et synthèse vocale
    "espeak-ng",
    "espeak-ng-data", 
    "alsa-utils",
    "pulseaudio",
    "python3-pyaudio",
    
    # Développement et compilation
    "build-essential",
    "cmake",
    "git",
    
    # Qt 6 pour Raspberry Pi OS
    "qt6-base-dev",
    "qt6-declarative-dev", 
    "qt6-quick-dev",
    "qt6-multimedia-dev",
    "qml6-module-qtquick",
    "qml6-module-qtquick-controls",
    
    # Outils système
    "htop",
    "curl",
    "wget",
    "vim",
]

# Configuration EGLFS pour mode headless
EGLFS_CONFIG = {
    "device": "/dev/dri/card1",
    "hwcursor": False,
    "pbuffers": True,
    "surfaceType": "window",
    "outputs": [
        {
            "name": "DSI1",
            "mode": "1920x1080",
            "physicalWidth": 155,
            "physicalHeight": 87,
            "scale": 1.0
        }
    ]
}


def run_command(cmd, check=True, capture_output=False):
    """Exécute une commande avec gestion d'erreur"""
    print(f"Exécution: {' '.join(cmd) if isinstance(cmd, list) else cmd}")
    
    try:
        if isinstance(cmd, str):
            result = subprocess.run(cmd, shell=True, check=check, 
                                  capture_output=capture_output, text=True)
        else:
            result = subprocess.run(cmd, check=check, 
                                  capture_output=capture_output, text=True)
        
        if capture_output:
            return result.stdout.strip()
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Erreur: {e}")
        if capture_output:
            return None
        return False


def check_python_version():
    """Vérifie la version Python"""
    version = sys.version_info
    print(f"🐍 Python {version.major}.{version.minor}.{version.micro}")
    
    if version.major != 3 or version.minor < 9:
        print("⚠️  Python 3.9+ requis")
        return False
    
    print("✅ Version Python compatible")
    return True


def update_system():
    """Met à jour le système"""
    print("\n📦 Mise à jour du système...")
    
    commands = [
        "sudo apt-get update",
        "sudo apt-get upgrade -y"
    ]
    
    for cmd in commands:
        if not run_command(cmd):
            print("❌ Erreur lors de la mise à jour système")
            return False
    
    print("✅ Système mis à jour")
    return True


def install_system_packages():
    """Installation des paquets système"""
    print("\n📦 Installation des dépendances système...")
    
    # Installation en lot pour optimiser
    packages_str = " ".join(SYSTEM_PACKAGES)
    cmd = f"sudo apt-get install -y {packages_str}"
    
    if not run_command(cmd):
        print("❌ Erreur installation paquets système")
        return False
    
    print("✅ Dépendances système installées")
    return True


def install_python_packages():
    """Installation des dépendances Python"""
    print("\n🐍 Installation des dépendances Python...")
    
    # Mise à jour pip
    if not run_command([sys.executable, "-m", "pip", "install", "--upgrade", "pip"]):
        print("⚠️  Impossible de mettre à jour pip")
    
    # Installation des requirements
    for requirement in PYTHON_REQUIREMENTS:
        print(f"   Installant {requirement}...")
        cmd = [sys.executable, "-m", "pip", "install", requirement]
        
        if not run_command(cmd):
            print(f"❌ Erreur installation {requirement}")
            return False
    
    print("✅ Dépendances Python installées")
    return True


def setup_audio_config():
    """Configuration audio pour Raspberry Pi"""
    print("\n🔊 Configuration audio...")
    
    # Configuration ALSA
    alsa_config = """
# Configuration ALSA pour Assistant
pcm.!default {
    type pulse
}
ctl.!default {
    type pulse
}
"""
    
    try:
        home_dir = Path.home()
        asoundrc_path = home_dir / ".asoundrc"
        
        with open(asoundrc_path, 'w') as f:
            f.write(alsa_config)
        
        print(f"✅ Configuration ALSA: {asoundrc_path}")
        
        # Démarrer PulseAudio
        run_command("pulseaudio --start", check=False)
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur configuration audio: {e}")
        return False


def setup_eglfs_config():
    """Configuration EGLFS pour Qt"""
    print("\n🖥️  Configuration EGLFS...")
    
    try:
        config_dir = Path("/opt/raspberry-assistant/config")
        config_dir.mkdir(parents=True, exist_ok=True)
        
        eglfs_path = config_dir / "eglfs_config.json"
        
        import json
        with open(eglfs_path, 'w') as f:
            json.dump(EGLFS_CONFIG, f, indent=2)
        
        print(f"✅ Configuration EGLFS: {eglfs_path}")
        return True
        
    except Exception as e:
        print(f"❌ Erreur configuration EGLFS: {e}")
        return False


def create_systemd_service():
    """Crée le service systemd pour auto-démarrage"""
    print("\n🚀 Configuration service systemd...")
    
    service_content = """[Unit]
Description=Assistant Personnel Raspberry Pi
After=network.target sound.target
Wants=network.target

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=/opt/raspberry-assistant
ExecStart=/usr/bin/python3 /opt/raspberry-assistant/python/main_service.py --daemon
Environment=QT_QPA_PLATFORM=eglfs
Environment=QT_QPA_EGLFS_KMS_CONFIG=/opt/raspberry-assistant/config/eglfs_config.json
Environment=ANTHROPIC_API_KEY=your_api_key_here
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
"""
    
    try:
        service_path = Path("/etc/systemd/system/raspberry-assistant.service")
        
        # Écrire le fichier service (nécessite sudo)
        cmd = f"sudo tee {service_path}"
        process = subprocess.Popen(cmd, shell=True, stdin=subprocess.PIPE, text=True)
        process.communicate(input=service_content)
        
        if process.returncode == 0:
            # Recharger systemd
            run_command("sudo systemctl daemon-reload")
            print(f"✅ Service systemd créé: {service_path}")
            print("   Pour activer: sudo systemctl enable raspberry-assistant")
            print("   Pour démarrer: sudo systemctl start raspberry-assistant")
            return True
        else:
            print("❌ Erreur création service systemd")
            return False
            
    except Exception as e:
        print(f"❌ Erreur service systemd: {e}")
        return False


def setup_permissions():
    """Configure les permissions système"""
    print("\n🔐 Configuration des permissions...")
    
    try:
        # Ajouter l'utilisateur aux groupes audio
        current_user = os.getenv('USER', 'pi')
        
        groups = ['audio', 'pulse', 'pulse-access']
        for group in groups:
            cmd = f"sudo usermod -a -G {group} {current_user}"
            run_command(cmd, check=False)  # Certains groupes peuvent ne pas exister
        
        # Permissions pour le dossier d'installation
        run_command("sudo chown -R pi:pi /opt/raspberry-assistant", check=False)
        run_command("sudo chmod -R 755 /opt/raspberry-assistant", check=False)
        
        print("✅ Permissions configurées")
        return True
        
    except Exception as e:
        print(f"❌ Erreur permissions: {e}")
        return False


def create_desktop_entry():
    """Crée une entrée pour le menu desktop (optionnel)"""
    print("\n🖥️  Création entrée desktop...")
    
    desktop_content = """[Desktop Entry]
Name=Assistant Personnel
Comment=Assistant IA avec Claude Haiku
Exec=/opt/raspberry-assistant/bin/RaspberryAssistant
Icon=/opt/raspberry-assistant/resources/assistant-icon.png
Type=Application
Categories=Utility;Audio;
Terminal=false
StartupNotify=true
"""
    
    try:
        desktop_dir = Path.home() / ".local/share/applications"
        desktop_dir.mkdir(parents=True, exist_ok=True)
        
        desktop_path = desktop_dir / "raspberry-assistant.desktop"
        
        with open(desktop_path, 'w') as f:
            f.write(desktop_content)
        
        # Rendre exécutable
        run_command(f"chmod +x {desktop_path}")
        
        print(f"✅ Entrée desktop: {desktop_path}")
        return True
        
    except Exception as e:
        print(f"❌ Erreur entrée desktop: {e}")
        return False


def verify_installation():
    """Vérifie que l'installation est complète"""
    print("\n🔍 Vérification de l'installation...")
    
    checks = []
    
    # Vérifier Python packages
    for requirement in PYTHON_REQUIREMENTS:
        package_name = requirement.split('>=')[0].split('==')[0]
        try:
            __import__(package_name.replace('-', '_'))
            checks.append(f"✅ {package_name}")
        except ImportError:
            checks.append(f"❌ {package_name} manquant")
    
    # Vérifier commandes système
    system_commands = ['espeak-ng', 'aplay', 'cmake']
    for cmd in system_commands:
        if run_command(f"which {cmd}", capture_output=True):
            checks.append(f"✅ {cmd}")
        else:
            checks.append(f"❌ {cmd} manquant")
    
    # Afficher résultats
    for check in checks:
        print(f"   {check}")
    
    # Compter les erreurs
    errors = [c for c in checks if '❌' in c]
    if errors:
        print(f"\n⚠️  {len(errors)} problème(s) détecté(s)")
        return False
    else:
        print("\n✅ Installation vérifiée avec succès")
        return True


def main():
    """Installation complète"""
    print("🤖 Installation Assistant Personnel Raspberry Pi 5")
    print("=" * 50)
    
    steps = [
        ("Vérification Python", check_python_version),
        ("Mise à jour système", update_system),
        ("Installation paquets système", install_system_packages),
        ("Installation Python", install_python_packages),
        ("Configuration audio", setup_audio_config),
        ("Configuration EGLFS", setup_eglfs_config),
        ("Service systemd", create_systemd_service),
        ("Permissions", setup_permissions),
        ("Entrée desktop", create_desktop_entry),
        ("Vérification", verify_installation),
    ]
    
    success_count = 0
    
    for step_name, step_func in steps:
        print(f"\n{'='*20} {step_name} {'='*20}")
        
        try:
            if step_func():
                success_count += 1
            else:
                print(f"⚠️  Étape '{step_name}' échouée")
        except KeyboardInterrupt:
            print("\n\n❌ Installation interrompue par l'utilisateur")
            return 1
        except Exception as e:
            print(f"❌ Erreur dans '{step_name}': {e}")
    
    print(f"\n{'='*50}")
    print(f"Installation terminée: {success_count}/{len(steps)} étapes réussies")
    
    if success_count == len(steps):
        print("\n🎉 Installation complète avec succès!")
        print("\nProcédure post-installation:")
        print("1. Configurez votre clé API Anthropic:")
        print("   export ANTHROPIC_API_KEY='your_key_here'")
        print("2. Compilez l'application Qt:")
        print("   cd /opt/raspberry-assistant && mkdir build && cd build")
        print("   cmake .. && make")
        print("3. Activez le service:")
        print("   sudo systemctl enable raspberry-assistant")
        print("   sudo systemctl start raspberry-assistant")
        return 0
    else:
        print(f"\n⚠️  Installation incomplète ({len(steps)-success_count} erreurs)")
        return 1


if __name__ == "__main__":
    sys.exit(main())