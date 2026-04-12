#include "AssistantManager.h"
#include "llm/AIMemoryManager.h"
#include "ConfigManager.h"
#include "LogManager.h"
#include "HealthCheck.h"
#include "llm/ClaudeAPI.h"
#include "audio/VoicePipeline.h"
#include "audio/AudioDeviceManager.h"
#include "utils/WeatherManager.h"
#include "PipelineEvent.h"
#include "PipelineTracer.h"
#include "ContextCache.h"
#include "LatencyMetrics.h"
#include "safeboot/SafeBootController.h"
#include <QQmlContext>
#include <QTimer>
#include <QTime>
#include <QDate>
#include <QLocale>
#include <QMetaObject>
#include <QUuid>
#include <QElapsedTimer>
#include <QRegularExpression>

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
    hAssistant() << "AssistantManager v30.3 créé";
}

AssistantManager::~AssistantManager()
{
    hAssistant() << "AssistantManager détruit";
}

void AssistantManager::setSafeBootController(SafeBootController *controller)
{
    if (m_safeBootController == controller) return;
    m_safeBootController = controller;
    if (m_safeBootController) {
        connect(m_safeBootController, &SafeBootController::safeBootActivated, this, &AssistantManager::safeBootChanged);
        connect(m_safeBootController, &SafeBootController::safeBootDeactivated, this, &AssistantManager::safeBootChanged);
        connect(m_safeBootController, &SafeBootController::serviceFailed, this, &AssistantManager::safeBootChanged);
        connect(m_safeBootController, &SafeBootController::serviceRecovered, this, &AssistantManager::safeBootChanged);
        connect(m_safeBootController, &SafeBootController::timelineUpdated, this, &AssistantManager::safeBootChanged);
    }
    emit safeBootChanged();
}

bool AssistantManager::safeBootEnabled() const
{
    return m_safeBootController ? m_safeBootController->isSafeBootEnabled() : false;
}

QVariantList AssistantManager::failedServices() const
{
    return m_safeBootController ? m_safeBootController->getFailedServices() : QVariantList{};
}

QVariantList AssistantManager::degradedServices() const
{
    return m_safeBootController ? m_safeBootController->getDegradedServices() : QVariantList{};
}

QVariantList AssistantManager::startupTimeline() const
{
    return m_safeBootController ? m_safeBootController->getStartupTimeline() : QVariantList{};
}

void AssistantManager::onServiceReady(const QString &serviceName)
{
    hAssistant() << "[SafeBoot] Service ready:" << serviceName;
    emit serviceReady(serviceName);
    emit safeBootChanged();
}

void AssistantManager::onServiceFailed(const QString &serviceName)
{
    hWarning(exoAssistant) << "[SafeBoot] Service failed:" << serviceName;
    emit serviceFailed(serviceName);
    emit safeBootChanged();
}

bool AssistantManager::autoRepairRunning() const
{
    return m_safeBootController ? m_safeBootController->autoRepairRunning() : false;
}

QVariantList AssistantManager::repairTimeline() const
{
    return m_safeBootController ? m_safeBootController->repairTimeline() : QVariantList{};
}

void AssistantManager::onRepairAttempt(const QString &service, bool success)
{
    if (success)
        hAssistant() << "[AutoRepair] Service réparé:" << service;
    else
        hWarning(exoAssistant) << "[AutoRepair] Échec réparation:" << service;
    emit safeBootChanged();
}

void AssistantManager::onRepairCompleted()
{
    hAssistant() << "[AutoRepair] Réparation automatique terminée";
    emit safeBootChanged();
}

void AssistantManager::setQmlEngine(QQmlApplicationEngine *engine)
{
    m_qmlEngine = engine;
    hAssistant() << "QML Engine configuré";
}

void AssistantManager::initConfigEarly(const QString &configPath)
{
    if (m_configManager) return; // déjà créé

    m_configManager = new ConfigManager(this);
    if (!m_configManager->loadConfiguration(configPath)) {
        hWarning(exoAssistant) << "Configuration par défaut utilisée (early)";
    }

    // Exposer immédiatement au QML pour que Component.onCompleted voit les vraies valeurs
    if (m_qmlEngine) {
        m_qmlEngine->rootContext()->setContextProperty("configManager", m_configManager);
        hAssistant() << "configManager exposé au QML (early)";
    }
}

bool AssistantManager::initializeWithConfig(const QString &configPath)
{
    if (m_isInitialized) {
        hWarning(exoAssistant) << "AssistantManager déjà initialisé";
        return true;
    }

    hAssistant() << "=== Initialisation d'EXO Assistant ===" ;

    // 1. Créer et charger la configuration (si pas déjà fait par initConfigEarly)
    if (!m_configManager) {
        m_configManager = new ConfigManager(this);
        if (!m_configManager->loadConfiguration(configPath)) {
            hWarning(exoAssistant) << "Configuration par défaut utilisée";
        }
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
        hWarning(exoClaude) << "Clé API Claude manquante - fonctionnalité désactivée";
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
    m_voicePipeline->setTTSPitch(m_configManager->getString("TTS", "pitch", "1.0").toFloat());
    m_voicePipeline->setTTSRate(m_configManager->getString("TTS", "rate", "1.0").toFloat());

    // Audio preprocessing from config
    m_voicePipeline->setNoiseGate(m_configManager->getString("Audio", "noise_gate", "0.001").toFloat());
    m_voicePipeline->setAGC(m_configManager->getBool("Audio", "agc_enabled", true));

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
        hWarning(exoWeather) << "Clé API météo manquante - fonctionnalité désactivée";
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

    // === v8.1 ULL: Context Cache ===
    m_contextCache = new ContextCache(this);
    // Weather: 60s TTL, DateTime: 10s, HA state: 30s
    m_contextCache->addRefreshRule("weather", 60000);
    m_contextCache->addRefreshRule("datetime", 10000);
    m_contextCache->addRefreshRule("ha_state", 30000);
    m_contextCache->startBackgroundRefresh();
    connect(m_contextCache, &ContextCache::refreshNeeded, this, [this](const QString &key) {
        // Pre-fill cache with fresh data
        if (key == "datetime") {
            QJsonObject dt;
            dt["date"] = QDate::currentDate().toString(Qt::ISODate);
            dt["time"] = QTime::currentTime().toString("HH:mm:ss");
            dt["day_name"] = QLocale(QLocale::French).dayName(QDate::currentDate().dayOfWeek());
            m_contextCache->set(key, dt, 10000);
        }
        // weather and ha_state will be refreshed by their respective providers
    });
    // Pre-fill datetime immediately
    {
        QJsonObject dt;
        dt["date"] = QDate::currentDate().toString(Qt::ISODate);
        dt["time"] = QTime::currentTime().toString("HH:mm:ss");
        dt["day_name"] = QLocale(QLocale::French).dayName(QDate::currentDate().dayOfWeek());
        m_contextCache->set("datetime", dt, 10000);
    }
    hAssistant() << "ContextCache initialisé avec règles de rafraîchissement";

    // === v8.1 ULL: LLM Warmup + KeepAlive ===
    if (m_claudeApi && m_claudeApi->isReady()) {
        m_claudeApi->initWarmup();
        m_claudeApi->startKeepAlive(240000);  // 4 min keepalive
    }

    // === Health Check ===
    m_healthCheck = new HealthCheck(this);
    m_healthCheck->configure(m_configManager);
    m_healthCheck->start(10000);  // Ping toutes les 10 secondes
    hAssistant() << "HealthCheck initialisé — surveillance des microservices activée";

    // === Tool Sockets (microservices outils) ===
    initToolSockets();
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
                    hWarning(exoVoice) << "Erreur vocale:" << error;
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
        hWarning(exoAssistant) << "QML Engine non disponible pour l'exposition";
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
    if (m_voicePipeline && m_voicePipeline->audioDeviceManager()) {
        m_qmlEngine->rootContext()->setContextProperty("audioDeviceManager", m_voicePipeline->audioDeviceManager());
    }

    // Exposer le LogManager pour le panneau Logs QML
    m_qmlEngine->rootContext()->setContextProperty("logManager", LogManager::instance());

    // Exposer le PipelineEventBus pour le moniteur de pipeline QML
    m_qmlEngine->rootContext()->setContextProperty("pipelineEventBus", PipelineEventBus::instance());
    
    hAssistant() << "Composants exposés au QML avec succès";
}

AudioDeviceManager* AssistantManager::audioDeviceManager() const
{
    return m_voicePipeline ? m_voicePipeline->audioDeviceManager() : nullptr;
}

void AssistantManager::sendMessage(const QString &message)
{
    if (!m_claudeApi) {
        hWarning(exoAssistant) << "sendMessage: Claude API NULL!";
        emit errorOccurred("Claude API non disponible");
        return;
    }

    hAssistant() << "=== sendMessage ===" << message.left(80)
                 << "claudeReady=" << m_claudeApi->isReady();
    
    // Stocker le message utilisateur pour la mémoire
    m_lastUserMessage = message;

    // v26.3: Fast-path — bypass Claude for simple intents (300–500 ms)
    if (tryFastPath(message))
        return;
    
    // ── Prompt système EXO v5.2 (Claude Optimisé) ──
    QString systemContext = QStringLiteral(
        "Tu es EXO, le moteur cognitif d'un assistant vocal temps réel.\n"
        "Ton rôle est de fournir des réponses immédiates, courtes, parlables, "
        "sans hésitation, parfaitement adaptées à un pipeline vocal streaming.\n"
        "L'utilisateur s'appelle Alex. Appelle-le toujours Alex, jamais autrement.\n\n"

        "STYLE : Tu parles comme un assistant vocal premium, clair, naturel, concis. "
        "Tu réponds en 1 à 2 phrases maximum sauf demande explicite. "
        "Tu vas directement à l'essentiel, sans préambule, sans remplissage. "
        "Tu ne fais aucun méta-commentaire sur ton fonctionnement. "
        "Tu n'utilises pas d'emojis sauf si demandé. "
        "Tu adaptes ton ton à celui de l'utilisateur.\n\n"

        "STREAMING : Tu produis des phrases courtes, complètes, bien ponctuées "
        "pour permettre un TTS phrase par phrase. "
        "Tu termines clairement tes phrases. "
        "Tu ne génères jamais de texte parasite avant la première phrase. "
        "Tu ne génères jamais de listes ou blocs longs sauf si demandé.\n\n"

        "LATENCE : Tu donnes la première phrase immédiatement. "
        "Tu ne fais pas d'introduction ni de transition inutile.\n\n"

        "OUTILS : Tu utilises les outils EXO uniquement quand c'est pertinent. "
        "Si un outil est nécessaire, tu l'appelles immédiatement sans commentaire. "
        "Outils disponibles : ha_turn_on, ha_turn_off, ha_toggle, ha_set_brightness, "
        "ha_set_temperature, ha_get_state (Home Assistant), "
        "get_weather (météo), get_datetime (date/heure), "
        "remember_info (mémoriser), recall_info (se souvenir), "
        "get_context (contexte actuel), create_plan (plan multi-étapes), "
        "search_web, get_news, get_summary, calculate, convert.\n\n"

        "MÉMOIRE v7 : Tu utilises remember_info pour stocker les préférences, "
        "faits personnels et souvenirs importants de l'utilisateur. "
        "Tu utilises recall_info pour retrouver des informations passées. "
        "Tu utilises get_context quand tu as besoin de connaître le moment, "
        "l'activité ou l'état des modules.\n\n"

        "SÉCURITÉ : Tu ne fais jamais d'hallucination factuelle. "
        "Si tu ne sais pas, tu réponds simplement et brièvement."
    );

    // Ajouter le contexte de mémoire intelligente si disponible
    if (m_memoryManager) {
        QString memoryContext = m_memoryManager->buildClaudeContext(5, 5);
        if (!memoryContext.isEmpty()) {
            systemContext += QStringLiteral("\n\n") + memoryContext;
        }
        systemContext += QStringLiteral(
            "\nUtilise ta mémoire des conversations précédentes "
            "et les souvenirs utilisateur pour personnaliser tes réponses.");
    }
    
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

// ═══════════════════════════════════════════════════════
//  v26.3 Fast-path — bypass Claude for trivial intents
//  Target: 300–500 ms instead of 4 s via LLM round-trip
// ═══════════════════════════════════════════════════════

bool AssistantManager::tryFastPath(const QString &message)
{
    const QString low = message.toLower();
    QElapsedTimer fpTimer;
    fpTimer.start();

    QString response;

    // ── Date / Heure (local, zero-cost) ──────────────
    bool isTime = low.contains(QLatin1String("quelle heure"))
               || (low.contains(QLatin1String("heure")) && low.contains(QLatin1String("il est")));
    bool isDate = low.contains(QLatin1String("quel jour"))
               || low.contains(QLatin1String("quelle date"))
               || low.contains(QLatin1String("on est quel"));

    if (isTime && !isDate) {
        QString t = QTime::currentTime().toString(QStringLiteral("H 'heures' mm"));
        response = QStringLiteral("Il est %1.").arg(t);
    } else if (isDate && !isTime) {
        QLocale fr(QStringLiteral("fr_FR"));
        QDate today = QDate::currentDate();
        response = QStringLiteral("Nous sommes le %1.").arg(
            fr.toString(today, QStringLiteral("dddd d MMMM yyyy")));
    } else if (isDate && isTime) {
        QLocale fr(QStringLiteral("fr_FR"));
        QDate today = QDate::currentDate();
        QString t = QTime::currentTime().toString(QStringLiteral("H 'heures' mm"));
        response = QStringLiteral("Nous sommes le %1, il est %2.")
            .arg(fr.toString(today, QStringLiteral("dddd d MMMM yyyy")), t);
    }

    // ── Météo (WeatherManager cache, ~0 ms) ─────────
    if (response.isEmpty()) {
        bool isWeather = low.contains(QLatin1String("météo"))
                      || low.contains(QLatin1String("quel temps"))
                      || (low.contains(QLatin1String("température")) && low.contains(QLatin1String("dehors")))
                      || (low.contains(QLatin1String("fait")) && low.contains(QLatin1String("dehors")));

        if (isWeather && m_weatherManager
            && !m_weatherManager->description().isEmpty()) {
            QString city = m_configManager ? m_configManager->getWeatherCity()
                                           : QStringLiteral("ici");
            response = QStringLiteral("À %1, il fait %2 degrés, %3.")
                .arg(city)
                .arg(m_weatherManager->temperature())
                .arg(m_weatherManager->description().toLower());
        }
    }

    // ── Domotique simple (allume/éteins X) ───────────
    if (response.isEmpty()) {
        bool turnOn  = low.contains(QLatin1String("allume"));
        bool turnOff = low.contains(QLatin1String("éteins"))
                    || low.contains(QLatin1String("éteindre"));

        if (turnOn || turnOff) {
            // Extract the entity from the message (after allume/éteins)
            static const QRegularExpression reOn(
                QStringLiteral("allume\\s+(?:la |le |les |l')?(.+)"),
                QRegularExpression::CaseInsensitiveOption);
            static const QRegularExpression reOff(
                QStringLiteral("(?:éteins|éteindre)\\s+(?:la |le |les |l')?(.+)"),
                QRegularExpression::CaseInsensitiveOption);

            QRegularExpressionMatch m = turnOn ? reOn.match(low) : reOff.match(low);
            if (m.hasMatch()) {
                QString entity = m.captured(1).trimmed();
                // Remove trailing punctuation
                while (!entity.isEmpty() && (entity.endsWith('.') || entity.endsWith('!')))
                    entity.chop(1);

                // Dispatch HA command via WebSocket
                QJsonObject haCommand;
                haCommand[QStringLiteral("type")] = QStringLiteral("ha_command");
                haCommand[QStringLiteral("tool")] = turnOn
                    ? QStringLiteral("ha_turn_on") : QStringLiteral("ha_turn_off");
                QJsonObject args;
                args[QStringLiteral("entity_id")] = entity;
                haCommand[QStringLiteral("arguments")] = args;

                if (m_voicePipeline) {
                    m_voicePipeline->sendWebSocketMessage(
                        QString::fromUtf8(QJsonDocument(haCommand).toJson(
                            QJsonDocument::Compact)));
                }

                response = turnOn
                    ? QStringLiteral("J'allume %1.").arg(entity)
                    : QStringLiteral("J'éteins %1.").arg(entity);
            }
        }
    }

    // ── No fast-path match → fall through to Claude ──
    if (response.isEmpty())
        return false;

    qint64 fpMs = fpTimer.elapsed();
    hAssistant() << "[FastPath]" << fpMs << "ms →" << response.left(60);

    PIPELINE_EVENT(PipelineModule::Orchestrator, EventType::ResponseReceived,
                   QJsonObject{{QStringLiteral("fast_path"), true},
                               {QStringLiteral("latency_ms"), fpMs}});

    // Latency metrics — record as LLM with near-zero time
    auto *lm = LatencyMetrics::instance();
    lm->markLlmRequest();
    lm->markLlmFirstToken();
    lm->markLlmComplete();

    // Feed TTS directly (sentence streaming)
    if (m_voicePipeline)
        m_voicePipeline->speakSentence(response);

    // Feed QML chat
    emit claudeResponseReceived(response);

    // Memory
    if (m_memoryManager && !m_lastUserMessage.isEmpty()) {
        m_memoryManager->addConversation(m_lastUserMessage, response);
        m_lastUserMessage.clear();
    }

    return true;
}

void AssistantManager::startListening()
{
    if (!m_voicePipeline) {
        hWarning(exoAssistant) << "Voice Pipeline non disponible";
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

void AssistantManager::requestNetworkScan(bool fast)
{
    QString guiId = QStringLiteral("gui_") + QUuid::createUuid().toString(QUuid::Id128);
    m_guiToolCalls.insert(guiId);

    auto *ws = m_toolSockets.value(QStringLiteral("network"));
    if (!ws || !ws->isValid()) {
        hWarning(exoAssistant) << "Network socket non disponible";
        QJsonObject err;
        err[QStringLiteral("status")] = QStringLiteral("error");
        err[QStringLiteral("message")] = QStringLiteral("Service réseau non disponible");
        m_guiToolCalls.remove(guiId);
        emit networkScanCompleted(err);
        return;
    }

    m_pendingToolCalls.insert(QStringLiteral("network"), guiId);

    QJsonObject request;
    request[QStringLiteral("action")] = fast ? QStringLiteral("scan_fast")
                                             : QStringLiteral("scan");
    request[QStringLiteral("params")] = QJsonObject();
    ws->sendTextMessage(QString::fromUtf8(
        QJsonDocument(request).toJson(QJsonDocument::Compact)));

    hAssistant() << "GUI network scan:" << (fast ? "fast" : "full");

    // Timeout 120s for full scan (ARP+mDNS+SSDP+Ping can be slow)
    int timeoutMs = fast ? 30000 : 120000;
    QTimer::singleShot(timeoutMs, this, [this, guiId]() {
        if (m_guiToolCalls.remove(guiId)) {
            if (m_pendingToolCalls.value(QStringLiteral("network")) == guiId)
                m_pendingToolCalls.remove(QStringLiteral("network"));
            hWarning(exoAssistant) << "GUI network scan timeout";
            QJsonObject err;
            err[QStringLiteral("status")] = QStringLiteral("error");
            err[QStringLiteral("message")] = QStringLiteral("Timeout scan réseau");
            emit networkScanCompleted(err);
        }
    });
}

void AssistantManager::requestHomeGraph()
{
    QString guiId = QStringLiteral("gui_") + QUuid::createUuid().toString(QUuid::Id128);
    m_guiToolCalls.insert(guiId);

    auto *ws = m_toolSockets.value(QStringLiteral("homegraph"));
    if (!ws || !ws->isValid()) {
        QJsonObject err;
        err[QStringLiteral("status")] = QStringLiteral("error");
        err[QStringLiteral("message")] = QStringLiteral("Service HomeGraph non disponible");
        m_guiToolCalls.remove(guiId);
        emit homeGraphReceived(err);
        return;
    }

    m_pendingToolCalls.insert(QStringLiteral("homegraph"), guiId);

    QJsonObject request;
    request[QStringLiteral("action")] = QStringLiteral("gui_state");
    request[QStringLiteral("params")] = QJsonObject();
    ws->sendTextMessage(QString::fromUtf8(
        QJsonDocument(request).toJson(QJsonDocument::Compact)));

    hAssistant() << "GUI HomeGraph state requested";

    QTimer::singleShot(60000, this, [this, guiId]() {
        if (m_guiToolCalls.remove(guiId)) {
            if (m_pendingToolCalls.value(QStringLiteral("homegraph")) == guiId)
                m_pendingToolCalls.remove(QStringLiteral("homegraph"));
            QJsonObject err;
            err[QStringLiteral("status")] = QStringLiteral("error");
            err[QStringLiteral("message")] = QStringLiteral("Timeout HomeGraph");
            emit homeGraphReceived(err);
        }
    });
}

void AssistantManager::requestDeviceCommand(const QString &deviceId,
                                             const QString &command,
                                             const QJsonObject &params)
{
    QString guiId = QStringLiteral("gui_") + QUuid::createUuid().toString(QUuid::Id128);
    m_guiToolCalls.insert(guiId);

    auto *ws = m_toolSockets.value(QStringLiteral("homegraph"));
    if (!ws || !ws->isValid()) {
        QJsonObject err;
        err[QStringLiteral("status")] = QStringLiteral("error");
        err[QStringLiteral("message")] = QStringLiteral("Service HomeGraph non disponible");
        m_guiToolCalls.remove(guiId);
        emit deviceCommandResult(err);
        return;
    }

    m_pendingToolCalls.insert(QStringLiteral("homegraph"), guiId);

    QJsonObject cmdParams;
    cmdParams[QStringLiteral("id_exo")] = deviceId;
    cmdParams[QStringLiteral("command")] = command;
    if (!params.isEmpty())
        cmdParams[QStringLiteral("params")] = params;

    QJsonObject request;
    request[QStringLiteral("action")] = QStringLiteral("apply_command");
    request[QStringLiteral("params")] = cmdParams;
    ws->sendTextMessage(QString::fromUtf8(
        QJsonDocument(request).toJson(QJsonDocument::Compact)));

    hAssistant() << "GUI device command:" << deviceId << command;

    QTimer::singleShot(15000, this, [this, guiId]() {
        if (m_guiToolCalls.remove(guiId)) {
            if (m_pendingToolCalls.value(QStringLiteral("homegraph")) == guiId)
                m_pendingToolCalls.remove(QStringLiteral("homegraph"));
            QJsonObject err;
            err[QStringLiteral("status")] = QStringLiteral("error");
            err[QStringLiteral("message")] = QStringLiteral("Timeout commande appareil");
            emit deviceCommandResult(err);
        }
    });
}

void AssistantManager::requestRunScenario(const QString &name)
{
    QString guiId = QStringLiteral("gui_") + QUuid::createUuid().toString(QUuid::Id128);
    m_guiToolCalls.insert(guiId);

    auto *ws = m_toolSockets.value(QStringLiteral("homegraph"));
    if (!ws || !ws->isValid()) {
        QJsonObject err;
        err[QStringLiteral("status")] = QStringLiteral("error");
        err[QStringLiteral("message")] = QStringLiteral("Service HomeGraph non disponible");
        m_guiToolCalls.remove(guiId);
        emit scenarioResult(err);
        return;
    }

    m_pendingToolCalls.insert(QStringLiteral("homegraph"), guiId);

    QJsonObject scParams;
    scParams[QStringLiteral("name")] = name;

    QJsonObject request;
    request[QStringLiteral("action")] = QStringLiteral("run_scenario");
    request[QStringLiteral("params")] = scParams;
    ws->sendTextMessage(QString::fromUtf8(
        QJsonDocument(request).toJson(QJsonDocument::Compact)));

    hAssistant() << "GUI run scenario:" << name;

    QTimer::singleShot(30000, this, [this, guiId]() {
        if (m_guiToolCalls.remove(guiId)) {
            if (m_pendingToolCalls.value(QStringLiteral("homegraph")) == guiId)
                m_pendingToolCalls.remove(QStringLiteral("homegraph"));
            QJsonObject err;
            err[QStringLiteral("status")] = QStringLiteral("error");
            err[QStringLiteral("message")] = QStringLiteral("Timeout scénario");
            emit scenarioResult(err);
        }
    });
}

// Slots

void AssistantManager::onWeatherUpdate()
{
    hWeather() << "Données météo mises à jour";
}

void AssistantManager::onError(const QString &error)
{
    hCritical(exoAssistant) << "Erreur AssistantManager:" << error;
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
    }

    // v7: notifier le ContextEngine de l'interaction
    if (!m_lastUserMessage.isEmpty()) {
        auto *ctxWs = m_toolSockets.value(QStringLiteral("context"));
        if (ctxWs && ctxWs->isValid()) {
            QJsonObject interaction;
            interaction[QStringLiteral("action")] = QStringLiteral("add_interaction");
            QJsonObject params;
            params[QStringLiteral("user")] = m_lastUserMessage;
            params[QStringLiteral("assistant")] = response.left(200);
            interaction[QStringLiteral("params")] = params;
            ctxWs->sendTextMessage(QString::fromUtf8(
                QJsonDocument(interaction).toJson(QJsonDocument::Compact)));
        }
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
        // v8.1: cache check
        if (m_contextCache && m_contextCache->has("weather")) {
            result = m_contextCache->get("weather");
            result[QStringLiteral("cached")] = true;
            m_claudeApi->sendToolResult(toolUseId, result);
            return;
        }
        // Résolution locale via WeatherManager
        if (m_weatherManager) {
            result[QStringLiteral("status")] = QStringLiteral("success");
            result[QStringLiteral("temperature")] = m_weatherManager->temperature();
            result[QStringLiteral("description")] = m_weatherManager->description();
            result[QStringLiteral("city")] = m_configManager->getWeatherCity();
            // v8.1: cache result
            if (m_contextCache)
                m_contextCache->set("weather", result, 60000);
        } else {
            result[QStringLiteral("status")] = QStringLiteral("error");
            result[QStringLiteral("message")] = QStringLiteral("Service météo non disponible");
        }
        m_claudeApi->sendToolResult(toolUseId, result);
        return;
    }

    if (toolName == QLatin1String("get_datetime")) {
        // v8.1: cache check
        if (m_contextCache && m_contextCache->has("datetime")) {
            result = m_contextCache->get("datetime");
            result[QStringLiteral("cached")] = true;
            m_claudeApi->sendToolResult(toolUseId, result);
            return;
        }
        result[QStringLiteral("status")] = QStringLiteral("success");
        result[QStringLiteral("date")] = QDate::currentDate().toString(Qt::ISODate);
        result[QStringLiteral("time")] = QTime::currentTime().toString(QStringLiteral("HH:mm:ss"));
        result[QStringLiteral("day")] = QLocale(QStringLiteral("fr_FR"))
            .dayName(QDate::currentDate().dayOfWeek());
        // v8.1: cache result
        if (m_contextCache)
            m_contextCache->set("datetime", result, 10000);
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

    // ── Outils microservices (dispatch async vers serveurs Python dédiés) ─────
    if (toolName == QLatin1String("search_web")) {
        dispatchToolToService(QStringLiteral("websearch"), toolUseId,
                              QStringLiteral("search_web"), arguments);
        return;
    }
    if (toolName == QLatin1String("get_news")) {
        dispatchToolToService(QStringLiteral("news"), toolUseId,
                              QStringLiteral("get_news"), arguments);
        return;
    }
    if (toolName == QLatin1String("get_summary")) {
        dispatchToolToService(QStringLiteral("knowledge"), toolUseId,
                              QStringLiteral("get_summary"), arguments);
        return;
    }
    if (toolName == QLatin1String("calculate")) {
        dispatchToolToService(QStringLiteral("tools"), toolUseId,
                              QStringLiteral("calculate"), arguments);
        return;
    }
    if (toolName == QLatin1String("convert")) {
        dispatchToolToService(QStringLiteral("tools"), toolUseId,
                              QStringLiteral("convert"), arguments);
        return;
    }

    // ── Outils v7 : Mémoire intelligente ─────────────────
    if (toolName == QLatin1String("remember_info")) {
        dispatchToolToService(QStringLiteral("memory"), toolUseId,
                              QStringLiteral("add"), arguments);
        return;
    }
    if (toolName == QLatin1String("recall_info")) {
        dispatchToolToService(QStringLiteral("memory"), toolUseId,
                              QStringLiteral("search"), arguments);
        return;
    }

    // ── Outils v7 : Contexte et planification ────────────
    if (toolName == QLatin1String("get_context")) {
        dispatchToolToService(QStringLiteral("context"), toolUseId,
                              QStringLiteral("get_context"), arguments);
        return;
    }
    if (toolName == QLatin1String("create_plan")) {
        dispatchToolToService(QStringLiteral("planner"), toolUseId,
                              QStringLiteral("create_plan"), arguments);
        return;
    }

    // ── Outils v8 : Agent autonome ───────────────────
    if (toolName == QLatin1String("execute_plan")) {
        dispatchToolToService(QStringLiteral("executor"), toolUseId,
                              QStringLiteral("execute_plan"), arguments);
        return;
    }
    if (toolName == QLatin1String("verify_result")) {
        dispatchToolToService(QStringLiteral("verifier"), toolUseId,
                              QStringLiteral("verify_result"), arguments);
        return;
    }
    if (toolName == QLatin1String("summarize_conversation")) {
        dispatchToolToService(QStringLiteral("memory"), toolUseId,
                              QStringLiteral("summarize_history"), arguments);
        return;
    }

    // ── Outils v8 : Fichiers ─────────────────────────
    if (toolName == QLatin1String("file_read")) {
        dispatchToolToService(QStringLiteral("files"), toolUseId,
                              QStringLiteral("file_read"), arguments);
        return;
    }
    if (toolName == QLatin1String("file_write")) {
        dispatchToolToService(QStringLiteral("files"), toolUseId,
                              QStringLiteral("file_write"), arguments);
        return;
    }
    if (toolName == QLatin1String("file_list")) {
        dispatchToolToService(QStringLiteral("files"), toolUseId,
                              QStringLiteral("file_list"), arguments);
        return;
    }

    // ── Outils v8 : Calendrier ───────────────────────
    if (toolName == QLatin1String("calendar_add")) {
        dispatchToolToService(QStringLiteral("calendar"), toolUseId,
                              QStringLiteral("calendar_add"), arguments);
        return;
    }
    if (toolName == QLatin1String("calendar_list")) {
        dispatchToolToService(QStringLiteral("calendar"), toolUseId,
                              QStringLiteral("calendar_list"), arguments);
        return;
    }

    // ── Outils v8 : Système ──────────────────────────
    if (toolName == QLatin1String("system_info")) {
        dispatchToolToService(QStringLiteral("system"), toolUseId,
                              QStringLiteral("system_info"), arguments);
        return;
    }

    // ── Outils Domotique v1 ─────────────────────────
    if (toolName == QLatin1String("domotic_action")) {
        dispatchToolToService(QStringLiteral("homegraph"), toolUseId,
                              QStringLiteral("domotic_action"), arguments);
        return;
    }
    if (toolName == QLatin1String("domotic_query")) {
        dispatchToolToService(QStringLiteral("homegraph"), toolUseId,
                              QStringLiteral("domotic_query"), arguments);
        return;
    }
    if (toolName == QLatin1String("network_scan")) {
        dispatchToolToService(QStringLiteral("network"), toolUseId,
                              QStringLiteral("scan"), arguments);
        return;
    }

    // ── Outil inconnu ────────────────────────────────
    hWarning(exoAssistant) << "Tool inconnu:" << toolName;
    result[QStringLiteral("status")] = QStringLiteral("error");
    result[QStringLiteral("message")] =
        QStringLiteral("Outil '%1' non reconnu").arg(toolName);
    m_claudeApi->sendToolResult(toolUseId, result);
}

// ═══════════════════════════════════════════════════════
//  Microservices Outils — WebSocket dispatch
// ═══════════════════════════════════════════════════════

void AssistantManager::initToolSockets()
{
    struct ServiceDef {
        QString name;
        QString section;
        QString key;
        QString defaultUrl;
    };

    const ServiceDef services[] = {
        { QStringLiteral("websearch"), QStringLiteral("Tools"), QStringLiteral("websearch_url"), QStringLiteral("ws://localhost:8773") },
        { QStringLiteral("news"),      QStringLiteral("Tools"), QStringLiteral("news_url"),      QStringLiteral("ws://localhost:8774") },
        { QStringLiteral("knowledge"), QStringLiteral("Tools"), QStringLiteral("knowledge_url"), QStringLiteral("ws://localhost:8775") },
        { QStringLiteral("tools"),     QStringLiteral("Tools"), QStringLiteral("tools_url"),     QStringLiteral("ws://localhost:8776") },
        // v7 services
        { QStringLiteral("context"),   QStringLiteral("Tools"), QStringLiteral("context_url"),   QStringLiteral("ws://localhost:8777") },
        { QStringLiteral("planner"),   QStringLiteral("Tools"), QStringLiteral("planner_url"),   QStringLiteral("ws://localhost:8778") },
        { QStringLiteral("memory"),    QStringLiteral("Memory"), QStringLiteral("semantic_server_url"), QStringLiteral("ws://localhost:8771") },
        // v8 services
        { QStringLiteral("executor"),  QStringLiteral("Tools"), QStringLiteral("executor_url"),  QStringLiteral("ws://localhost:8779") },
        { QStringLiteral("verifier"),  QStringLiteral("Tools"), QStringLiteral("verifier_url"),  QStringLiteral("ws://localhost:8780") },
        { QStringLiteral("files"),     QStringLiteral("Tools"), QStringLiteral("files_url"),     QStringLiteral("ws://localhost:8781") },
        { QStringLiteral("calendar"),  QStringLiteral("Tools"), QStringLiteral("calendar_url"),  QStringLiteral("ws://localhost:8782") },
        { QStringLiteral("system"),    QStringLiteral("Tools"), QStringLiteral("system_url"),    QStringLiteral("ws://localhost:8783") },
        // Domotique v1 services
        { QStringLiteral("homegraph"), QStringLiteral("Domotique"), QStringLiteral("homegraph_url"), QStringLiteral("ws://localhost:8784") },
        { QStringLiteral("domotic"),   QStringLiteral("Domotique"), QStringLiteral("domotic_url"),   QStringLiteral("ws://localhost:8785") },
        { QStringLiteral("camera"),    QStringLiteral("Domotique"), QStringLiteral("camera_url"),    QStringLiteral("ws://localhost:8786") },
        { QStringLiteral("samsung"),   QStringLiteral("Domotique"), QStringLiteral("samsung_url"),   QStringLiteral("ws://localhost:8787") },
        { QStringLiteral("voltalis"),  QStringLiteral("Domotique"), QStringLiteral("voltalis_url"),  QStringLiteral("ws://localhost:8788") },
        { QStringLiteral("echo"),      QStringLiteral("Domotique"), QStringLiteral("echo_url"),      QStringLiteral("ws://localhost:8789") },
        { QStringLiteral("network"),   QStringLiteral("Domotique"), QStringLiteral("network_url"),   QStringLiteral("ws://localhost:8790") },
    };

    for (const auto &svc : services) {
        QString url = m_configManager->getString(svc.section, svc.key, svc.defaultUrl);
        auto *ws = new QWebSocket(QString(), QWebSocketProtocol::VersionLatest, this);

        const QString serviceName = svc.name;

        connect(ws, &QWebSocket::connected, this, [this, serviceName]() {
            hAssistant() << "Tool socket connecté:" << serviceName;
        });

        connect(ws, &QWebSocket::disconnected, this, [this, serviceName]() {
            hAssistant() << "Tool socket déconnecté:" << serviceName;
            // Reconnexion automatique après 3 secondes
            QTimer::singleShot(3000, this, [this, serviceName]() {
                if (auto *sock = m_toolSockets.value(serviceName)) {
                    QString url = m_configManager->getString(
                        QStringLiteral("Tools"),
                        serviceName + QStringLiteral("_url"),
                        QStringLiteral("ws://localhost:8773"));
                    sock->open(QUrl(url));
                }
            });
        });

        connect(ws, &QWebSocket::textMessageReceived, this,
                [this, serviceName](const QString &msg) {
                    onToolServiceMessage(serviceName, msg);
                });

        m_toolSockets.insert(svc.name, ws);
        ws->open(QUrl(url));
        hAssistant() << "Tool socket" << svc.name << "→" << url;
    }
}

void AssistantManager::dispatchToolToService(const QString &service,
                                              const QString &toolUseId,
                                              const QString &action,
                                              const QJsonObject &params)
{
    auto *ws = m_toolSockets.value(service);
    if (!ws || !ws->isValid()) {
        hWarning(exoAssistant) << "Tool socket non disponible:" << service;
        QJsonObject err;
        err[QStringLiteral("status")] = QStringLiteral("error");
        err[QStringLiteral("message")] =
            QStringLiteral("Service %1 non disponible").arg(service);
        m_claudeApi->sendToolResult(toolUseId, err);
        return;
    }

    // Stocker le tool_use_id en attente pour ce service
    m_pendingToolCalls.insert(service, toolUseId);

    // Envoyer la requête au microservice
    QJsonObject request;
    request[QStringLiteral("action")] = action;
    request[QStringLiteral("params")] = params;

    QJsonDocument doc(request);
    ws->sendTextMessage(QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));

    hAssistant() << "Tool dispatch:" << action << "→" << service
                 << "(tool_use_id:" << toolUseId << ")";

    // Timeout : si pas de réponse en 15 secondes, envoyer une erreur à Claude
    QTimer::singleShot(15000, this, [this, service, toolUseId]() {
        if (m_pendingToolCalls.value(service) == toolUseId) {
            m_pendingToolCalls.remove(service);
            hWarning(exoAssistant) << "Tool timeout:" << service;
            QJsonObject err;
            err[QStringLiteral("status")] = QStringLiteral("error");
            err[QStringLiteral("message")] =
                QStringLiteral("Timeout: le service %1 n'a pas répondu").arg(service);
            m_claudeApi->sendToolResult(toolUseId, err);
        }
    });
}

void AssistantManager::onToolServiceMessage(const QString &service,
                                             const QString &message)
{
    QJsonDocument doc = QJsonDocument::fromJson(message.toUtf8());
    if (doc.isNull()) return;

    QJsonObject msg = doc.object();

    // Ignorer les messages ready et pong (protocole interne)
    QString type = msg.value(QStringLiteral("type")).toString();
    if (type == QLatin1String("ready") || type == QLatin1String("pong"))
        return;

    // Récupérer le tool_use_id en attente
    QString toolUseId = m_pendingToolCalls.value(service);
    if (toolUseId.isEmpty()) {
        hAssistant() << "Message tool reçu sans requête en attente:" << service;
        return;
    }

    m_pendingToolCalls.remove(service);

    // GUI-initiated request → emit signal, don't forward to Claude
    if (m_guiToolCalls.remove(toolUseId)) {
        QJsonObject result;
        if (msg.value(QStringLiteral("ok")).toBool()) {
            result = msg.value(QStringLiteral("data")).toObject();
            result[QStringLiteral("status")] = QStringLiteral("success");
        } else {
            result[QStringLiteral("status")] = QStringLiteral("error");
            result[QStringLiteral("message")] =
                msg.value(QStringLiteral("error")).toString(QStringLiteral("Erreur inconnue"));
        }
        hAssistant() << "GUI tool response:" << service;

        // Route to correct signal based on service
        if (service == QLatin1String("network")) {
            emit networkScanCompleted(result);
        } else if (service == QLatin1String("homegraph")) {
            // Detect action type from result content
            if (result.contains(QStringLiteral("devices"))
                || result.contains(QStringLiteral("rooms"))
                || result.contains(QStringLiteral("scenarios"))) {
                emit homeGraphReceived(result);
            } else if (result.contains(QStringLiteral("state"))
                       || result.contains(QStringLiteral("ok"))) {
                emit deviceCommandResult(result);
            } else {
                emit homeGraphReceived(result);
            }
        } else {
            // Fallback
            emit homeGraphReceived(result);
        }
        return;
    }

    // Construire le résultat pour Claude
    QJsonObject result;
    if (msg.value(QStringLiteral("ok")).toBool()) {
        result[QStringLiteral("status")] = QStringLiteral("success");
        QJsonObject data = msg.value(QStringLiteral("data")).toObject();
        // Fusionner les données dans le résultat
        for (auto it = data.begin(); it != data.end(); ++it) {
            result.insert(it.key(), it.value());
        }
    } else {
        result[QStringLiteral("status")] = QStringLiteral("error");
        result[QStringLiteral("message")] =
            msg.value(QStringLiteral("error")).toString(QStringLiteral("Erreur inconnue"));
    }

    hAssistant() << "Tool response:" << service << "→ status:"
                 << result.value(QStringLiteral("status")).toString();

    m_claudeApi->sendToolResult(toolUseId, result);
}