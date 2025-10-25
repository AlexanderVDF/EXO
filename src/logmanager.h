#pragma once

#include <QObject>
#include <QLoggingCategory>
#include <QString>

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