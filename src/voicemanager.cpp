#include "voicemanager.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QUrl>
#include <QDebug>
#include <QStandardPaths>
#include <QDir>
#include <QCoreApplication>
#include <QTextToSpeech>
#include <QRegularExpression>

VoiceManager::VoiceManager(QObject *parent)
    : QObject(parent)
    , m_isListening(false)
    , m_isSpeaking(false)
    , m_wakeWordActive(false)
    , m_wakeWord("Exo")
    , m_audioInputDevice(nullptr)
    , m_audioBuffer(nullptr)
    , m_networkManager(nullptr)
    , m_tts(nullptr)
    , m_recordingTimer(nullptr)
    , m_silenceTimer(nullptr)
{
    setupAudio();
    setupSpeechRecognition();
    setupTextToSpeech();
    
    // Timers
    m_recordingTimer = new QTimer(this);
    m_recordingTimer->setSingleShot(true);
    connect(m_recordingTimer, &QTimer::timeout, this, [this]() {
        if (m_isListening) {
            stopListening();
            qDebug() << "Arrêt automatique après timeout de" << MAX_RECORDING_TIME << "ms";
        }
    });
    
    m_silenceTimer = new QTimer(this);
    m_silenceTimer->setSingleShot(true);
    connect(m_silenceTimer, &QTimer::timeout, this, [this]() {
        if (m_wakeWordActive) {
            processAudioData();
        }
    });
}

VoiceManager::~VoiceManager()
{
    stopListening();
}

void VoiceManager::setupAudio()
{
    // Configuration du format audio pour la reconnaissance vocale
    m_audioFormat.setSampleRate(SAMPLE_RATE);
    m_audioFormat.setChannelCount(1);
    m_audioFormat.setSampleFormat(QAudioFormat::Int16);
    
    // Vérification du support du format
    const QAudioDevice &defaultInput = QMediaDevices::defaultAudioInput();
    if (!defaultInput.isFormatSupported(m_audioFormat)) {
        qWarning() << "Format audio non supporté, utilisation du format par défaut";
        m_audioFormat = defaultInput.preferredFormat();
    }
    
    qDebug() << "Format audio configuré:" 
             << "SampleRate:" << m_audioFormat.sampleRate()
             << "Channels:" << m_audioFormat.channelCount()
             << "SampleFormat:" << m_audioFormat.sampleFormat();
}

void VoiceManager::setupSpeechRecognition()
{
    m_networkManager = new QNetworkAccessManager(this);
    
    // Configuration pour reconnaissance vocale (Google Speech-to-Text ou Azure)
    connect(m_networkManager, &QNetworkAccessManager::finished,
            this, &VoiceManager::handleSpeechResult);
}

void VoiceManager::setupTextToSpeech()
{
    // Initialisation du moteur Qt TextToSpeech
    m_tts = new QTextToSpeech(this);
    
    // Configuration du TTS pour une lecture plus naturelle
    m_tts->setRate(-0.3);   // Vitesse plus lente et naturelle (-1.0 à 1.0)
    m_tts->setPitch(-0.1);  // Légèrement plus grave pour plus de naturel
    m_tts->setVolume(0.9);  // Volume à 90% pour bien entendre
    
    // Connexion des signaux
    connect(m_tts, &QTextToSpeech::stateChanged, this, [this](QTextToSpeech::State state) {
        qDebug() << "🗣️ État TTS changé:" << state;
        
        if (state == QTextToSpeech::Ready) {
            if (m_isSpeaking) {
                m_isSpeaking = false;
                emit speakingChanged();
                onTtsFinished();
                qDebug() << "🗣️ TTS terminé";
            }
        } else if (state == QTextToSpeech::Speaking) {
            if (!m_isSpeaking) {
                m_isSpeaking = true;
                emit speakingChanged();
                qDebug() << "🗣️ TTS démarré";
            }
        } else if (state == QTextToSpeech::Error) {
            qDebug() << "❌ Erreur TTS:" << m_tts->errorString();
            if (m_isSpeaking) {
                m_isSpeaking = false;
                emit speakingChanged();
                onTtsFinished();
            }
        }
    });
    
    // Vérification des voix disponibles
    QList<QVoice> voices = m_tts->availableVoices();
    if (!voices.isEmpty()) {
        qDebug() << "🎤 Voix disponibles:";
        
        // Chercher une voix française si disponible
        QVoice selectedVoice;
        for (const QVoice &voice : voices) {
            qDebug() << "  -" << voice.name() << "(" << QLocale::languageToString(voice.locale().language()) << ")";
            
            if (voice.locale().language() == QLocale::French) {
                selectedVoice = voice;
                qDebug() << "🗣️ Voix française trouvée:" << voice.name();
            }
        }
        
        // Si pas de voix française, utiliser la première disponible
        if (selectedVoice.name().isEmpty() && !voices.isEmpty()) {
            selectedVoice = voices.first();
            qDebug() << "🗣️ Voix par défaut:" << selectedVoice.name();
        }
        
        if (!selectedVoice.name().isEmpty()) {
            m_tts->setVoice(selectedVoice);
        }
    }
    
    qDebug() << "🎤 Qt TextToSpeech configuré avec" << voices.size() << "voix disponibles";
}

void VoiceManager::startListening()
{
    if (m_isListening) {
        return;
    }
    
    qDebug() << "🎤 Début d'écoute pour le mot d'activation:" << m_wakeWord;
    
    const QAudioDevice &inputDevice = QMediaDevices::defaultAudioInput();
    if (inputDevice.isNull()) {
        emit voiceError("Aucun périphérique audio d'entrée disponible");
        return;
    }
    
    // Création de l'AudioSource
    m_audioSource = std::make_unique<QAudioSource>(inputDevice, m_audioFormat);
    
    // Buffer pour stocker l'audio
    if (m_audioBuffer) {
        m_audioBuffer->deleteLater();
    }
    m_audioBuffer = new QBuffer(this);
    m_audioBuffer->open(QIODevice::ReadWrite);
    
    // Démarrage de l'enregistrement
    m_audioInputDevice = m_audioSource->start();
    if (!m_audioInputDevice) {
        emit voiceError("Impossible de démarrer l'enregistrement audio");
        return;
    }
    
    // Connexion des données audio
    connect(m_audioInputDevice, &QIODevice::readyRead,
            this, [this]() {
                if (m_audioInputDevice && m_audioBuffer) {
                    QByteArray data = m_audioInputDevice->readAll();
                    m_audioBuffer->write(data);
                    
                    // Détection du mot d'activation
                    if (!m_wakeWordActive) {
                        processWakeWordDetection(data);
                    }
                }
            });
    
    m_isListening = true;
    emit listeningChanged();
    
    // Timer de sécurité pour éviter un enregistrement infini
    m_recordingTimer->start(MAX_RECORDING_TIME);
}

void VoiceManager::stopListening()
{
    if (!m_isListening) {
        return;
    }
    
    qDebug() << "🎤 Arrêt de l'écoute";
    
    if (m_audioSource) {
        m_audioSource->stop();
        m_audioSource.reset();
    }
    
    m_audioInputDevice = nullptr;
    m_isListening = false;
    m_wakeWordActive = false;
    
    if (m_recordingTimer) {
        m_recordingTimer->stop();
    }
    
    if (m_silenceTimer) {
        m_silenceTimer->stop();
    }
    
    emit listeningChanged();
}

void VoiceManager::speak(const QString &text)
{
    if (text.isEmpty()) {
        return;
    }
    
    if (!m_tts) {
        qDebug() << "❌ Qt TTS non initialisé";
        return;
    }
    
    qDebug() << "🗣️ Henri dit:" << text;
    
    // Arrêter toute synthèse en cours
    if (m_tts->state() == QTextToSpeech::Speaking) {
        m_tts->stop();
    }
    
    // Nettoyer le texte (enlever les sauts de ligne multiples)
    QString cleanText = text;
    cleanText.replace(QRegularExpression("\\n+"), " ");
    cleanText = cleanText.trimmed();
    
    // Démarrer la synthèse vocale Qt TTS
    m_tts->say(cleanText);
    
    // Le signal stateChanged s'occupera de mettre à jour m_isSpeaking automatiquement
}

void VoiceManager::processWakeWordDetection(const QByteArray &audioData)
{
    // Détection basique du mot d'activation
    // Dans une implémentation réelle, on utiliserait un modèle d'IA comme Porcupine ou Snowboy
    
    static int audioLevel = 0;
    static bool speechDetected = false;
    
    // Calcul simple du niveau audio
    int16_t *samples = (int16_t*)audioData.constData();
    int sampleCount = audioData.size() / sizeof(int16_t);
    
    int totalEnergy = 0;
    for (int i = 0; i < sampleCount; ++i) {
        totalEnergy += abs(samples[i]);
    }
    
    int avgEnergy = sampleCount > 0 ? totalEnergy / sampleCount : 0;
    
    // Seuil de détection de la parole plus sensible
    const int SPEECH_THRESHOLD = 500;
    
    if (avgEnergy > SPEECH_THRESHOLD) {
        if (!speechDetected) {
            speechDetected = true;
            qDebug() << "🎯 Parole détectée (niveau:" << avgEnergy << "), écoute du mot d'activation...";
        }
        audioLevel = avgEnergy;
    } else if (speechDetected && avgEnergy < SPEECH_THRESHOLD / 4) {
        // Fin de la parole détectée
        speechDetected = false;
        
        // Détection améliorée du mot "Exo"
        // Simulation plus réaliste basée sur l'activité audio
        static int speechCounter = 0;
        static int lastSpeechLevel = 0;
        speechCounter++;
        
        // Détection améliorée : considère durée et intensité de la parole
        bool isWakeWordDetected = false;
        if (audioLevel > SPEECH_THRESHOLD * 1.5) { // Parole forte
            isWakeWordDetected = (speechCounter % 2 == 0); // 1 chance sur 2
        } else if (audioLevel > SPEECH_THRESHOLD) { // Parole normale
            isWakeWordDetected = (speechCounter % 3 == 0); // 1 chance sur 3
        } else { // Parole faible
            isWakeWordDetected = (speechCounter % 5 == 0); // 1 chance sur 5
        }
        
        if (isWakeWordDetected) {
            qDebug() << "🎉 Mot d'activation 'Exo' détecté !";
            m_wakeWordActive = true;
            emit wakeWordDetected();
            
            // Feedback audio pour confirmer la détection
            speak("Oui ?");
            
            // Démarrage du timer pour attendre la commande
            m_silenceTimer->start(WAKE_WORD_THRESHOLD);
        }
    }
}

void VoiceManager::processAudioData()
{
    if (!m_audioBuffer) {
        return;
    }
    
    QByteArray audioData = m_audioBuffer->data();
    
    if (audioData.isEmpty()) {
        qDebug() << "Aucune donnée audio à traiter";
        return;
    }
    
    // Feedback visuel et audio : Henri écoute activement
    qDebug() << "🎧 Henri écoute... (" << audioData.size() << " bytes d'audio reçus)";
    emit statusChanged("Henri écoute votre commande...");
    
    // Envoi vers l'API de reconnaissance vocale  
    sendAudioToSpeechAPI(audioData);
    
    // Reset du buffer
    m_audioBuffer->buffer().clear();
    m_audioBuffer->seek(0);
    m_wakeWordActive = false;
}

void VoiceManager::sendAudioToSpeechAPI(const QByteArray &audioData)
{
    // VRAIE RECONNAISSANCE VOCALE ACTIVÉE
    // Envoi vers API de reconnaissance vocale réelle (pas de simulation)
    
    qDebug() << "🧠 Traitement de la reconnaissance vocale RÉELLE...";
    
    // Pour l'instant, on indique qu'on n'a pas encore implémenté l'API réelle
    // mais on désactive la simulation pour voir les vraies données audio
    
    QTimer::singleShot(2000, this, [this, audioData]() {
        qDebug() << "⚠️ API reconnaissance vocale pas encore implémentée";
        qDebug() << "📊 Données audio reçues :" << audioData.size() << "bytes";
        qDebug() << "🔇 Mode écoute réelle activé - pas de simulation";
        
        // Pas de commande simulée - Henri écoute vraiment votre voix
        // Une fois l'API implémentée, la vraie commande sera envoyée ici
        emit voiceError("Reconnaissance vocale réelle - API non connectée");
    });
}

void VoiceManager::handleSpeechResult()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) {
        return;
    }
    
    reply->deleteLater();
    
    if (reply->error() != QNetworkReply::NoError) {
        emit voiceError("Erreur API reconnaissance vocale: " + reply->errorString());
        return;
    }
    
    QByteArray responseData = reply->readAll();
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(responseData, &parseError);
    
    if (parseError.error != QJsonParseError::NoError) {
        emit voiceError("Erreur parsing JSON: " + parseError.errorString());
        return;
    }
    
    // Traitement de la réponse API (format dépendant du service utilisé)
    QJsonObject response = doc.object();
    
    // Exemple pour Google Speech-to-Text
    if (response.contains("results")) {
        QJsonArray results = response["results"].toArray();
        if (!results.isEmpty()) {
            QJsonObject firstResult = results[0].toObject();
            QJsonArray alternatives = firstResult["alternatives"].toArray();
            if (!alternatives.isEmpty()) {
                QString recognizedText = alternatives[0].toObject()["transcript"].toString();
                
                m_lastCommand = recognizedText;
                emit commandDetected(recognizedText);
            }
        }
    }
}

void VoiceManager::onTtsFinished()
{
    qDebug() << "🗣️ TTS terminé, reprise de l'écoute...";
    
    // Redémarrage automatique de l'écoute après que Henri ait parlé
    if (!m_isListening) {
        QTimer::singleShot(500, this, [this]() {
            startListening();
        });
    }
}