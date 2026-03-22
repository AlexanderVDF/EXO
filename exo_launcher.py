"""
EXO Assistant Launcher
Lance tous les services backend puis la GUI.
Usage : python exo_launcher.py
"""

import os
import sys
import time
import signal
import subprocess
from pathlib import Path

# ── Chemins projet ───────────────────────────────────────────────
PROJECT_DIR = Path(__file__).resolve().parent
SSD_ROOT = Path("D:/EXO")
LOG_DIR = SSD_ROOT / "logs"

VENV_MAIN = PROJECT_DIR / ".venv" / "Scripts" / "python.exe"
VENV_STT_TTS = PROJECT_DIR / ".venv_stt_tts" / "Scripts" / "python.exe"

GUI_EXE = PROJECT_DIR / "build" / "Debug" / "RaspberryAssistant.exe"

# ── Variables d'environnement EXO ────────────────────────────────
EXO_ENV = {
    "EXO_WHISPER_MODELS":  str(SSD_ROOT / "models" / "whisper"),
    "EXO_WHISPERCPP_BIN":  str(SSD_ROOT / "whispercpp" / "build_vk" / "bin" / "Release"),
    "EXO_XTTS_MODELS":     str(SSD_ROOT / "models" / "xtts"),
    "EXO_FAISS_DIR":       str(SSD_ROOT / "faiss" / "semantic_memory"),
    "EXO_WAKEWORD_MODELS": str(SSD_ROOT / "models" / "wakeword"),
    "HF_HOME":             str(SSD_ROOT / "cache" / "huggingface"),
    "TRANSFORMERS_CACHE":  str(SSD_ROOT / "cache" / "huggingface" / "hub"),
}

# ── Définition des services ──────────────────────────────────────
# (nom, python_exe, script, arguments)
SERVICES = [
    ("STT Server",      VENV_STT_TTS, "python/stt/stt_server.py",
     ["--backend", "whispercpp", "--model", "medium", "--beam-size", "3", "--language", "fr"]),
    ("TTS Server",      VENV_STT_TTS, "python/tts/tts_server_directml.py",
     ["--voice", "Claribel Dervla", "--lang", "fr"]),
    ("VAD Server",      VENV_STT_TTS, "python/vad/vad_server.py", []),
    ("Wakeword Server", VENV_STT_TTS, "python/wakeword/wakeword_server.py", []),
    ("Memory Server",   VENV_STT_TTS, "python/memory/memory_server.py", []),
    ("NLU Server",      VENV_STT_TTS, "python/nlu/nlu_server.py", []),
    ("Orchestrator",    VENV_MAIN,    "python/orchestrator/exo_server.py", []),
]

# ── Processus lancés ─────────────────────────────────────────────
processes: dict[str, subprocess.Popen] = {}


def build_env() -> dict[str, str]:
    """Construit l'environnement complet pour les sous-processus."""
    env = os.environ.copy()
    env.update(EXO_ENV)

    # Charger .env si présent
    env_file = PROJECT_DIR / ".env"
    if env_file.exists():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, _, value = line.partition("=")
                env[key.strip()] = value.strip()

    # Qt dans le PATH
    qt_bin = r"C:\Qt\6.9.3\msvc2022_64\bin"
    if qt_bin not in env.get("PATH", ""):
        env["PATH"] = qt_bin + ";" + env.get("PATH", "")

    return env


def start_services() -> None:
    """Lance tous les services backend séquentiellement."""
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    env = build_env()

    for name, python_exe, script, args in SERVICES:
        script_path = PROJECT_DIR / script
        if not python_exe.exists():
            print(f"[LAUNCHER] SKIP {name} — venv introuvable : {python_exe}")
            continue
        if not script_path.exists():
            print(f"[LAUNCHER] SKIP {name} — script introuvable : {script_path}")
            continue

        cmd = [str(python_exe), str(script_path)] + args
        log_stem = script_path.stem
        stdout_log = LOG_DIR / f"{log_stem}_stdout.log"
        stderr_log = LOG_DIR / f"{log_stem}_stderr.log"

        print(f"[LAUNCHER] Starting {name}")
        proc = subprocess.Popen(
            cmd,
            cwd=str(PROJECT_DIR),
            env=env,
            stdout=open(stdout_log, "w", encoding="utf-8"),
            stderr=open(stderr_log, "w", encoding="utf-8"),
        )
        processes[name] = proc
        time.sleep(0.5)

    print(f"[LAUNCHER] {len(processes)} service(s) lancé(s)")


def start_gui() -> None:
    """Lance la GUI EXO (exécutable Qt)."""
    env = build_env()

    if GUI_EXE.exists():
        print(f"[LAUNCHER] GUI started ({GUI_EXE.name})")
        proc = subprocess.Popen(
            [str(GUI_EXE)],
            cwd=str(GUI_EXE.parent),
            env=env,
        )
        processes["GUI"] = proc
    else:
        print(f"[LAUNCHER] ERREUR — GUI introuvable : {GUI_EXE}")


def shutdown(signum=None, frame=None) -> None:
    """Arrête proprement tous les processus enfants."""
    print("\n[LAUNCHER] Arrêt en cours...")
    for name, proc in processes.items():
        if proc.poll() is None:
            print(f"[LAUNCHER] Stopping {name} (PID {proc.pid})")
            proc.terminate()
    # Laisser un délai pour arrêt propre
    for name, proc in processes.items():
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            print(f"[LAUNCHER] Killing {name} (PID {proc.pid})")
            proc.kill()
    print("[LAUNCHER] Tous les processus arrêtés.")


def main() -> None:
    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    print("=" * 60)
    print("  EXO Assistant Launcher")
    print("=" * 60)

    start_services()
    print(f"[LAUNCHER] Attente 2s avant lancement GUI...")
    time.sleep(2)
    start_gui()

    # Attendre que la GUI se ferme, puis tout arrêter
    gui_proc = processes.get("GUI")
    if gui_proc:
        try:
            gui_proc.wait()
        except KeyboardInterrupt:
            pass
    shutdown()


if __name__ == "__main__":
    main()
