#pragma once

#include <QObject>
#include <QProcess>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QAudioOutput>
#include <QMediaPlayer>
#include <QTemporaryFile>

/**
 * @brief Gestionnaire de synthèse vocale Microsoft Henri
 * 
 * Utilise l'API Azure Cognitive Services Speech pour la voix française Henri
 * Optimisé pour qualité audio supérieure sur Raspberry Pi 5
 */
class MicrosoftTTSManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isConfigured READ isConfigured NOTIFY configurationChanged)
    Q_PROPERTY(bool isSpeaking READ isSpeaking NOTIFY speakingStateChanged)
    Q_PROPERTY(double speechRate READ speechRate WRITE setSpeechRate NOTIFY speechRateChanged)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(QString voice READ voice WRITE setVoice NOTIFY voiceChanged)

public:
    explicit MicrosoftTTSManager(QObject *parent = nullptr);
    ~MicrosoftTTSManager();

    // Configuration
    void setAzureApiKey(const QString& apiKey);
    void setAzureRegion(const QString& region);
    
    // Propriétés
    bool isConfigured() const { return m_isConfigured; }
    bool isSpeaking() const { return m_isSpeaking; }
    double speechRate() const { return m_speechRate; }
    double volume() const { return m_volume; }
    QString voice() const { return m_currentVoice; }

    // Voix disponibles
    enum FrenchVoice {
        Henri,      // Voix masculine française (recommandé)
        Denise,     // Voix féminine française 
        Alain,      // Voix masculine québécoise
        Marie       // Voix féminine québécoise
    };
    Q_ENUM(FrenchVoice)

public slots:
    Q_INVOKABLE void speakText(const QString& text);
    Q_INVOKABLE void speakTextWithEmotion(const QString& text, const QString& emotion);
    Q_INVOKABLE void stopSpeaking();
    Q_INVOKABLE void pauseSpeaking();
    Q_INVOKABLE void resumeSpeaking();
    
    void setSpeechRate(double rate);
    void setVolume(double volume);
    void setVoice(const QString& voiceName);
    void setVoice(FrenchVoice voice);
    
    Q_INVOKABLE void testConfiguration();
    Q_INVOKABLE QStringList getAvailableVoices() const;

signals:
    void configurationChanged(bool configured);
    void speakingStateChanged(bool speaking);
    void speechRateChanged(double rate);
    void volumeChanged(double volume);
    void voiceChanged(const QString& voice);
    
    void speechStarted();
    void speechFinished();
    void speechError(const QString& error);
    void configurationError(const QString& error);

private slots:
    void handleNetworkReply();
    void handleMediaPlayerStateChanged(QMediaPlayer::PlaybackState state);
    void handleMediaPlayerError(QMediaPlayer::Error error);

private:
    void setupAudioSystem();
    QString createSSMLRequest(const QString& text, const QString& emotion = QString()) const;
    QString getVoiceName(FrenchVoice voice) const;
    void processAudioResponse(const QByteArray& audioData);
    
    // Configuration Azure
    QString m_azureApiKey;
    QString m_azureRegion;
    QString m_azureEndpoint;
    bool m_isConfigured;
    
    // Paramètres vocaux
    QString m_currentVoice;
    double m_speechRate;     // 0.5 à 2.0
    double m_volume;         // 0.0 à 1.0
    QString m_currentEmotion;
    
    // Networking
    QNetworkAccessManager* m_networkManager;
    QNetworkReply* m_currentReply;
    
    // Lecture audio
    QMediaPlayer* m_mediaPlayer;
    QAudioOutput* m_audioOutput;
    QTemporaryFile* m_currentAudioFile;
    
    // État
    bool m_isSpeaking;
    bool m_isPaused;
    
    // Cache audio pour phrases courantes
    QHash<QString, QString> m_audioCache;
    
    static const QString AZURE_TTS_ENDPOINT;
    static const QStringList SUPPORTED_EMOTIONS;
};