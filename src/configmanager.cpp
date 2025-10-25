#include "configmanager.h"
#include <QDebug>
#include <QDir>
#include <QCoreApplication>
#include <QStandardPaths>

// Constantes par défaut
const QString ConfigManager::DEFAULT_WAKE_WORD = "Exo";
const QString ConfigManager::DEFAULT_WEATHER_CITY = "Paris";
const QString ConfigManager::DEFAULT_CLAUDE_MODEL = "claude-3-haiku-20240307";
const QString ConfigManager::DEFAULT_VOICE_LANGUAGE = "fr-FR";
const QString ConfigManager::DEFAULT_LOG_LEVEL = "Info";
const double ConfigManager::DEFAULT_VOICE_RATE = -0.3;
const double ConfigManager::DEFAULT_VOICE_PITCH = -0.1;
const double ConfigManager::DEFAULT_VOICE_VOLUME = 0.9;
const int ConfigManager::DEFAULT_WEATHER_UPDATE_INTERVAL = 600000; // 10 minutes

ConfigManager::ConfigManager(QObject *parent)
    : QObject(parent)
    , m_settings(nullptr)
    , m_isLoaded(false)
{
    qDebug() << "ConfigManager créé";
}

ConfigManager::~ConfigManager()
{
    if (m_settings) {
        delete m_settings;
    }
}

bool ConfigManager::loadConfiguration(const QString &configPath)
{
    m_configPath = configPath;
    
    // Vérifier si le fichier existe
    QDir appDir(QCoreApplication::applicationDirPath());
    QString fullPath = appDir.absoluteFilePath(configPath);
    
    if (!QFile::exists(fullPath)) {
        qWarning() << "Fichier de configuration non trouvé:" << fullPath;
        qDebug() << "Utilisation des valeurs par défaut";
        setDefaultValues();
        return false;
    }
    
    // Charger les paramètres
    if (m_settings) {
        delete m_settings;
    }
    
    m_settings = new QSettings(fullPath, QSettings::IniFormat, this);
    
    if (m_settings->status() != QSettings::NoError) {
        qCritical() << "Erreur lors du chargement de la configuration:" << fullPath;
        emit configurationError("Impossible de charger le fichier de configuration");
        return false;
    }
    
    m_isLoaded = true;
    qDebug() << "Configuration chargée depuis:" << fullPath;
    
    // Vérifier les clés essentielles
    QString claudeKey = getClaudeApiKey();
    QString weatherKey = getWeatherApiKey();
    
    if (claudeKey.isEmpty()) {
        qWarning() << "Clé API Claude manquante dans la configuration";
    }
    
    if (weatherKey.isEmpty()) {
        qWarning() << "Clé API météo manquante dans la configuration";
    }
    
    emit configurationLoaded();
    return true;
}

void ConfigManager::setDefaultValues()
{
    if (m_settings) {
        delete m_settings;
    }
    
    // Créer une configuration temporaire en mémoire
    m_settings = new QSettings(QSettings::IniFormat, QSettings::UserScope, 
                              "HenriAssistant", "default", this);
    
    m_isLoaded = true;
}

QString ConfigManager::getClaudeApiKey() const
{
    return getConfigValue("Claude", "api_key");
}

QString ConfigManager::getClaudeModel() const
{
    return getConfigValue("Claude", "model", DEFAULT_CLAUDE_MODEL);
}

QString ConfigManager::getWeatherApiKey() const
{
    return getConfigValue("OpenWeatherMap", "api_key");
}

QString ConfigManager::getWeatherCity() const
{
    return getConfigValue("OpenWeatherMap", "city", DEFAULT_WEATHER_CITY);
}

int ConfigManager::getWeatherUpdateInterval() const
{
    return getConfigValueInt("OpenWeatherMap", "update_interval", DEFAULT_WEATHER_UPDATE_INTERVAL);
}

QString ConfigManager::getWakeWord() const
{
    return getConfigValue("Voice", "wake_word", DEFAULT_WAKE_WORD);
}

double ConfigManager::getVoiceRate() const
{
    return getConfigValueDouble("Voice", "voice_rate", DEFAULT_VOICE_RATE);
}

double ConfigManager::getVoicePitch() const
{
    return getConfigValueDouble("Voice", "voice_pitch", DEFAULT_VOICE_PITCH);
}

double ConfigManager::getVoiceVolume() const
{
    return getConfigValueDouble("Voice", "voice_volume", DEFAULT_VOICE_VOLUME);
}

QString ConfigManager::getVoiceLanguage() const
{
    return getConfigValue("Voice", "language", DEFAULT_VOICE_LANGUAGE);
}

QString ConfigManager::getLogLevel() const
{
    return getConfigValue("Logging", "level", DEFAULT_LOG_LEVEL);
}

bool ConfigManager::isDebugEnabled() const
{
    return getConfigValueBool("Logging", "debug_enabled", true);
}

bool ConfigManager::saveConfiguration()
{
    if (!m_settings) {
        qCritical() << "Aucune configuration à sauvegarder";
        return false;
    }
    
    m_settings->sync();
    
    if (m_settings->status() != QSettings::NoError) {
        qCritical() << "Erreur lors de la sauvegarde de la configuration";
        return false;
    }
    
    qDebug() << "Configuration sauvegardée avec succès";
    return true;
}

// Méthodes utilitaires privées
QString ConfigManager::getConfigValue(const QString &section, const QString &key, const QString &defaultValue) const
{
    if (!m_settings) {
        return defaultValue;
    }
    
    return m_settings->value(section + "/" + key, defaultValue).toString();
}

double ConfigManager::getConfigValueDouble(const QString &section, const QString &key, double defaultValue) const
{
    if (!m_settings) {
        return defaultValue;
    }
    
    bool ok;
    double value = m_settings->value(section + "/" + key, defaultValue).toDouble(&ok);
    return ok ? value : defaultValue;
}

int ConfigManager::getConfigValueInt(const QString &section, const QString &key, int defaultValue) const
{
    if (!m_settings) {
        return defaultValue;
    }
    
    bool ok;
    int value = m_settings->value(section + "/" + key, defaultValue).toInt(&ok);
    return ok ? value : defaultValue;
}

bool ConfigManager::getConfigValueBool(const QString &section, const QString &key, bool defaultValue) const
{
    if (!m_settings) {
        return defaultValue;
    }
    
    return m_settings->value(section + "/" + key, defaultValue).toBool();
}