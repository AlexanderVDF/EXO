#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QDebug>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    
    app.setApplicationName("Assistant Raspberry Pi 5");
    app.setApplicationVersion("2.0");
    app.setOrganizationName("RaspberryAssistant");
    
    qDebug() << "Démarrage de l'Assistant Raspberry Pi 5...";
    
    QQmlApplicationEngine engine;
    engine.load(QUrl(QStringLiteral("qrc:/RaspberryAssistant/qml/main.qml")));
    
    if (engine.rootObjects().isEmpty()) {
        qDebug() << "Erreur: Impossible de charger l'interface QML";
        return -1;
    }
    
    qDebug() << "Interface chargée avec succès!";
    return app.exec();
}