#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QDir>
#include <QLoggingCategory>
#include <QStandardPaths>

#ifdef _WIN32
#include <windows.h>
#include <io.h>
#include <fcntl.h>
#include <cstdio>
#endif

#ifdef RASPBERRY_PI
#include <QGuiApplication>
#endif

#include "assistantmanager.h"
#include "logmanager.h"

// Configuration des logs - utilisation de la catégorie définie dans logmanager.h

int main(int argc, char *argv[])
{
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
    app.setApplicationVersion("2.2");
    app.setOrganizationName("EXOAssistant");
    app.setOrganizationDomain("exo-assistant.local");

    // Style Material Design
    QQuickStyle::setStyle("Material");
    qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME", "Dark");

    qInfo() << "=== Démarrage d'EXO Assistant v2.2 ===";
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

    // Interface radiale EXO - chemin relatif au répertoire de l'application
    QString appDir = QCoreApplication::applicationDirPath();
    // Remonter de build/Debug vers la racine du projet
    QDir projectDir(appDir);
    projectDir.cdUp(); // Debug -> build
    projectDir.cdUp(); // build -> racine
    const QUrl mainQml(QUrl::fromLocalFile(projectDir.absoluteFilePath("qml/main_radial.qml")));
    
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

    qInfo() << "EXO Assistant démarré - Interface radiale";

    // Lancement de la boucle d'événements
    int result = app.exec();
    
    qInfo() << "Application fermée avec code:" << result;
    return result;
}