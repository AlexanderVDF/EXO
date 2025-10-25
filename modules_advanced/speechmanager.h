#pragma once

#include <QObject>
#include <QProcess>
#include <QTimer>

/**
 * @brief Gestionnaire de reconnaissance et synthèse vocale
 * 
 * Interface entre Qt et les services vocaux Python.
 * Optimisé pour fonctionnement tactile et vocal sur Raspberry Pi.
 */
class SpeechManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isListening READ isListening NOTIFY listeningStateChanged)
    Q_PROPERTY(bool isSpeaking READ isSpeaking NOTIFY speakingStateChanged)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool isMuted READ isMuted NOTIFY mutedStateChanged)

public:
    explicit SpeechManager(QObject *parent = nullptr);
    ~SpeechManager();

    // Propriétés
    bool isListening() const { return m_isListening; }
    bool isSpeaking() const { return m_isSpeaking; }
    double volume() const { return m_volume; }
    bool isMuted() const { return m_isMuted; }

public slots:
    void startListening();
    void stopListening();
    void speakText(const QString& text);
    void stopSpeaking();
    void setVolume(double volume);
    void toggleMute();
    void calibrateMicrophone();

signals:
    void voiceInputReceived(const QString& text);
    void listeningStateChanged(bool listening);
    void speakingStateChanged(bool speaking);
    void volumeChanged(double volume);
    void mutedStateChanged(bool muted);
    void errorOccurred(const QString& error);
    void audioLevelChanged(double level);

private slots:
    void handleSpeechProcessOutput();
    void handleSpeechProcessError();
    void updateAudioLevel();

private:
    void initializeSpeechServices();
    void startSpeechRecognition();
    void stopSpeechRecognition();
    void startTextToSpeech(const QString& text);
    
    QProcess* m_speechProcess;
    QTimer* m_audioLevelTimer;
    
    bool m_isListening;
    bool m_isSpeaking;
    double m_volume;
    bool m_isMuted;
    double m_currentAudioLevel;
    
    QString m_speechServicePath;
};