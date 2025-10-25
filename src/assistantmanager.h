#pragma once

#include <QObject>
#include <QTimer>
#include <QJsonObject>
#include <QJsonDocument>
#include <QQmlApplicationEngine>

class ClaudeAPI;
class WeatherManager;
class VoiceManager;
class ConfigManager;

/**
 * @brief Gestionnaire principal de l'assistant Henri (version simplifiée)
 * 
 * Coordonne les interactions entre Claude API, Weather Manager et l'interface QML
 */
class AssistantManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isListening READ isListening NOTIFY listeningStateChanged)
    Q_PROPERTY(bool isInitialized READ isInitialized NOTIFY initializationComplete)

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
    Q_INVOKABLE void startListening();
    Q_INVOKABLE void stopListening();
    Q_INVOKABLE QString getWeatherSummary() const;
    
    // Accès aux composants pour l'exposition QML
    ClaudeAPI* claudeApi() const { return m_claudeApi; }
    VoiceManager* voiceManager() const { return m_voiceManager; }
    WeatherManager* weatherManager() const { return m_weatherManager; }
    ConfigManager* configManager() const { return m_configManager; }

signals:
    void messageReceived(const QString &sender, const QString &message);
    void listeningStateChanged(bool isListening);
    void initializationComplete();
    void errorOccurred(const QString &error);

private slots:
    void onClaudeResponse(const QString &response);
    void onWeatherUpdate();
    void onError(const QString &error);
    void onConfigurationLoaded();

private:
    void initializeComponents();
    void setupConnections();
    void exposeToQml();

    // Membres privés
    bool m_isListening;
    bool m_isInitialized;
    
    // Composants
    ConfigManager *m_configManager;
    ClaudeAPI *m_claudeApi;
    VoiceManager *m_voiceManager;
    WeatherManager *m_weatherManager;
    QQmlApplicationEngine *m_qmlEngine;
};