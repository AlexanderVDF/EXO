#pragma once

#include <QObject>
#include <QTimer>
#include <QJsonObject>
#include <QJsonDocument>
#include <QQmlApplicationEngine>
#include "ConfigManager.h"
#include "HealthCheck.h"

class ClaudeAPI;
class WeatherManager;
class VoicePipeline;
class AIMemoryManager;
class AudioDeviceManager;

Q_DECLARE_METATYPE(ConfigManager*)

/**
 * @brief Gestionnaire principal de l'assistant EXO (version simplifiée)
 * 
 * Coordonne les interactions entre Claude API, Weather Manager et l'interface QML
 */
class AssistantManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isListening READ isListening NOTIFY listeningStateChanged)
    Q_PROPERTY(bool isInitialized READ isInitialized NOTIFY initializationComplete)
    Q_PROPERTY(ConfigManager* configManager READ configManager CONSTANT)
    Q_PROPERTY(HealthCheck* healthCheck READ healthCheck CONSTANT)
    Q_PROPERTY(AudioDeviceManager* audioDeviceManager READ audioDeviceManager CONSTANT)

public:
    explicit AssistantManager(QObject *parent = nullptr);
    ~AssistantManager();

    // Propriétés
    bool isListening() const { return m_isListening; }
    bool isInitialized() const { return m_isInitialized; }
    
    // Configuration
    void setQmlEngine(QQmlApplicationEngine *engine);

    // Méthodes publiques
    Q_INVOKABLE bool initializeWithConfig(const QString &configPath = "config/assistant.conf");
    Q_INVOKABLE void sendMessage(const QString &message);
    Q_INVOKABLE void sendManualQuery(const QString &text);
    Q_INVOKABLE void startListening();
    Q_INVOKABLE void stopListening();
    Q_INVOKABLE QString getWeatherSummary() const;
    
    // Accès aux composants pour l'exposition QML  
    ClaudeAPI* claudeApi() const { return m_claudeApi; }
    VoicePipeline* voicePipeline() const { return m_voicePipeline; }
    WeatherManager* weatherManager() const { return m_weatherManager; }
    ConfigManager* configManager() const { return m_configManager; }
    AIMemoryManager* memoryManager() const { return m_memoryManager; }
    HealthCheck* healthCheck() const { return m_healthCheck; }
    AudioDeviceManager* audioDeviceManager() const;

signals:
    void messageReceived(const QString &sender, const QString &message);
    void claudeResponseReceived(const QString &response);
    void claudePartialResponse(const QString &partialText);
    void listeningStateChanged(bool isListening);
    void initializationComplete();
    void errorOccurred(const QString &error);

private slots:
    void onClaudeResponse(const QString &response);
    void onClaudePartial(const QString &text);
    void onToolCall(const QString &toolUseId,
                    const QString &toolName,
                    const QJsonObject &arguments);
    void onWeatherUpdate();
    void onError(const QString &error);
    void onConfigurationLoaded();

private:
    void initializeComponents();
    void setupConnections();
    void exposeToQml();
    void sendWelcomeMessage();
    void onSpeechTranscribed(const QString &transcription);

    // Membres privés
    bool m_isListening;
    bool m_isInitialized;
    QString m_lastUserMessage;
    
    // Composants
    ConfigManager *m_configManager;
    ClaudeAPI *m_claudeApi;
    VoicePipeline *m_voicePipeline;
    WeatherManager *m_weatherManager;
    AIMemoryManager *m_memoryManager;
    HealthCheck *m_healthCheck;
    QQmlApplicationEngine *m_qmlEngine;
};