#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QDir>
#include <QLoggingCategory>
#include <QStandardPaths>

#ifdef RASPBERRY_PI
#include <QGuiApplication>
#endif

#include "assistantmanager.h"
#include "logmanager.h"

// Configuration des logs - utilisation de la catégorie définie dans logmanager.h

int main(int argc, char *argv[])
{
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
    app.setApplicationName("Henri Assistant");
    app.setApplicationVersion("2.1");
    app.setOrganizationName("HenriAssistant");
    app.setOrganizationDomain("henri-assistant.local");

    // Style Material Design
    QQuickStyle::setStyle("Material");
    qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME", "Dark");

    qInfo() << "=== Démarrage d'Henri Assistant v2.1 ===";
    qInfo() << "Plateforme:" 
#ifdef RASPBERRY_PI
                 << "Raspberry Pi 5 (EGLFS)"
#else
                 << "Développement Windows"
#endif
                 ;

    // === Initialisation simplifiée avec AssistantManager ===
    
    // Créer le gestionnaire principal
    AssistantManager* assistant = new AssistantManager(&app);
    
    // Créer le moteur QML
    QQmlApplicationEngine engine;
    assistant->setQmlEngine(&engine);

    // Initialiser Henri avec la configuration
    if (!assistant->initializeWithConfig()) {
        qCritical() << "Échec de l'initialisation d'Henri";
        return -1;
    }

    // === Chargement de l'interface QML ===
    
    // Configuration des chemins de ressources
    engine.addImportPath("qrc:/qml");
    engine.addImportPath(":/");

    // Chargement de l'interface principale
    const QUrl mainQml(QStringLiteral("qrc:/qml/main.qml"));
    
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [mainQml](QObject *obj, const QUrl &objUrl) {
        if (!obj && objUrl == mainQml) {
            qCritical() << "Échec du chargement de l'interface QML";
            QCoreApplication::exit(-1);
        }
    });

    engine.load(mainQml);

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "Interface QML non chargée";
        return -1;
    }

    qInfo() << "Interface QML chargée avec succès";

    // === Gestion propre de l'arrêt ===
    
    QObject::connect(&app, &QCoreApplication::aboutToQuit, [assistant]() {
        qInfo() << "Arrêt d'Henri...";
        assistant->deleteLater();
    });

    qInfo() << "Henri Assistant démarré - En attente d'interactions";

    // Lancement de la boucle d'événements
    int result = app.exec();
    
    qInfo() << "Application fermée avec code:" << result;
    return result;
}