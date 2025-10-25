#include "assistantmanager.h"
#include "configmanager.h"
#include "logmanager.h"
#include "claudeapi.h"
#include "voicemanager.h"
#include "weathermanager.h"

#include <QQmlContext>

AssistantManager::AssistantManager(QObject *parent)
    : QObject(parent)
    , m_isListening(false)
    , m_isInitialized(false)
    , m_configManager(nullptr)
    , m_claudeApi(nullptr)
    , m_voiceManager(nullptr)
    , m_weatherManager(nullptr)
    , m_qmlEngine(nullptr)
{
    hAssistant() << "AssistantManager créé (version refactorisée)";
}

AssistantManager::~AssistantManager()
{
    hAssistant() << "AssistantManager détruit";
}

void AssistantManager::setQmlEngine(QQmlApplicationEngine *engine)
{
    m_qmlEngine = engine;
    hAssistant() << "QML Engine configuré";
}

bool AssistantManager::initializeWithConfig(const QString &configPath)
{
    if (m_isInitialized) {
        hWarning(henriAssistant) << "AssistantManager déjà initialisé";
        return true;
    }

    hAssistant() << "=== Initialisation d'Henri Assistant ===";

    // 1. Créer et charger la configuration
    m_configManager = new ConfigManager(this);
    
    if (!m_configManager->loadConfiguration(configPath)) {
        hWarning(henriAssistant) << "Configuration par défaut utilisée";
    }
    
    // 2. Initialiser le système de logging avec la config
    LogManager* logManager = LogManager::instance();
    LogManager::LogLevel logLevel = LogManager::stringToLogLevel(m_configManager->getLogLevel());
    logManager->initialize(logLevel, true, false); // Console activée, fichier désactivé par défaut
    
    // 3. Initialiser les composants principaux
    initializeComponents();
    
    // 4. Configuration des connexions entre composants
    setupConnections();
    
    // 5. Exposer les composants au QML
    exposeToQml();

    m_isInitialized = true;
    emit initializationComplete();
    
    hAssistant() << "Henri Assistant initialisé avec succès !";
    return true;
}

void AssistantManager::initializeComponents()
{
    hAssistant() << "Initialisation des composants principaux...";

    // === Claude API ===
    m_claudeApi = new ClaudeAPI(this);
    QString claudeKey = m_configManager->getClaudeApiKey();
    if (!claudeKey.isEmpty()) {
        m_claudeApi->setApiKey(claudeKey);
        m_claudeApi->setModel(m_configManager->getClaudeModel());
        hClaude() << "Claude API configuré avec le modèle:" << m_configManager->getClaudeModel();
    } else {
        hWarning(henriClaude) << "Clé API Claude manquante - fonctionnalité désactivée";
    }

    // === Voice Manager ===
    m_voiceManager = new VoiceManager(this);
    m_voiceManager->setWakeWord(m_configManager->getWakeWord());
    hVoice() << "Voice Manager configuré avec mot d'activation:" << m_configManager->getWakeWord();

    // === Weather Manager ===
    m_weatherManager = new WeatherManager(this);
    QString weatherKey = m_configManager->getWeatherApiKey();
    if (!weatherKey.isEmpty()) {
        m_weatherManager->setApiKey(weatherKey);
        m_weatherManager->setCity(m_configManager->getWeatherCity());
        m_weatherManager->initialize();
        hWeather() << "Weather Manager configuré pour:" << m_configManager->getWeatherCity();
    } else {
        hWarning(henriWeather) << "Clé API météo manquante - fonctionnalité désactivée";
    }
}

void AssistantManager::setupConnections()
{
    hAssistant() << "Configuration des connexions entre composants...";

    // Connexions Claude API
    if (m_claudeApi) {
        connect(m_claudeApi, &ClaudeAPI::responseReceived, 
                this, &AssistantManager::onClaudeResponse);
        connect(m_claudeApi, &ClaudeAPI::errorOccurred, 
                this, &AssistantManager::onError);
    }

    // Connexions Voice Manager
    if (m_voiceManager) {
        connect(m_voiceManager, &VoiceManager::listeningChanged,
                this, [this]() {
                    emit listeningStateChanged(m_voiceManager->isListening());
                });
        connect(m_voiceManager, &VoiceManager::commandDetected,
                this, &AssistantManager::sendMessage);
    }

    // Connexions Weather Manager
    if (m_weatherManager) {
        connect(m_weatherManager, &WeatherManager::weatherUpdated,
                this, &AssistantManager::onWeatherUpdate);
    }
    
    // Connexion Claude -> Voice pour les réponses intelligentes
    if (m_claudeApi && m_voiceManager) {
        connect(m_claudeApi, &ClaudeAPI::responseReceived,
                m_voiceManager, [this](const QString& response) {
                    m_voiceManager->speak(response);
                });
        hAssistant() << "Connexion Claude -> Voice établie";
    }
}

void AssistantManager::exposeToQml()
{
    if (!m_qmlEngine) {
        hWarning(henriAssistant) << "QML Engine non disponible pour l'exposition";
        return;
    }

    // Exposer AssistantManager lui-même
    m_qmlEngine->rootContext()->setContextProperty("assistantManager", this);
    
    // Exposer les composants individuellement pour plus de flexibilité
    if (m_claudeApi) {
        m_qmlEngine->rootContext()->setContextProperty("claudeAPI", m_claudeApi);
    }
    if (m_voiceManager) {
        m_qmlEngine->rootContext()->setContextProperty("voiceManager", m_voiceManager);
    }
    if (m_weatherManager) {
        m_qmlEngine->rootContext()->setContextProperty("weatherManager", m_weatherManager);
    }
    if (m_configManager) {
        m_qmlEngine->rootContext()->setContextProperty("configManager", m_configManager);
    }
    
    hAssistant() << "Composants exposés au QML avec succès";
}

void AssistantManager::sendMessage(const QString &message)
{
    if (!m_claudeApi) {
        emit errorOccurred("Claude API non disponible");
        return;
    }

    hAssistant() << "Envoi message à Claude:" << message.left(50) + "...";
    m_claudeApi->sendMessage(message);
}

void AssistantManager::startListening()
{
    if (!m_voiceManager) {
        hWarning(henriAssistant) << "Voice Manager non disponible";
        return;
    }
    
    if (m_isListening) return;
    
    m_voiceManager->startListening();
    m_isListening = true;
    emit listeningStateChanged(true);
    hVoice() << "Écoute vocale démarrée";
}

void AssistantManager::stopListening()
{
    if (!m_voiceManager) return;
    
    if (!m_isListening) return;
    
    m_voiceManager->stopListening();
    m_isListening = false;
    emit listeningStateChanged(false);
    hVoice() << "Écoute vocale arrêtée";
}

QString AssistantManager::getWeatherSummary() const
{
    if (!m_weatherManager) {
        return "Service météo non disponible";
    }
    
    return QString("Météo %1 : %2°C, %3")
           .arg(m_configManager->getWeatherCity())
           .arg(m_weatherManager->temperature())
           .arg(m_weatherManager->description());
}

// Slots
void AssistantManager::onClaudeResponse(const QString &response)
{
    hClaude() << "Réponse Claude reçue:" << response.left(50) + "...";
    emit messageReceived("assistant", response);
}

void AssistantManager::onWeatherUpdate()
{
    hWeather() << "Données météo mises à jour";
}

void AssistantManager::onError(const QString &error)
{
    hCritical(henriAssistant) << "Erreur AssistantManager:" << error;
    emit errorOccurred(error);
}

void AssistantManager::onConfigurationLoaded()
{
    hConfig() << "Configuration chargée avec succès";
}