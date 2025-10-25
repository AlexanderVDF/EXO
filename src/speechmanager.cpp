#include "speechmanager.h"
#include <QDebug>
#include <QStandardPaths>
#include <QDir>
#include <QCoreApplication>

SpeechManager::SpeechManager(QObject *parent)
    : QObject(parent)
    , m_speechProcess(nullptr)
    , m_isListening(false)
    , m_isSpeaking(false)
    , m_volume(0.7)
    , m_isMuted(false)
{
    // Initialisation du processus de reconnaissance vocale
    m_speechProcess = new QProcess(this);
    
    // Connexion des signaux du processus
    connect(m_speechProcess, &QProcess::readyReadStandardOutput, this, &SpeechManager::processSpeechOutput);
    connect(m_speechProcess, &QProcess::finished, this, &SpeechManager::onProcessFinished);
    
    // Timer pour timeout de reconnaissance
    m_listenTimer = new QTimer(this);
    m_listenTimer->setSingleShot(true);
    connect(m_listenTimer, &QTimer::timeout, this, &SpeechManager::stopListening);
    
    qDebug() << "SpeechManager initialisé";
}

SpeechManager::~SpeechManager()
{
    stopListening();
    stopSpeaking();
}

void SpeechManager::setVolume(double volume)
{
    if (qAbs(m_volume - volume) > 0.01) {
        m_volume = qBound(0.0, volume, 1.0);
        emit volumeChanged();
        qDebug() << "Volume vocal ajusté à:" << m_volume;
    }
}

void SpeechManager::startListening(int timeoutMs)
{
    if (m_isListening) {
        qDebug() << "Écoute déjà en cours";
        return;
    }
    
    if (m_isSpeaking) {
        qDebug() << "Arrêt de la synthèse avant écoute";
        stopSpeaking();
    }
    
    m_isListening = true;
    emit listeningStateChanged();
    emit listeningStarted();
    
    // Démarrage du processus Python de reconnaissance
    QString pythonScript = QDir(QCoreApplication::applicationDirPath()).filePath("python/speech_manager.py");
    QStringList arguments;
    arguments << "--listen" << "--timeout" << QString::number(timeoutMs / 1000);
    
    m_speechProcess->start("python", arguments << pythonScript);
    
    if (timeoutMs > 0) {
        m_listenTimer->start(timeoutMs);
    }
    
    qDebug() << "Écoute vocale démarrée (timeout:" << timeoutMs << "ms)";
}

void SpeechManager::stopListening()
{
    if (!m_isListening) {
        return;
    }
    
    m_listenTimer->stop();
    
    if (m_speechProcess->state() == QProcess::Running) {
        m_speechProcess->terminate();
        if (!m_speechProcess->waitForFinished(3000)) {
            m_speechProcess->kill();
        }
    }
    
    m_isListening = false;
    emit listeningStateChanged();
    emit listeningStopped();
    
    qDebug() << "Écoute vocale arrêtée";
}

void SpeechManager::speak(const QString& text, const QString& voice)
{
    if (text.isEmpty()) {
        return;
    }
    
    if (m_isListening) {
        qDebug() << "Arrêt de l'écoute avant synthèse";
        stopListening();
    }
    
    m_isSpeaking = true;
    emit speakingStateChanged();
    emit speakingStarted(text);
    
    // Démarrage du processus Python de synthèse vocale
    QString pythonScript = QDir(QCoreApplication::applicationDirPath()).filePath("python/speech_manager.py");
    QStringList arguments;
    arguments << "--speak" << text;
    arguments << "--voice" << (voice.isEmpty() ? "henri" : voice);
    arguments << "--volume" << QString::number(m_volume);
    
    if (m_isMuted) {
        arguments << "--muted";
    }
    
    // Processus séparé pour la synthèse
    QProcess* speakProcess = new QProcess(this);
    connect(speakProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &SpeechManager::onSpeakProcessFinished);
    
    speakProcess->start("python", arguments << pythonScript);
    
    qDebug() << "Synthèse vocale démarrée:" << text.left(50) + "...";
}

void SpeechManager::stopSpeaking()
{
    if (!m_isSpeaking) {
        return;
    }
    
    // Arrêt de tous les processus de synthèse
    QList<QProcess*> speakProcesses = findChildren<QProcess*>();
    for (QProcess* process : speakProcesses) {
        if (process != m_speechProcess && process->state() == QProcess::Running) {
            process->terminate();
            if (!process->waitForFinished(2000)) {
                process->kill();
            }
        }
    }
    
    m_isSpeaking = false;
    emit speakingStateChanged();
    emit speakingStopped();
    
    qDebug() << "Synthèse vocale arrêtée";
}

void SpeechManager::setMuted(bool muted)
{
    if (m_isMuted != muted) {
        m_isMuted = muted;
        emit mutedStateChanged();
        
        if (muted && m_isSpeaking) {
            stopSpeaking();
        }
        
        qDebug() << "Audio" << (muted ? "coupé" : "activé");
    }
}

void SpeechManager::calibrateMicrophone()
{
    qDebug() << "Calibrage microphone...";
    
    QString pythonScript = QDir(QCoreApplication::applicationDirPath()).filePath("python/speech_manager.py");
    QStringList arguments;
    arguments << "--calibrate";
    
    QProcess* calibProcess = new QProcess(this);
    connect(calibProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            [this, calibProcess](int exitCode) {
                calibProcess->deleteLater();
                emit microphoneCalibrated(exitCode == 0);
                qDebug() << "Calibrage microphone terminé (succès:" << (exitCode == 0) << ")";
            });
    
    calibProcess->start("python", arguments << pythonScript);
}

void SpeechManager::testAudio()
{
    qDebug() << "Test audio...";
    speak("Test audio : un, deux, trois. Microphone et haut-parleurs fonctionnels.", "henri");
}

void SpeechManager::processSpeechOutput()
{
    if (!m_speechProcess) {
        return;
    }
    
    QByteArray data = m_speechProcess->readAllStandardOutput();
    QString output = QString::fromUtf8(data).trimmed();
    
    if (output.isEmpty()) {
        return;
    }
    
    // Analyse de la sortie du processus Python
    if (output.startsWith("SPEECH:")) {
        QString recognizedText = output.mid(7).trimmed();
        emit speechRecognized(recognizedText);
        qDebug() << "Parole reconnue:" << recognizedText;
        
    } else if (output.startsWith("ERROR:")) {
        QString error = output.mid(6).trimmed();
        emit errorOccurred(error);
        qDebug() << "Erreur vocale:" << error;
        
    } else if (output.startsWith("STATUS:")) {
        QString status = output.mid(7).trimmed();
        qDebug() << "Statut vocal:" << status;
    }
}

void SpeechManager::onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    Q_UNUSED(exitCode)
    Q_UNUSED(exitStatus)
    
    if (m_isListening) {
        m_isListening = false;
        emit listeningStateChanged();
        emit listeningStopped();
        qDebug() << "Processus d'écoute terminé";
    }
}

void SpeechManager::onSpeakProcessFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    Q_UNUSED(exitCode)
    Q_UNUSED(exitStatus)
    
    QProcess* speakProcess = qobject_cast<QProcess*>(sender());
    if (speakProcess) {
        speakProcess->deleteLater();
    }
    
    // Vérifier s'il reste des processus de synthèse
    QList<QProcess*> speakProcesses = findChildren<QProcess*>();
    bool hasRunningSpeakProcess = false;
    
    for (QProcess* process : speakProcesses) {
        if (process != m_speechProcess && process->state() == QProcess::Running) {
            hasRunningSpeakProcess = true;
            break;
        }
    }
    
    if (!hasRunningSpeakProcess && m_isSpeaking) {
        m_isSpeaking = false;
        emit speakingStateChanged();
        emit speakingStopped();
        qDebug() << "Synthèse vocale terminée";
    }
}