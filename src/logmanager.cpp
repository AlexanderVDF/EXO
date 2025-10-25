#include "logmanager.h"
#include <QDebug>
#include <QDir>
#include <QStandardPaths>
#include <QDateTime>
#include <QTextStream>
#include <QCoreApplication>
#include <iostream>

// Définition des catégories de logging
Q_LOGGING_CATEGORY(henriMain, "henri.main")
Q_LOGGING_CATEGORY(henriConfig, "henri.config")
Q_LOGGING_CATEGORY(henriClaude, "henri.claude")
Q_LOGGING_CATEGORY(henriVoice, "henri.voice")
Q_LOGGING_CATEGORY(henriWeather, "henri.weather")
Q_LOGGING_CATEGORY(henriAssistant, "henri.assistant")

LogManager* LogManager::s_instance = nullptr;

LogManager* LogManager::instance()
{
    if (!s_instance) {
        s_instance = new LogManager();
    }
    return s_instance;
}

LogManager::LogManager(QObject *parent)
    : QObject(parent)
    , m_currentLevel(Info)
    , m_consoleEnabled(true)
    , m_fileEnabled(false)
    , m_oldHandler(nullptr)
{
}

LogManager::~LogManager()
{
    if (m_oldHandler) {
        qInstallMessageHandler(m_oldHandler);
    }
}

void LogManager::initialize(LogLevel level, bool enableConsole, bool enableFile)
{
    m_currentLevel = level;
    m_consoleEnabled = enableConsole;
    m_fileEnabled = enableFile;
    
    // Installer notre gestionnaire de messages
    m_oldHandler = qInstallMessageHandler([](QtMsgType type, const QMessageLogContext &context, const QString &msg) {
        LogManager::instance()->handleMessage(type, context, msg);
    });
    
    // Configurer les règles de logging
    setupLoggingRules();
    
    if (m_fileEnabled) {
        createLogFile();
    }
    
    hLog() << "=== Système de logging Henri initialisé ===";
    hLog() << "Niveau:" << logLevelToString(m_currentLevel);
    hLog() << "Console:" << (m_consoleEnabled ? "Activée" : "Désactivée");
    hLog() << "Fichier:" << (m_fileEnabled ? "Activé" : "Désactivé");
}

void LogManager::setLogLevel(LogLevel level)
{
    m_currentLevel = level;
    setupLoggingRules();
    hLog() << "Niveau de logging changé à:" << logLevelToString(level);
}

void LogManager::setLogLevel(const QString &levelName)
{
    LogLevel level = stringToLogLevel(levelName);
    setLogLevel(level);
}

void LogManager::enableFileLogging(const QString &logFilePath)
{
    if (logFilePath.isEmpty()) {
        QString logDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        QDir().mkpath(logDir);
        m_logFilePath = QDir(logDir).filePath("henri.log");
    } else {
        m_logFilePath = logFilePath;
    }
    
    m_fileEnabled = true;
    createLogFile();
    hLog() << "Logging fichier activé:" << m_logFilePath;
}

void LogManager::disableFileLogging()
{
    m_fileEnabled = false;
    m_logFilePath.clear();
    hLog() << "Logging fichier désactivé";
}

QString LogManager::logLevelToString(LogLevel level)
{
    switch (level) {
        case Debug:    return "Debug";
        case Info:     return "Info";
        case Warning:  return "Warning";
        case Critical: return "Critical";
        default:       return "Unknown";
    }
}

LogManager::LogLevel LogManager::stringToLogLevel(const QString &levelName)
{
    QString lower = levelName.toLower();
    if (lower == "debug") return Debug;
    if (lower == "info") return Info;
    if (lower == "warning") return Warning;
    if (lower == "critical") return Critical;
    return Info; // Par défaut
}

void LogManager::setupLoggingRules()
{
    // Activer/désactiver les catégories selon le niveau
    bool debugEnabled = (m_currentLevel <= Debug);
    bool infoEnabled = (m_currentLevel <= Info);
    bool warningEnabled = (m_currentLevel <= Warning);
    
    // Configuration des règles Qt Logging
    QString rules;
    if (debugEnabled) {
        rules += "henri.*.debug=true\n";
    } else {
        rules += "henri.*.debug=false\n";
    }
    
    if (infoEnabled) {
        rules += "henri.*.info=true\n";
    } else {
        rules += "henri.*.info=false\n";
    }
    
    if (warningEnabled) {
        rules += "henri.*.warning=true\n";
    } else {
        rules += "henri.*.warning=false\n";
    }
    
    rules += "henri.*.critical=true\n"; // Toujours activé
    
    QLoggingCategory::setFilterRules(rules);
}

void LogManager::createLogFile()
{
    if (m_logFilePath.isEmpty()) {
        return;
    }
    
    // S'assurer que le répertoire existe
    QFileInfo fileInfo(m_logFilePath);
    QDir().mkpath(fileInfo.absolutePath());
    
    // Le fichier sera créé automatiquement lors de la première écriture
}

void LogManager::handleMessage(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    LogManager* manager = LogManager::instance();
    
    // Format du message
    QString timestamp = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss.zzz");
    QString typeStr;
    
    switch (type) {
        case QtDebugMsg:    typeStr = "DEBUG"; break;
        case QtInfoMsg:     typeStr = "INFO "; break;
        case QtWarningMsg:  typeStr = "WARN "; break;
        case QtCriticalMsg: typeStr = "CRIT "; break;
        case QtFatalMsg:    typeStr = "FATAL"; break;
    }
    
    // Extraire la catégorie proprement
    QString category = QString(context.category);
    if (category.startsWith("henri.")) {
        category = category.mid(6); // Supprimer "henri."
    }
    
    QString formattedMsg = QString("[%1] %2 [%3] %4")
                          .arg(timestamp)
                          .arg(typeStr)
                          .arg(category.toUpper())
                          .arg(msg);
    
    // Sortie console
    if (manager->m_consoleEnabled) {
        std::cout << formattedMsg.toStdString() << std::endl;
    }
    
    // Sortie fichier
    if (manager->m_fileEnabled && !manager->m_logFilePath.isEmpty()) {
        QFile logFile(manager->m_logFilePath);
        if (logFile.open(QIODevice::WriteOnly | QIODevice::Append)) {
            QTextStream stream(&logFile);
            stream << formattedMsg << Qt::endl;
        }
    }
    
    // Pour les messages fatals, restaurer le gestionnaire par défaut
    if (type == QtFatalMsg) {
        if (manager->m_oldHandler) {
            qInstallMessageHandler(manager->m_oldHandler);
        }
        abort();
    }
}