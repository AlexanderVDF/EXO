#ifndef VOICEMANAGER_H
#define VOICEMANAGER_H

#include <QObject>
#include <QAudioInput>
#include <QAudioFormat>
#include <QAudioDevice>
#include <QMediaDevices>
#include <QIODevice>
#include <QTimer>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QBuffer>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QAudioOutput>
#include <QAudioSink>
#include <QAudioSource>
#include <QTextToSpeech>
#include <memory>

class VoiceManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isListening READ isListening NOTIFY listeningChanged)
    Q_PROPERTY(bool isSpeaking READ isSpeaking NOTIFY speakingChanged)
    Q_PROPERTY(QString lastCommand READ lastCommand NOTIFY commandDetected)

public:
    explicit VoiceManager(QObject *parent = nullptr);
    ~VoiceManager();

    // Propriétés
    bool isListening() const { return m_isListening; }
    bool isSpeaking() const { return m_isSpeaking; }
    QString lastCommand() const { return m_lastCommand; }

    // Méthodes publiques
    Q_INVOKABLE void startListening();
    Q_INVOKABLE void stopListening();
    Q_INVOKABLE void speak(const QString &text);
    Q_INVOKABLE void setWakeWord(const QString &word) { m_wakeWord = word; }

signals:
    void listeningChanged();
    void speakingChanged();
    void commandDetected(const QString &command);
    void wakeWordDetected();
    void statusChanged(const QString &status);
    void voiceError(const QString &error);

private slots:
    void processAudioData();
    void handleSpeechResult();
    void onTtsFinished();

private:
    // Configuration audio
    void setupAudio();
    void setupSpeechRecognition();
    void setupTextToSpeech();
    
    // Traitement audio
    void processWakeWordDetection(const QByteArray &audioData);
    void sendAudioToSpeechAPI(const QByteArray &audioData);
    
    // TTS
    void requestTTS(const QString &text);
    
    // Membres privés
    bool m_isListening;
    bool m_isSpeaking;
    bool m_wakeWordActive;
    QString m_lastCommand;
    QString m_wakeWord;
    
    // Audio
    std::unique_ptr<QAudioSource> m_audioSource;
    std::unique_ptr<QAudioSink> m_audioSink;
    QAudioFormat m_audioFormat;
    QIODevice *m_audioInputDevice;
    QBuffer *m_audioBuffer;
    
    // Réseau
    QNetworkAccessManager *m_networkManager;
    
    // Synthèse vocale
    QTextToSpeech *m_tts;
    
    // Timers
    QTimer *m_recordingTimer;
    QTimer *m_silenceTimer;
    
    // Configuration
    static constexpr int SAMPLE_RATE = 16000;
    static constexpr int WAKE_WORD_THRESHOLD = 1500; // ms de silence après mot d'activation
    static constexpr int MAX_RECORDING_TIME = 8000; // 8 secondes max pour phrase complète
    static constexpr int AUDIO_LEVEL_THRESHOLD = 1000; // Seuil de détection audio
};

#endif // VOICEMANAGER_H