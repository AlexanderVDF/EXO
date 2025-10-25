#include "microsofttts.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QHttpMultiPart>
#include <QDebug>
#include <QStandardPaths>
#include <QDir>

// Endpoint Azure TTS
const QString MicrosoftTTSManager::AZURE_TTS_ENDPOINT = "https://%1.tts.speech.microsoft.com/cognitiveservices/v1";

// Émotions supportées par Azure TTS
const QStringList MicrosoftTTSManager::SUPPORTED_EMOTIONS = {
    "neutral", "cheerful", "sad", "angry", "fearful", "disgruntled", 
    "serious", "affectionate", "gentle", "lyrical"
};

MicrosoftTTSManager::MicrosoftTTSManager(QObject *parent)
    : QObject(parent)
    , m_isConfigured(false)
    , m_currentVoice("fr-FR-HenriNeural")  // Voix Henri par défaut
    , m_speechRate(1.0)
    , m_volume(0.8)
    , m_currentEmotion("neutral")
    , m_networkManager(new QNetworkAccessManager(this))
    , m_currentReply(nullptr)
    , m_mediaPlayer(new QMediaPlayer(this))
    , m_audioOutput(new QAudioOutput(this))
    , m_currentAudioFile(nullptr)
    , m_isSpeaking(false)
    , m_isPaused(false)
{
    setupAudioSystem();
    
    // Configuration du cache audio
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/tts";
    QDir().mkpath(cacheDir);
    
    qDebug() << "Microsoft TTS Manager initialisé avec voix Henri";
}

MicrosoftTTSManager::~MicrosoftTTSManager()
{
    if (m_currentReply) {
        m_currentReply->abort();
    }
    
    if (m_currentAudioFile) {
        delete m_currentAudioFile;
    }
}

void MicrosoftTTSManager::setupAudioSystem()
{
    // Configuration audio haute qualité
    m_audioOutput->setVolume(m_volume);
    m_mediaPlayer->setAudioOutput(m_audioOutput);
    
    // Connexions pour le suivi d'état
    connect(m_mediaPlayer, &QMediaPlayer::playbackStateChanged,
            this, &MicrosoftTTSManager::handleMediaPlayerStateChanged);
    
    connect(m_mediaPlayer, &QMediaPlayer::errorOccurred,
            this, &MicrosoftTTSManager::handleMediaPlayerError);
    
    qDebug() << "Système audio configuré";
}

void MicrosoftTTSManager::setAzureApiKey(const QString& apiKey)
{
    m_azureApiKey = apiKey;
    updateConfiguration();
}

void MicrosoftTTSManager::setAzureRegion(const QString& region)
{
    m_azureRegion = region;
    m_azureEndpoint = AZURE_TTS_ENDPOINT.arg(region);
    updateConfiguration();
}

void MicrosoftTTSManager::updateConfiguration()
{
    bool wasConfigured = m_isConfigured;
    m_isConfigured = !m_azureApiKey.isEmpty() && !m_azureRegion.isEmpty();
    
    if (wasConfigured != m_isConfigured) {
        emit configurationChanged(m_isConfigured);
        
        if (m_isConfigured) {
            qDebug() << "Microsoft TTS configuré pour la région:" << m_azureRegion;
        } else {
            qDebug() << "Microsoft TTS non configuré - vérifiez API key et région";
        }
    }
}

QString MicrosoftTTSManager::createSSMLRequest(const QString& text, const QString& emotion) const
{
    QString ssml = QString(
        "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' "
        "xmlns:mstts='https://www.w3.org/2001/mstts' xml:lang='fr-FR'>"
        "<voice name='%1'>"
        "<mstts:express-as style='%2'>"
        "<prosody rate='%3' volume='%4'>%5</prosody>"
        "</mstts:express-as>"
        "</voice>"
        "</speak>"
    ).arg(m_currentVoice)
     .arg(emotion.isEmpty() ? m_currentEmotion : emotion)
     .arg(QString::number(m_speechRate, 'f', 1))
     .arg(QString::number(m_volume * 100, 'f', 0) + "%")
     .arg(text.toHtmlEscaped());
    
    return ssml;
}

void MicrosoftTTSManager::speakText(const QString& text)
{
    speakTextWithEmotion(text, QString());
}

void MicrosoftTTSManager::speakTextWithEmotion(const QString& text, const QString& emotion)
{
    if (!m_isConfigured) {
        emit configurationError("Microsoft TTS non configuré");
        return;
    }
    
    if (text.trimmed().isEmpty()) {
        return;
    }
    
    // Vérifier le cache d'abord
    QString cacheKey = QString("%1_%2_%3_%4").arg(text, m_currentVoice, 
                                                  QString::number(m_speechRate),
                                                  emotion.isEmpty() ? m_currentEmotion : emotion);
    
    if (m_audioCache.contains(cacheKey)) {
        qDebug() << "Utilisation du cache TTS pour:" << text.left(30) + "...";
        playAudioFile(m_audioCache[cacheKey]);
        return;
    }
    
    // Arrêter la lecture en cours
    if (m_isSpeaking) {
        stopSpeaking();
    }
    
    qDebug() << "Synthèse TTS Microsoft:" << text.left(50) + "...";
    
    // Préparation de la requête HTTP
    QNetworkRequest request(QUrl(m_azureEndpoint));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/ssml+xml");
    request.setRawHeader("Ocp-Apim-Subscription-Key", m_azureApiKey.toUtf8());
    request.setRawHeader("User-Agent", "RaspberryAssistant/1.0");
    request.setRawHeader("X-Microsoft-OutputFormat", "audio-24khz-96kbitrate-mono-mp3");
    
    // Créer le SSML
    QString ssmlContent = createSSMLRequest(text, emotion);
    
    // Envoyer la requête
    m_currentReply = m_networkManager->post(request, ssmlContent.toUtf8());
    
    connect(m_currentReply, &QNetworkReply::finished,
            this, &MicrosoftTTSManager::handleNetworkReply);
    
    emit speechStarted();
}

void MicrosoftTTSManager::handleNetworkReply()
{
    if (!m_currentReply) {
        return;
    }
    
    if (m_currentReply->error() == QNetworkReply::NoError) {
        QByteArray audioData = m_currentReply->readAll();
        
        if (!audioData.isEmpty()) {
            processAudioResponse(audioData);
        } else {
            emit speechError("Réponse audio vide de Microsoft TTS");
        }
    } else {
        QString errorMsg = QString("Erreur Microsoft TTS: %1").arg(m_currentReply->errorString());
        qDebug() << errorMsg;
        emit speechError(errorMsg);
    }
    
    m_currentReply->deleteLater();
    m_currentReply = nullptr;
}

void MicrosoftTTSManager::processAudioResponse(const QByteArray& audioData)
{
    // Créer un fichier temporaire pour l'audio
    if (m_currentAudioFile) {
        delete m_currentAudioFile;
    }
    
    m_currentAudioFile = new QTemporaryFile(this);
    m_currentAudioFile->setFileTemplate("tts_XXXXXX.mp3");
    
    if (m_currentAudioFile->open()) {
        m_currentAudioFile->write(audioData);
        m_currentAudioFile->close();
        
        QString audioFilePath = m_currentAudioFile->fileName();
        
        // Jouer l'audio
        playAudioFile(audioFilePath);
        
        // Ajouter au cache (optionnel, selon la taille)
        // m_audioCache[cacheKey] = audioFilePath;
        
    } else {
        emit speechError("Impossible de créer le fichier audio temporaire");
    }
}

void MicrosoftTTSManager::playAudioFile(const QString& filePath)
{
    m_mediaPlayer->setSource(QUrl::fromLocalFile(filePath));
    m_mediaPlayer->play();
    
    m_isSpeaking = true;
    m_isPaused = false;
    emit speakingStateChanged(true);
}

void MicrosoftTTSManager::stopSpeaking()
{
    if (m_mediaPlayer->playbackState() != QMediaPlayer::StoppedState) {
        m_mediaPlayer->stop();
    }
    
    if (m_currentReply) {
        m_currentReply->abort();
    }
    
    m_isSpeaking = false;
    m_isPaused = false;
    emit speakingStateChanged(false);
}

void MicrosoftTTSManager::pauseSpeaking()
{
    if (m_mediaPlayer->playbackState() == QMediaPlayer::PlayingState) {
        m_mediaPlayer->pause();
        m_isPaused = true;
    }
}

void MicrosoftTTSManager::resumeSpeaking()
{
    if (m_isPaused && m_mediaPlayer->playbackState() == QMediaPlayer::PausedState) {
        m_mediaPlayer->play();
        m_isPaused = false;
    }
}

void MicrosoftTTSManager::setSpeechRate(double rate)
{
    rate = qBound(0.5, rate, 2.0);  // Limiter entre 0.5x et 2x
    
    if (qAbs(m_speechRate - rate) > 0.01) {
        m_speechRate = rate;
        emit speechRateChanged(rate);
        qDebug() << "Vitesse de parole changée à:" << rate;
    }
}

void MicrosoftTTSManager::setVolume(double volume)
{
    volume = qBound(0.0, volume, 1.0);
    
    if (qAbs(m_volume - volume) > 0.01) {
        m_volume = volume;
        m_audioOutput->setVolume(volume);
        emit volumeChanged(volume);
        qDebug() << "Volume TTS changé à:" << volume;
    }
}

void MicrosoftTTSManager::setVoice(const QString& voiceName)
{
    if (m_currentVoice != voiceName) {
        m_currentVoice = voiceName;
        emit voiceChanged(voiceName);
        qDebug() << "Voix TTS changée à:" << voiceName;
    }
}

void MicrosoftTTSManager::setVoice(FrenchVoice voice)
{
    setVoice(getVoiceName(voice));
}

QString MicrosoftTTSManager::getVoiceName(FrenchVoice voice) const
{
    switch (voice) {
    case Henri:  return "fr-FR-HenriNeural";
    case Denise: return "fr-FR-DeniseNeural"; 
    case Alain:  return "fr-CA-AlainNeural";
    case Marie:  return "fr-CA-MarieNeural";
    default:     return "fr-FR-HenriNeural";
    }
}

QStringList MicrosoftTTSManager::getAvailableVoices() const
{
    return QStringList{
        "fr-FR-HenriNeural (Henri - Français)",
        "fr-FR-DeniseNeural (Denise - Française)",
        "fr-CA-AlainNeural (Alain - Québécois)", 
        "fr-CA-MarieNeural (Marie - Québécoise)"
    };
}

void MicrosoftTTSManager::testConfiguration()
{
    if (!m_isConfigured) {
        emit configurationError("Configuration incomplète");
        return;
    }
    
    speakTextWithEmotion("Bonjour ! Je suis Henri, votre assistant vocal. Ma configuration fonctionne parfaitement.", "cheerful");
}

void MicrosoftTTSManager::handleMediaPlayerStateChanged(QMediaPlayer::PlaybackState state)
{
    switch (state) {
    case QMediaPlayer::PlayingState:
        if (!m_isSpeaking) {
            m_isSpeaking = true;
            emit speakingStateChanged(true);
        }
        break;
        
    case QMediaPlayer::StoppedState:
        if (m_isSpeaking) {
            m_isSpeaking = false;
            emit speakingStateChanged(false);
            emit speechFinished();
        }
        break;
        
    case QMediaPlayer::PausedState:
        // État géré par pauseSpeaking()
        break;
    }
}

void MicrosoftTTSManager::handleMediaPlayerError(QMediaPlayer::Error error)
{
    QString errorMsg = QString("Erreur lecture audio: %1").arg(m_mediaPlayer->errorString());
    qDebug() << errorMsg;
    
    m_isSpeaking = false;
    emit speakingStateChanged(false);
    emit speechError(errorMsg);
}