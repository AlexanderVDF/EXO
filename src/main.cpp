#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QDir>
#include <QLoggingCategory>
#include <QStandardPaths>
#include <QFile>
#include <QTextStream>
#include <QDateTime>
#include <QFileInfo>

#ifdef _WIN32
#include <windows.h>
#include <io.h>
#include <fcntl.h>
#include <cstdio>
#include <dbghelp.h>
#pragma comment(lib, "dbghelp.lib")
#endif

#include <csignal>

#ifdef RASPBERRY_PI
#include <QGuiApplication>
#endif

#include "assistantmanager.h"
#include "logmanager.h"

// ═══════════════════════════════════════════════════════
//  Crash handler — write minidump + log before dying
// ═══════════════════════════════════════════════════════

static QString crashLogDir()
{
    QString dir = QStringLiteral("D:/EXO/logs");
    QDir().mkpath(dir);
    return dir;
}

#ifdef _WIN32
static LONG WINAPI exoUnhandledExceptionFilter(EXCEPTION_POINTERS *ep)
{
    // Write minidump
    QString dumpPath = crashLogDir() + "/exo_crash.dmp";
    HANDLE hFile = CreateFileW(reinterpret_cast<LPCWSTR>(dumpPath.utf16()),
                               GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
                               FILE_ATTRIBUTE_NORMAL, nullptr);
    if (hFile != INVALID_HANDLE_VALUE) {
        MINIDUMP_EXCEPTION_INFORMATION mei;
        mei.ThreadId = GetCurrentThreadId();
        mei.ExceptionPointers = ep;
        mei.ClientPointers = FALSE;
        MiniDumpWriteDump(GetCurrentProcess(), GetCurrentProcessId(), hFile,
                          MiniDumpNormal, &mei, nullptr, nullptr);
        CloseHandle(hFile);
    }

    // Append to crash log
    QString logPath = crashLogDir() + "/exo_crash.log";
    QFile logFile(logPath);
    if (logFile.open(QIODevice::Append | QIODevice::Text)) {
        QTextStream ts(&logFile);
        ts << "\n=== CRASH " << QDateTime::currentDateTime().toString(Qt::ISODate)
           << " === ExceptionCode: 0x" << Qt::hex << ep->ExceptionRecord->ExceptionCode
           << " Address: 0x" << reinterpret_cast<quintptr>(ep->ExceptionRecord->ExceptionAddress)
           << Qt::dec << " ===\n";
        ts << "Dump: " << dumpPath << "\n";
    }

    return EXCEPTION_EXECUTE_HANDLER;
}
#endif

static void exoSignalHandler(int sig)
{
    const char *name = (sig == SIGSEGV) ? "SIGSEGV"
                     : (sig == SIGABRT) ? "SIGABRT"
                     : (sig == SIGFPE)  ? "SIGFPE" : "UNKNOWN";

    // Best-effort file write (async-signal-safe is impossible with Qt, but
    // the process is about to die anyway — better to have *something* logged)
    QString logPath = crashLogDir() + "/exo_crash.log";
    QFile f(logPath);
    if (f.open(QIODevice::Append | QIODevice::Text)) {
        QTextStream ts(&f);
        ts << "\n=== SIGNAL " << name << " at "
           << QDateTime::currentDateTime().toString(Qt::ISODate) << " ===\n";
    }

    std::signal(sig, SIG_DFL);
    std::raise(sig);
}

int main(int argc, char *argv[])
{
    // Install crash handlers ASAP
#ifdef _WIN32
    SetUnhandledExceptionFilter(exoUnhandledExceptionFilter);
#endif
    std::signal(SIGSEGV, exoSignalHandler);
    std::signal(SIGABRT, exoSignalHandler);
    std::signal(SIGFPE,  exoSignalHandler);

    // Configuration console Windows uniquement en mode debug
#ifdef _WIN32
#ifdef QT_DEBUG
    AllocConsole();
    freopen_s((FILE**)stdout, "CONOUT$", "w", stdout);
    freopen_s((FILE**)stderr, "CONOUT$", "w", stderr);
    printf("=== EXO DEBUG CONSOLE ===\n");
#endif
#endif

    // Configuration de l'application selon la plateforme
#ifdef RASPBERRY_PI
    // Mode EGLFS pour Raspberry Pi (sans serveur X)
    qputenv("QT_QPA_PLATFORM", "eglfs");
    qputenv("QT_QPA_EGLFS_ALWAYS_SET_MODE", "1");
    qputenv("QT_QPA_EGLFS_PHYSICAL_WIDTH", "154");
    qputenv("QT_QPA_EGLFS_PHYSICAL_HEIGHT", "85");
    
    QGuiApplication app(argc, argv);
#else
    // Mode desktop pour développement
    QApplication app(argc, argv);
#endif

    // === Configuration de base de l'application ===
    app.setApplicationName("EXO Assistant");
    app.setApplicationVersion("4.2");
    app.setOrganizationName("EXOAssistant");
    app.setOrganizationDomain("exo-assistant.local");

    // Style Material Design
    QQuickStyle::setStyle("Material");
    qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME", "Dark");

    // Initialize LogManager with file logging ENABLED for crash diagnostics
    LogManager::instance()->initialize(LogManager::Debug, true, true);
    hLog() << "Fichier de log:" << LogManager::instance()->getRecentLogs();

    qInfo() << "=== Démarrage d'EXO Assistant v4.2 ===";
    qInfo() << "Plateforme:" 
#ifdef RASPBERRY_PI
                 << "Raspberry Pi 5 (EGLFS)"
#else
                 << "Développement Windows"
#endif
                 ;

    // === Initialisation avec AssistantManager réel ===
    
    qInfo() << "Démarrage EXO...";
    
    // Créer l'AssistantManager réel
    AssistantManager assistantManager;
    
    // Créer le moteur QML
    QQmlApplicationEngine engine;
    
    // Associer l'AssistantManager au moteur QML
    assistantManager.setQmlEngine(&engine);

    // === Chargement de l'interface QML ===
    
    // Configuration des chemins de ressources
    engine.addImportPath("qrc:/qml");
    engine.addImportPath(":/");
    
    // Exposer l'AssistantManager à QML
    engine.rootContext()->setContextProperty("assistantManager", &assistantManager);
    
    // Initialiser l'assistant avec la configuration
    assistantManager.initializeWithConfig();

    // Interface VS Code style - chemin relatif au répertoire de l'application
    QString appDir = QCoreApplication::applicationDirPath();
    // Remonter de build/Debug vers la racine du projet
    QDir projectDir(appDir);
    projectDir.cdUp(); // Debug -> build
    projectDir.cdUp(); // build -> racine

    // Ajouter le dossier qml comme import path pour les sous-dossiers (vscode/)
    engine.addImportPath(projectDir.absoluteFilePath("qml"));

    const QUrl mainQml(QUrl::fromLocalFile(projectDir.absoluteFilePath("qml/MainWindow.qml")));
    
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [mainQml](QObject *obj, const QUrl &objUrl) {
        if (!obj && objUrl == mainQml) {
            qCritical() << "Échec du chargement de l'interface QML:" << objUrl;
            QCoreApplication::exit(-1);
        } else {
            qInfo() << "Interface QML chargée avec succès:" << objUrl;
        }
    });

    qInfo() << "Chargement de l'interface QML:" << mainQml;
    engine.load(mainQml);

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "Interface QML non chargée";
        return -1;
    }

    qInfo() << "Interface QML chargée avec succès";

    qInfo() << "EXO Assistant démarré - Interface VS Code";

    // Lancement de la boucle d'événements
    int result = app.exec();
    
    qInfo() << "Application fermée avec code:" << result;
    return result;
}