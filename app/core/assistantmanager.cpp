#include "AssistantManager.h"
#include "llm/AIMemoryManager.h"
#include "ConfigManager.h"
#include "LogManager.h"
#include "HealthCheck.h"
#include "llm/ClaudeAPI.h"
#include "audio/VoicePipeline.h"
#include "utils/WeatherManager.h"
#include "PipelineEvent.h"
#include "PipelineTracer.h"
#include <QQmlContext>
#include <QTimer>
#include <QTime>
#include <QDate>
#include <QLocale>
#include <QMetaObject>

AssistantManager::AssistantManager(QObject *parent)
    : QObject(parent)
    , m_isListening(false)
    , m_isInitialized(false)
    , m_configManager(nullptr)
    , m_claudeApi(nullptr)
    , m_voicePipeline(nullptr)
    , m_weatherManager(nullptr)
    , m_memoryManager(nullptr)
    , m_healthCheck(nullptr)
    , m_qmlEngine(nullptr)
{
    hAssistant() << "AssistantManager v4 créé";
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

    hAssistant() << "=== Initialisation d'EXO Assistant ===" ;

    // 1. Créer et charger la configuration
    m_configManager = new ConfigManager(this);
    
    if (!m_configManager->loadConfiguration(configPath)) {
        hWarning(henriAssistant) << "Configuration par défaut utilisée";
    }
    
    // 2. Initialiser le système de logging avec la config
    LogManager* logManager = LogManager::instance();
    LogManager::LogLevel logLevel = LogManager::stringToLogLevel(m_configManager->getLogLevel());
    logManager->initialize(logLevel, true, true); // Console + fichier activés pour diagnostic
    
    // 3. Initialiser les composants principaux
    initializeComponents();
    
    // 4. Configuration des connexions entre composants
    setupConnections();
    
    // 5. Exposer les composants au QML
    exposeToQml();

    m_isInitialized = true;
    emit initializationComplete();
    
    hAssistant() << "EXO Assistant initialisé avec succès !";
    
    // Envoyer le message d'accueil personnalisé
    sendWelcomeMessage();
    
    // Démarrer l'écoute permanente après une courte pause
    QTimer::singleShot(2000, this, [this]() {
        if (m_voicePipeline) {
            hVoice() << "Démarrage de l'écoute permanente";
            m_voicePipeline->startListening();
        }
    });
    
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

    // === Voice Pipeline ===
    m_voicePipeline = new VoicePipeline(this);

    // Configure audio backend from config (qt or rtaudio)
    QString audioBackend = m_configManager->getString("Audio", "backend", "qt");
    m_voicePipeline->setAudioBackend(audioBackend);

    m_voicePipeline->initAudio();

    // Configure VAD backend from config
    QString vadBackend = m_configManager->getVADBackend();
    VADEngine::Backend vadEnum = VADEngine::Backend::Builtin;
    if (vadBackend == "silero")
        vadEnum = VADEngine::Backend::SileroONNX;
    else if (vadBackend == "hybrid")
        vadEnum = VADEngine::Backend::Hybrid;
    QString vadUrl = m_configManager->getString("VAD", "server_url", "ws://localhost:8768");
    m_voicePipeline->initVAD(vadEnum, vadUrl);

    m_voicePipeline->initSTT(m_configManager->getSTTServerUrl());
    m_voicePipeline->initTTS(m_configManager->getTTSServerUrl());

    // OpenWakeWord neural wake word detection (optional)
    bool wakewordNeural = m_configManager->getBool("WakeWord", "neural_enabled", false);
    if (wakewordNeural) {
        QString wakewordUrl = m_configManager->getString("WakeWord", "server_url", "ws://localhost:8770");
        m_voicePipeline->initWakeWordServer(wakewordUrl);
    }

    // Apply TTS settings from config
    m_voicePipeline->setTTSVoice(m_configManager->getTTSVoice());
    m_voicePipeline->setTTSLanguage(m_configManager->getTTSLanguage());
    m_voicePipeline->setTTSStyle(m_configManager->getTTSStyle());
    m_voicePipeline->setTTSEngine(m_configManager->getTTSEngine());

    // Configure STT language from config
    m_voicePipeline->setSTTLanguage(m_configManager->getSTTLanguage());
    m_voicePipeline->setVADThreshold(static_cast<float>(
        m_configManager->getVADThreshold()));

    // Configure wake-word with phonetic variants
    m_voicePipeline->setWakeWord(m_configManager->getWakeWord());

    // Connect to GUI WebSocket server for state/audio broadcast
    m_voicePipeline->connectToServer(m_configManager->getGUIServerUrl());

    hVoice() << "VoicePipeline configuré (wake-word logiciel)"
             << "STT:" << m_configManager->getSTTServerUrl()
             << "TTS:" << m_configManager->getTTSServerUrl()
             << "GUI:" << m_configManager->getGUIServerUrl();

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
    
    // === Memory Manager ===
    m_memoryManager = new AIMemoryManager(this);
    // Connect to FAISS semantic memory server if configured
    QString memoryUrl = m_configManager->getString("Memory", "semantic_server_url", "ws://localhost:8771");
    bool semanticEnabled = m_configManager->getBool("Memory", "semantic_enabled", true);
    if (semanticEnabled) {
        m_memoryManager->initSemanticServer(memoryUrl);
    }
    hAssistant() << "Memory Manager initialisé - mémoire EXO activée";

    // === Pipeline Tracer ===
    PipelineTracer::instance();
    hAssistant() << "PipelineTracer initialisé — analyse post-interaction activée";

    // === Health Check ===
    m_healthCheck = new HealthCheck(this);
    m_healthCheck->configure(m_configManager);
    m_healthCheck->start(10000);  // Ping toutes les 10 secondes
    hAssistant() << "HealthCheck initialisé — surveillance des microservices activée";
}

void AssistantManager::setupConnections()
{
    hAssistant() << "Configuration des connexions entre composants...";

    // Connexions Claude API (v3 streaming + function calling)
    if (m_claudeApi) {
        connect(m_claudeApi, &ClaudeAPI::finalResponse,
                this, &AssistantManager::onClaudeResponse);
        connect(m_claudeApi, &ClaudeAPI::partialResponse,
                this, &AssistantManager::onClaudePartial);
        connect(m_claudeApi, &ClaudeAPI::toolCallDetected,
                this, &AssistantManager::onToolCall);
        connect(m_claudeApi, &ClaudeAPI::errorOccurred,
                this, &AssistantManager::onError);
    }

    // Connexions Voice Pipeline
    if (m_voicePipeline) {
        connect(m_voicePipeline, &VoicePipeline::listeningChanged,
                this, [this]() {
                    emit listeningStateChanged(m_voicePipeline->isListening());
                });
        connect(m_voicePipeline, &VoicePipeline::commandDetected,
                this, &AssistantManager::sendMessage);
        connect(m_voicePipeline, &VoicePipeline::speechTranscribed,
                this, &AssistantManager::onSpeechTranscribed);
    }

    // Connexions Weather Manager
    if (m_weatherManager) {
        connect(m_weatherManager, &WeatherManager::weatherUpdated,
                this, &AssistantManager::onWeatherUpdate);
    }
    
    // Connexions Config Manager
    if (m_configManager && m_weatherManager) {
        connect(m_configManager, &ConfigManager::weatherConfigChanged,
                this, [this](const QString &city, const QString &apiKey) {
                    hWeather() << "Configuration météo mise à jour - Ville:" << city;
                    m_weatherManager->setCity(city);
                    m_weatherManager->setApiKey(apiKey);
                    // Forcer une mise à jour immédiate
                    m_weatherManager->initialize();
                });
    }
    
    // Connexion Claude -> Voice pour les réponses vocales (sentence streaming)
    if (m_claudeApi && m_voicePipeline) {
        connect(m_claudeApi, &ClaudeAPI::sentenceReady,
                m_voicePipeline, [this](const QString& sentence) {
                    m_voicePipeline->speakSentence(sentence);
                });
        hAssistant() << "Connexion Claude sentenceReady -> VoicePipeline établie";
    }
    
    // Note: claudeResponseReceived n'est plus connecté au TTS pour éviter le double speak
    
    // Connexions signaux Voice → AssistantManager
    if (m_voicePipeline) {
        connect(m_voicePipeline, &VoicePipeline::voiceError,
                this, [this](const QString& error) {
                    hWarning(henriVoice) << "Erreur vocale:" << error;
                    emit errorOccurred(error);
                });
        connect(m_voicePipeline, &VoicePipeline::statusChanged,
                this, [](const QString& status) {
                    hVoice() << "Status vocal:" << status;
                });
        connect(m_voicePipeline, &VoicePipeline::wakeWordDetected,
                this, []() {
                    hVoice() << "Wake word détecté";
                });
    }
    
    // Note: la mémoire est gérée dans onClaudeResponse() uniquement
    // pour éviter les doublons

    // Pipeline Event Bus → LogManager (structured logging)
    auto *eventBus = PipelineEventBus::instance();
    connect(eventBus, &PipelineEventBus::eventEmitted,
            LogManager::instance(), &LogManager::logPipelineEvent);

    // Initialiser les modules comme Idle
    PIPELINE_STATE(PipelineModule::Orchestrator, ModuleState::Idle);
    PIPELINE_STATE(PipelineModule::AudioCapture, ModuleState::Idle);
    if (m_claudeApi)
        PIPELINE_STATE(PipelineModule::Claude, ModuleState::Idle);
    if (m_voicePipeline) {
        PIPELINE_STATE(PipelineModule::VAD, ModuleState::Idle);
        PIPELINE_STATE(PipelineModule::STT, ModuleState::Idle);
        PIPELINE_STATE(PipelineModule::TTS, ModuleState::Idle);
        PIPELINE_STATE(PipelineModule::AudioOutput, ModuleState::Idle);
    }
    hAssistant() << "Pipeline Event Bus initialisé et connecté";
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
    if (m_voicePipeline) {
        m_qmlEngine->rootContext()->setContextProperty("voiceManager", m_voicePipeline);
    }
    if (m_weatherManager) {
        m_qmlEngine->rootContext()->setContextProperty("weatherManager", m_weatherManager);
    }
    if (m_configManager) {
        m_qmlEngine->rootContext()->setContextProperty("configManager", m_configManager);
    }
    if (m_memoryManager) {
        m_qmlEngine->rootContext()->setContextProperty("memoryManager", m_memoryManager);
    }
    if (m_healthCheck) {
        m_qmlEngine->rootContext()->setContextProperty("healthCheck", m_healthCheck);
    }

    // Exposer le LogManager pour le panneau Logs QML
    m_qmlEngine->rootContext()->setContextProperty("logManager", LogManager::instance());

    // Exposer le PipelineEventBus pour le moniteur de pipeline QML
    m_qmlEngine->rootContext()->setContextProperty("pipelineEventBus", PipelineEventBus::instance());
    
    hAssistant() << "Composants exposés au QML avec succès";
}

void AssistantManager::sendMessage(const QString &message)
{
    if (!m_claudeApi) {
        hWarning(henriAssistant) << "sendMessage: Claude API NULL!";
        emit errorOccurred("Claude API non disponible");
        return;
    }

    hAssistant() << "=== sendMessage ===" << message.left(80)
                 << "claudeReady=" << m_claudeApi->isReady();
    
    // Stocker le message utilisateur pour la mémoire
    m_lastUserMessage = message;
    
    // Contexte système enrichi avec les capacités EXO
    QString systemContext = "Vous êtes EXO, un assistant domotique français intelligent. ";
    systemContext += "Vous avez accès aux outils suivants via Function Calling: ";
    systemContext += "ha_turn_on, ha_turn_off, ha_toggle, ha_set_brightness, ha_set_temperature, ha_get_state (Home Assistant), ";
    systemContext += "get_weather (météo), get_datetime (date/heure). ";
    systemContext += "Utilisez ces outils quand l'utilisateur demande une action domotique ou une information. ";
    
    // Ajouter le contexte de mémoire intelligente si disponible
    if (m_memoryManager) {
        QString memoryContext = m_memoryManager->buildClaudeContext(5, 5);
        if (!memoryContext.isEmpty()) {
            systemContext += "\n\n" + memoryContext;
        }
        systemContext += "\nUtilise ta mémoire des conversations précédentes et les souvenirs utilisateur pour personnaliser tes réponses.";
    }
    
    systemContext += "\nUtilisez ces informations pour répondre de manière contextuelle et utile.";
    
    // Construire les outils EXO Function Calling
    QJsonArray tools = ClaudeAPI::buildEXOTools();

    // Envoyer le message avec streaming + function calling
    m_claudeApi->sendMessageFull(message, systemContext, tools, true);
}

void AssistantManager::sendManualQuery(const QString &text)
{
    QString trimmed = text.trimmed();
    if (trimmed.isEmpty()) return;
    hAssistant() << "Requête manuelle:" << trimmed.left(50);
    sendMessage(trimmed);
}

void AssistantManager::startListening()
{
    if (!m_voicePipeline) {
        hWarning(henriAssistant) << "Voice Pipeline non disponible";
        return;
    }
    
    if (m_isListening) return;
    
    m_voicePipeline->startListening();
    m_isListening = true;
    emit listeningStateChanged(true);
    hVoice() << "Écoute vocale démarrée";
}

void AssistantManager::stopListening()
{
    if (!m_voicePipeline) return;
    
    if (!m_isListening) return;
    
    m_voicePipeline->stopListening();
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

void AssistantManager::onWeatherUpdate()
{
    hWeather() << "Données météo mises à jour";
}

void AssistantManager::onError(const QString &error)
{
    hCritical(henriAssistant) << "Erreur AssistantManager:" << error;
    emit errorOccurred(error);
}

void AssistantManager::sendWelcomeMessage()
{
    const QString welcomeMessage = "EXO prêt.";
    
    // Émettre le message d'accueil pour l'interface (texte seulement)
    emit claudeResponseReceived(welcomeMessage);
    
    // Pas de TTS au démarrage — l'utilisateur peut tester la voix dans les paramètres
    
    hAssistant() << "Message d'accueil EXO envoyé:" << welcomeMessage;
}

void AssistantManager::onConfigurationLoaded()
{
    hConfig() << "Configuration chargée avec succès";
}

void AssistantManager::onClaudeResponse(const QString &response)
{
    hClaude() << "Réponse Claude reçue:" << response.left(80) + "...";
    PIPELINE_EVENT(PipelineModule::Claude, EventType::ResponseReceived,
                   QJsonObject{{"length", response.length()}});
    PIPELINE_STATE(PipelineModule::Claude, ModuleState::Idle);
    
    emit claudeResponseReceived(response);
    
    // Stocker la conversation + analyse auto des souvenirs
    if (m_memoryManager && !m_lastUserMessage.isEmpty()) {
        m_memoryManager->addConversation(m_lastUserMessage, response);
        m_memoryManager->analyzeAndMaybeStore(m_lastUserMessage);
        m_lastUserMessage.clear();
    }
}

void AssistantManager::onSpeechTranscribed(const QString &transcription)
{
    hClaude() << "=== onSpeechTranscribed ===" << transcription.left(80);
    PIPELINE_EVENT(PipelineModule::Orchestrator, EventType::SpeechTranscribed,
                   QJsonObject{{"text", transcription}, {"length", transcription.length()}});
    
    // L'affichage dans le chat est géré côté QML via Connections { target: voiceManager }
    // → onSpeechTranscribed → transcriptView.addMessage()
}

void AssistantManager::onClaudePartial(const QString &text)
{
    PIPELINE_EVENT(PipelineModule::Claude, EventType::PartialResponse,
                   QJsonObject{{"length", text.length()}});
    // Relayer le streaming partiel vers l'interface QML
    emit claudePartialResponse(text);
}

void AssistantManager::onToolCall(const QString &toolUseId,
                                  const QString &toolName,
                                  const QJsonObject &arguments)
{
    hAssistant() << "Tool call reçu:" << toolName << "— id:" << toolUseId;
    PIPELINE_EVENT(PipelineModule::Claude, EventType::ToolCallDispatched,
                   QJsonObject{{"tool", toolName}, {"tool_use_id", toolUseId}});

    QJsonObject result;

    // ── Outils locaux (pas besoin du backend Python) ─────
    if (toolName == QLatin1String("get_weather")) {
        // Résolution locale via WeatherManager
        if (m_weatherManager) {
            result[QStringLiteral("status")] = QStringLiteral("success");
            result[QStringLiteral("temperature")] = m_weatherManager->temperature();
            result[QStringLiteral("description")] = m_weatherManager->description();
            result[QStringLiteral("city")] = m_configManager->getWeatherCity();
        } else {
            result[QStringLiteral("status")] = QStringLiteral("error");
            result[QStringLiteral("message")] = QStringLiteral("Service météo non disponible");
        }
        m_claudeApi->sendToolResult(toolUseId, result);
        return;
    }

    if (toolName == QLatin1String("get_datetime")) {
        result[QStringLiteral("status")] = QStringLiteral("success");
        result[QStringLiteral("date")] = QDate::currentDate().toString(Qt::ISODate);
        result[QStringLiteral("time")] = QTime::currentTime().toString(QStringLiteral("HH:mm:ss"));
        result[QStringLiteral("day")] = QLocale(QStringLiteral("fr_FR"))
            .dayName(QDate::currentDate().dayOfWeek());
        m_claudeApi->sendToolResult(toolUseId, result);
        return;
    }

    // ── Outils Home Assistant (dispatch vers Python backend via WebSocket) ─────
    if (toolName.startsWith(QLatin1String("ha_"))) {
        hAssistant() << "Dispatch HA tool:" << toolName;

        // Construire la commande HA à envoyer via WebSocket
        QJsonObject haCommand;
        haCommand[QStringLiteral("type")] = QStringLiteral("ha_command");
        haCommand[QStringLiteral("tool")] = toolName;
        haCommand[QStringLiteral("arguments")] = arguments;
        haCommand[QStringLiteral("tool_use_id")] = toolUseId;

        // Envoyer via le WebSocket du VoicePipeline
        if (m_voicePipeline) {
            QJsonDocument doc(haCommand);
            m_voicePipeline->sendWebSocketMessage(
                QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
        }

        // Répondre immédiatement à Claude (le résultat réel viendra async)
        result[QStringLiteral("status")] = QStringLiteral("success");
        result[QStringLiteral("message")] =
            QStringLiteral("Commande %1 envoyée pour %2")
                .arg(toolName,
                     arguments[QStringLiteral("entity_id")].toString());
        m_claudeApi->sendToolResult(toolUseId, result);
        return;
    }

    // ── Outil inconnu ────────────────────────────────
    hWarning(henriAssistant) << "Tool inconnu:" << toolName;
    result[QStringLiteral("status")] = QStringLiteral("error");
    result[QStringLiteral("message")] =
        QStringLiteral("Outil '%1' non reconnu").arg(toolName);
    m_claudeApi->sendToolResult(toolUseId, result);
}