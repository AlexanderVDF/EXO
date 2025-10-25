#pragma once

#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QJsonObject>
#include <QJsonDocument>
#include <QQmlApplicationEngine>
#include <QQuickItem>

class ClaudeAPI;
class WeatherManager;
// Note: SpeechManager et SystemMonitor déplacés dans modules_advanced

/**
 * @brief Gestionnaire principal de l'assistant personnel
 * 
 * Coordonne les interactions entre l'interface QML, l'API Claude,
 * la reconnaissance vocale et le monitoring système.
 */
class AssistantManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentStatus READ currentStatus NOTIFY statusChanged)
    Q_PROPERTY(bool isListening READ isListening NOTIFY listeningStateChanged)
    Q_PROPERTY(bool isProcessing READ isProcessing NOTIFY processingStateChanged)
    Q_PROPERTY(QString lastResponse READ lastResponse NOTIFY responseReceived)
    Q_PROPERTY(int batteryLevel READ batteryLevel NOTIFY batteryLevelChanged)
    Q_PROPERTY(double cpuUsage READ cpuUsage NOTIFY cpuUsageChanged)

public:
    explicit AssistantManager(QObject *parent = nullptr);
    ~AssistantManager();

    // Propriétés accessibles depuis QML
    QString currentStatus() const { return m_currentStatus; }
    bool isListening() const { return m_isListening; }
    bool isProcessing() const { return m_isProcessing; }
    QString lastResponse() const { return m_lastResponse; }
    int batteryLevel() const { return m_batteryLevel; }
    double cpuUsage() const { return m_cpuUsage; }

    // Initialisation
    void initialize();
    void setQmlEngine(QQmlApplicationEngine* engine);

public slots:
    // Méthodes appelables depuis QML
    Q_INVOKABLE void startListening();
    Q_INVOKABLE void stopListening();
    Q_INVOKABLE void sendTextQuery(const QString& text);
    Q_INVOKABLE void toggleMute();
    Q_INVOKABLE void adjustVolume(double level);
    Q_INVOKABLE void shutdown();
    Q_INVOKABLE void reboot();
    Q_INVOKABLE QString getSystemInfo();

signals:
    // Signaux pour QML
    void statusChanged(const QString& status);
    void listeningStateChanged(bool listening);
    void processingStateChanged(bool processing);
    void responseReceived(const QString& response);
    void batteryLevelChanged(int level);
    void cpuUsageChanged(double usage);
    void errorOccurred(const QString& error);
    void voiceInputReceived(const QString& text);

private slots:
    void onVoiceInputReceived(const QString& text);
    void onClaudeResponseReceived(const QString& response);
    void onClaudeErrorOccurred(const QString& error);
    void onWeatherResponseReceived(const QString& response);
    void onSystemStatsUpdated();
    void updateSystemMonitoring();

private:
    void setStatus(const QString& status);
    void setListening(bool listening);
    void setProcessing(bool processing);
    void loadConfiguration();
    void saveConfiguration();
    void setupPythonEnvironment();
    void initializeSystemServices();

    // Composants principaux
    ClaudeAPI* m_claudeApi;
    SpeechManager* m_speechManager;
    SystemMonitor* m_systemMonitor;
    WeatherManager* m_weatherManager;
    QQmlApplicationEngine* m_qmlEngine;

    // État de l'assistant
    QString m_currentStatus;
    bool m_isListening;
    bool m_isProcessing;
    QString m_lastResponse;
    
    // Monitoring système
    int m_batteryLevel;
    double m_cpuUsage;
    QTimer* m_systemTimer;
    
    // Configuration
    QJsonObject m_config;
    QString m_configPath;
    
    // Processus Python
    QProcess* m_pythonProcess;
    bool m_pythonReady;
};