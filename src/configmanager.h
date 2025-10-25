#pragma once

#include <QObject>
#include <QSettings>
#include <QString>

/**
 * @brief Gestionnaire centralisé de configuration pour Henri
 * 
 * Charge et gère tous les paramètres de configuration depuis les fichiers
 * de configuration, évitant les valeurs hardcodées dans le code.
 */
class ConfigManager : public QObject
{
    Q_OBJECT

public:
    explicit ConfigManager(QObject *parent = nullptr);
    ~ConfigManager();

    // Initialisation
    bool loadConfiguration(const QString &configPath = "config/assistant.conf");
    bool isLoaded() const { return m_isLoaded; }

    // API Keys
    QString getClaudeApiKey() const;
    QString getClaudeModel() const;
    QString getWeatherApiKey() const;
    
    // Paramètres généraux
    QString getWeatherCity() const;
    QString getWakeWord() const;
    int getWeatherUpdateInterval() const;
    
    // Paramètres de synthèse vocale
    double getVoiceRate() const;
    double getVoicePitch() const;
    double getVoiceVolume() const;
    QString getVoiceLanguage() const;
    
    // Paramètres de logging
    QString getLogLevel() const;
    bool isDebugEnabled() const;
    
    // Sauvegarde
    bool saveConfiguration();

signals:
    void configurationLoaded();
    void configurationError(const QString &error);

private:
    void setDefaultValues();
    QString getConfigValue(const QString &section, const QString &key, const QString &defaultValue = QString()) const;
    double getConfigValueDouble(const QString &section, const QString &key, double defaultValue = 0.0) const;
    int getConfigValueInt(const QString &section, const QString &key, int defaultValue = 0) const;
    bool getConfigValueBool(const QString &section, const QString &key, bool defaultValue = false) const;

    QSettings *m_settings;
    bool m_isLoaded;
    QString m_configPath;
    
    // Valeurs par défaut
    static const QString DEFAULT_WAKE_WORD;
    static const QString DEFAULT_WEATHER_CITY;
    static const QString DEFAULT_CLAUDE_MODEL;
    static const QString DEFAULT_VOICE_LANGUAGE;
    static const QString DEFAULT_LOG_LEVEL;
    static const double DEFAULT_VOICE_RATE;
    static const double DEFAULT_VOICE_PITCH;
    static const double DEFAULT_VOICE_VOLUME;
    static const int DEFAULT_WEATHER_UPDATE_INTERVAL;
};