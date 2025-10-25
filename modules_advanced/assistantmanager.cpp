#include "assistantmanager.h"
#include "claudeapi.h"
#include "weathermanager.h"
// Note: speechmanager et systemmonitor déplacés dans modules_advanced

#include <QDebug>
#include <QStandardPaths>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QCoreApplication>
#include <QQmlContext>

AssistantManager::AssistantManager(QObject *parent)
    : QObject(parent)
    , m_claudeApi(nullptr)
    , m_speechManager(nullptr)
    , m_systemMonitor(nullptr)
    , m_weatherManager(nullptr)
    , m_qmlEngine(nullptr)
    , m_currentStatus("Initialisation...")
    , m_isListening(false)
    , m_isProcessing(false)
    , m_batteryLevel(100)
    , m_cpuUsage(0.0)
    , m_systemTimer(new QTimer(this))
    , m_pythonProcess(new QProcess(this))
    , m_pythonReady(false)
{
    // Configuration du timer système
    m_systemTimer->setInterval(2000); // Mise à jour toutes les 2 secondes
    connect(m_systemTimer, &QTimer::timeout, this, &AssistantManager::updateSystemMonitoring);
    
    // Configuration du chemin de config
    m_configPath = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/raspberry-assistant/config.json";
}

AssistantManager::~AssistantManager()
{
    if (m_pythonProcess && m_pythonProcess->state() != QProcess::NotRunning) {
        m_pythonProcess->terminate();
        m_pythonProcess->waitForFinished(3000);
    }
}

void AssistantManager::initialize()
{
    qDebug() << "=== Initialisation de l'Assistant ===";
    
    setStatus("Chargement de la configuration...");
    loadConfiguration();
    
    setStatus("Démarrage des services système...");
    initializeSystemServices();
    
    setStatus("Configuration de l'environnement Python...");
    setupPythonEnvironment();
    
    setStatus("Initialisation de l'API Claude...");
    m_claudeApi = new ClaudeAPI(this);
    connect(m_claudeApi, &ClaudeAPI::responseReceived, this, &AssistantManager::onClaudeResponseReceived);
    connect(m_claudeApi, &ClaudeAPI::errorOccurred, this, &AssistantManager::onClaudeErrorOccurred);
    
    setStatus("Configuration de la reconnaissance vocale...");
    m_speechManager = new SpeechManager(this);
    connect(m_speechManager, &SpeechManager::voiceInputReceived, this, &AssistantManager::onVoiceInputReceived);
    
    setStatus("Initialisation du monitoring système...");
    m_systemMonitor = new SystemMonitor(this);
    connect(m_systemMonitor, &SystemMonitor::statsUpdated, this, &AssistantManager::onSystemStatsUpdated);
    
    setStatus("Initialisation de la météo...");
    m_weatherManager = new WeatherManager(this);
    connect(m_weatherManager, &WeatherManager::weatherResponse, this, &AssistantManager::onWeatherResponseReceived);
    
    // Configuration clé API météo depuis la config
    QString weatherApiKey = m_config["weather_api_key"].toString();
    if (!weatherApiKey.isEmpty()) {
        m_weatherManager->setApiKey(weatherApiKey);
        m_weatherManager->initialize();
    } else {
        qWarning() << "⚠️ Clé API météo manquante dans la configuration";
    }
    
    // Démarrage du monitoring système
    m_systemTimer->start();
    
    setStatus("Assistant prêt !");
    qDebug() << "Assistant initialisé avec succès";
}

void AssistantManager::setQmlEngine(QQmlApplicationEngine* engine)
{
    m_qmlEngine = engine;
    if (m_qmlEngine) {
        // Exposition de l'assistant au contexte QML
        m_qmlEngine->rootContext()->setContextProperty("assistantManager", this);
        
        // Exposition du gestionnaire météo
        if (m_weatherManager) {
            m_qmlEngine->rootContext()->setContextProperty("weatherManager", m_weatherManager);
        }
        
        qDebug() << "Assistant et modules exposés au contexte QML";
    }
}

void AssistantManager::startListening()
{
    if (!m_isListening && m_speechManager) {
        qDebug() << "Démarrage de l'écoute vocale";
        setListening(true);
        setStatus("Écoute en cours...");
        m_speechManager->startListening();
    }
}

void AssistantManager::stopListening()
{
    if (m_isListening && m_speechManager) {
        qDebug() << "Arrêt de l'écoute vocale";
        setListening(false);
        setStatus("En attente");
        m_speechManager->stopListening();
    }
}

void AssistantManager::sendTextQuery(const QString& text)
{
    if (text.trimmed().isEmpty() || !m_claudeApi) {
        return;
    }
    
    qDebug() << "Envoi de la requête texte:" << text;
    setProcessing(true);
    setStatus("Traitement de votre demande...");
    
    m_claudeApi->sendMessage(text);
}

void AssistantManager::toggleMute()
{
    if (m_speechManager) {
        m_speechManager->toggleMute();
        qDebug() << "Basculement du mode muet";
    }
}

void AssistantManager::adjustVolume(double level)
{
    if (m_speechManager) {
        m_speechManager->setVolume(level);
        qDebug() << "Ajustement du volume à" << level;
    }
}

void AssistantManager::shutdown()
{
    qDebug() << "Demande d'arrêt du système";
    setStatus("Arrêt du système...");
    saveConfiguration();
    
#ifdef RASPBERRY_PI
    QProcess::execute("sudo", QStringList() << "shutdown" << "-h" << "now");
#else
    qDebug() << "Simulation d'arrêt (développement)";
    QCoreApplication::quit();
#endif
}

void AssistantManager::reboot()
{
    qDebug() << "Demande de redémarrage du système";
    setStatus("Redémarrage du système...");
    saveConfiguration();
    
#ifdef RASPBERRY_PI
    QProcess::execute("sudo", QStringList() << "reboot");
#else
    qDebug() << "Simulation de redémarrage (développement)";
    QCoreApplication::quit();
#endif
}

QString AssistantManager::getSystemInfo()
{
    QJsonObject info;
    info["cpu_usage"] = m_cpuUsage;
    info["battery_level"] = m_batteryLevel;
    info["status"] = m_currentStatus;
    info["listening"] = m_isListening;
    info["processing"] = m_isProcessing;
    
    return QJsonDocument(info).toJson(QJsonDocument::Compact);
}

// Slots privés
void AssistantManager::onVoiceInputReceived(const QString& text)
{
    qDebug() << "Entrée vocale reçue:" << text;
    emit voiceInputReceived(text);
    
    if (!text.trimmed().isEmpty()) {
        // Vérifier d'abord si c'est une commande météo
        if (m_weatherManager) {
            QString weatherResponse = m_weatherManager->handleVoiceCommand(text);
            if (!weatherResponse.isEmpty()) {
                qDebug() << "🌤️ Commande météo traitée localement";
                onWeatherResponseReceived(weatherResponse);
                return;
            }
        }
        
        // Sinon, envoyer à Claude
        sendTextQuery(text);
    }
}

void AssistantManager::onClaudeResponseReceived(const QString& response)
{
    qDebug() << "Réponse Claude reçue:" << response.left(100) + "...";
    
    m_lastResponse = response;
    setProcessing(false);
    setStatus("Réponse reçue");
    
    emit responseReceived(response);
    
    // Synthèse vocale de la réponse
    if (m_speechManager) {
        m_speechManager->speakText(response);
    }
}

void AssistantManager::onWeatherResponseReceived(const QString& response)
{
    qDebug() << "🌤️ Réponse météo reçue:" << response.left(100) + "...";
    
    m_lastResponse = response;
    setProcessing(false);
    setStatus("Météo mise à jour");
    
    emit responseReceived(response);
    
    // Synthèse vocale de la réponse météo
    if (m_speechManager) {
        m_speechManager->speakText(response);
    }
}

void AssistantManager::onClaudeErrorOccurred(const QString& error)
{
    qDebug() << "Erreur Claude:" << error;
    
    setProcessing(false);
    setStatus("Erreur de traitement");
    
    emit errorOccurred(error);
}

void AssistantManager::onSystemStatsUpdated()
{
    if (m_systemMonitor) {
        m_batteryLevel = m_systemMonitor->getBatteryLevel();
        m_cpuUsage = m_systemMonitor->getCpuUsage();
        
        emit batteryLevelChanged(m_batteryLevel);
        emit cpuUsageChanged(m_cpuUsage);
    }
}

void AssistantManager::updateSystemMonitoring()
{
    if (m_systemMonitor) {
        m_systemMonitor->updateStats();
    }
}

// Méthodes privées
void AssistantManager::setStatus(const QString& status)
{
    if (m_currentStatus != status) {
        m_currentStatus = status;
        emit statusChanged(status);
    }
}

void AssistantManager::setListening(bool listening)
{
    if (m_isListening != listening) {
        m_isListening = listening;
        emit listeningStateChanged(listening);
    }
}

void AssistantManager::setProcessing(bool processing)
{
    if (m_isProcessing != processing) {
        m_isProcessing = processing;
        emit processingStateChanged(processing);
    }
}

void AssistantManager::loadConfiguration()
{
    QDir configDir = QFileInfo(m_configPath).dir();
    if (!configDir.exists()) {
        configDir.mkpath(".");
    }
    
    QFile configFile(m_configPath);
    if (configFile.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(configFile.readAll());
        m_config = doc.object();
        qDebug() << "Configuration chargée depuis" << m_configPath;
    } else {
        // Configuration par défaut
        m_config["claude_model"] = "claude-3-haiku-20240307";
        m_config["voice_enabled"] = true;
        m_config["volume"] = 0.7;
        qDebug() << "Configuration par défaut créée";
    }
}

void AssistantManager::saveConfiguration()
{
    QFile configFile(m_configPath);
    if (configFile.open(QIODevice::WriteOnly)) {
        QJsonDocument doc(m_config);
        configFile.write(doc.toJson());
        qDebug() << "Configuration sauvegardée";
    }
}

void AssistantManager::setupPythonEnvironment()
{
    // Configuration du processus Python pour l'API Claude
    m_pythonProcess->setProgram("python3");
    m_pythonProcess->setArguments(QStringList() << "python/claude_service.py");
    m_pythonProcess->setWorkingDirectory(QCoreApplication::applicationDirPath());
    
    // Démarrage du service Python
    connect(m_pythonProcess, &QProcess::started, [this]() {
        m_pythonReady = true;
        qDebug() << "Service Python démarré";
    });
    
    connect(m_pythonProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            [this](int exitCode, QProcess::ExitStatus exitStatus) {
        m_pythonReady = false;
        qDebug() << "Service Python terminé avec code:" << exitCode;
    });
    
    m_pythonProcess->start();
}

void AssistantManager::initializeSystemServices()
{
    // Initialisation des services système spécifiques au Raspberry Pi
#ifdef RASPBERRY_PI
    // Configuration GPIO si nécessaire
    // Configuration des périphériques
    qDebug() << "Services Raspberry Pi initialisés";
#else
    qDebug() << "Mode développement - services simulés";
#endif
}