#pragma once

#include <QObject>
#include <QLoggingCategory>
#include <QString>
#include <QJsonObject>

/**
 * @brief Gestionnaire centralisé de logging pour Henri
 * 
 * Fournit des catégories de logging organisées et configurables
 * pour remplacer les qDebug() dispersés dans le code.
 */

// Déclaration des catégories de logging
Q_DECLARE_LOGGING_CATEGORY(henriMain)
Q_DECLARE_LOGGING_CATEGORY(henriConfig)
Q_DECLARE_LOGGING_CATEGORY(henriClaude)
Q_DECLARE_LOGGING_CATEGORY(henriVoice)
Q_DECLARE_LOGGING_CATEGORY(henriWeather)
Q_DECLARE_LOGGING_CATEGORY(henriAssistant)

class LogManager : public QObject
{
    Q_OBJECT

public:
    enum LogLevel {
        Debug = 0,
        Info = 1,
        Warning = 2,
        Critical = 3
    };
    Q_ENUM(LogLevel)

    static LogManager* instance();
    
    // Configuration du système de logging
    void initialize(LogLevel level = Info, bool enableConsole = true, bool enableFile = false);
    void setLogLevel(LogLevel level);
    void setLogLevel(const QString &levelName);
    
    // Gestion des fichiers de log
    void enableFileLogging(const QString &logFilePath = QString());
    void disableFileLogging();
    
    // Utilitaires
    static QString logLevelToString(LogLevel level);
    static LogLevel stringToLogLevel(const QString &levelName);

    Q_INVOKABLE QStringList getRecentLogs() const { return m_recentLogs; }
    Q_INVOKABLE void clearLogs() { m_recentLogs.clear(); }
    Q_INVOKABLE void copyToClipboard(const QString &text);

    // Structured pipeline logging
    Q_INVOKABLE QStringList getRecentPipelineEvents() const { return m_pipelineEvents; }
    void logPipelineEvent(const QJsonObject &event);

signals:
    void newLogEntry(const QString &entry);
    void newPipelineEvent(const QJsonObject &event);

public slots:
    void handleMessage(QtMsgType type, const QMessageLogContext &context, const QString &msg);

private:
    explicit LogManager(QObject *parent = nullptr);
    ~LogManager();
    
    void setupLoggingRules();
    void createLogFile();
    
    static LogManager* s_instance;
    
    LogLevel m_currentLevel;
    bool m_consoleEnabled;
    bool m_fileEnabled;
    QString m_logFilePath;
    
    // Ancienne fonction de message pour restauration
    QtMessageHandler m_oldHandler;

    // Buffer circulaire pour le QML LogPanel
    QStringList m_recentLogs;
    static constexpr int MAX_LOG_ENTRIES = 500;

    // Pipeline events for structured logging
    QStringList m_pipelineEvents;
    static constexpr int MAX_PIPELINE_EVENTS = 200;
};

// Macros de convenance pour un usage simplifié
#define hLog()      qCInfo(henriMain)
#define hConfig()   qCInfo(henriConfig)
#define hClaude()   qCInfo(henriClaude)
#define hVoice()    qCInfo(henriVoice)
#define hWeather()  qCInfo(henriWeather)
#define hAssistant() qCInfo(henriAssistant)

#define hDebug(category)    qCDebug(category)
#define hWarning(category)  qCWarning(category)
#define hCritical(category) qCCritical(category)