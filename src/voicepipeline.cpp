#include "voicepipeline.h"
#include "logmanager.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QDataStream>
#include <QtEndian>
#include <cstring>
#include <algorithm>
#include <numeric>

// ═══════════════════════════════════════════════════════
//  CircularAudioBuffer
// ═══════════════════════════════════════════════════════

CircularAudioBuffer::CircularAudioBuffer(size_t cap)
    : m_buf(cap, 0)
{}

void CircularAudioBuffer::write(const int16_t *data, size_t count)
{
    QMutexLocker lk(&m_mutex);
    for (size_t i = 0; i < count; ++i) {
        m_buf[m_head] = data[i];
        m_head = (m_head + 1) % m_buf.size();
        if (m_count < m_buf.size())
            ++m_count;
        else
            m_tail = (m_tail + 1) % m_buf.size(); // overwrite oldest
    }
}

size_t CircularAudioBuffer::read(int16_t *dest, size_t count)
{
    QMutexLocker lk(&m_mutex);
    size_t n = std::min(count, m_count);
    for (size_t i = 0; i < n; ++i) {
        dest[i] = m_buf[m_tail];
        m_tail = (m_tail + 1) % m_buf.size();
    }
    m_count -= n;
    return n;
}

size_t CircularAudioBuffer::peek(int16_t *dest, size_t count) const
{
    QMutexLocker lk(&m_mutex);
    size_t n = std::min(count, m_count);
    size_t idx = m_tail;
    for (size_t i = 0; i < n; ++i) {
        dest[i] = m_buf[idx];
        idx = (idx + 1) % m_buf.size();
    }
    return n;
}

size_t CircularAudioBuffer::available() const
{
    QMutexLocker lk(&m_mutex);
    return m_count;
}

void CircularAudioBuffer::clear()
{
    QMutexLocker lk(&m_mutex);
    m_head = m_tail = m_count = 0;
}

// ═══════════════════════════════════════════════════════
//  AudioPreprocessor
// ═══════════════════════════════════════════════════════

AudioPreprocessor::AudioPreprocessor()
{
    recomputeHP();
}

void AudioPreprocessor::setSampleRate(int sr)
{
    m_sampleRate = sr;
    recomputeHP();
}

void AudioPreprocessor::setHighPassCutoff(float hz)
{
    m_hpCutoff = hz;
    recomputeHP();
}

void AudioPreprocessor::setNoiseGateThreshold(float rms)
{
    m_gateThreshold = rms;
}

void AudioPreprocessor::setAGCEnabled(bool on)
{
    m_agcEnabled = on;
    m_agcGain = 1.0f;
}

void AudioPreprocessor::setNormalizationTarget(float rms)
{
    m_normTarget = rms;
}

void AudioPreprocessor::recomputeHP()
{
    // Butterworth 2nd-order high-pass via bilinear transform
    const double pi = 3.14159265358979323846;
    double wc = 2.0 * pi * m_hpCutoff / m_sampleRate;
    double k  = std::tan(wc / 2.0);
    double k2 = k * k;
    double sq2 = std::sqrt(2.0);
    double norm = 1.0 / (1.0 + sq2 * k + k2);

    m_b0 =  1.0 * norm;
    m_b1 = -2.0 * norm;
    m_b2 =  1.0 * norm;
    m_a1 =  2.0 * (k2 - 1.0) * norm;
    m_a2 = (1.0 - sq2 * k + k2) * norm;

    // reset state
    m_x1 = m_x2 = m_y1 = m_y2 = 0.0;
}

void AudioPreprocessor::process(int16_t *samples, int count)
{
    if (count <= 0) return;

    // ---- 1. High-pass filter (in-place) ----
    for (int i = 0; i < count; ++i) {
        double x0 = static_cast<double>(samples[i]);
        double y0 = m_b0 * x0 + m_b1 * m_x1 + m_b2 * m_x2
                   - m_a1 * m_y1 - m_a2 * m_y2;
        m_x2 = m_x1; m_x1 = x0;
        m_y2 = m_y1; m_y1 = y0;
        // clamp
        y0 = std::clamp(y0, -32768.0, 32767.0);
        samples[i] = static_cast<int16_t>(y0);
    }

    // ---- 2. Compute RMS of this chunk ----
    double sumSq = 0.0;
    for (int i = 0; i < count; ++i) {
        double s = samples[i] / 32768.0;
        sumSq += s * s;
    }
    float rms = static_cast<float>(std::sqrt(sumSq / count));

    // ---- 3. Noise gate ----
    if (rms < m_gateThreshold) {
        if (!m_gateOpen) {
            std::memset(samples, 0, count * sizeof(int16_t));
            return;
        }
        // hysteresis: gate opened, keep open until well below threshold
        if (rms < m_gateThreshold * 0.6f) {
            m_gateOpen = false;
            std::memset(samples, 0, count * sizeof(int16_t));
            return;
        }
    } else {
        m_gateOpen = true;
    }

    // ---- 4. RMS normalization (optional) ----
    if (m_normTarget > 0.0f && rms > 1e-6f) {
        float gain = m_normTarget / rms;
        gain = std::min(gain, 10.0f);  // cap at 20 dB boost
        for (int i = 0; i < count; ++i) {
            float v = samples[i] * gain;
            samples[i] = static_cast<int16_t>(std::clamp(v, -32768.0f, 32767.0f));
        }
    }

    // ---- 5. AGC (slow envelope follower) ----
    if (m_agcEnabled && rms > 1e-6f) {
        constexpr float TARGET = 0.15f;  // target RMS ~ -16 dBFS
        float desired = TARGET / rms;
        // smooth
        m_agcGain += 0.05f * (desired - m_agcGain);
        m_agcGain = std::clamp(m_agcGain, 0.1f, 10.0f);
        for (int i = 0; i < count; ++i) {
            float v = samples[i] * m_agcGain;
            samples[i] = static_cast<int16_t>(std::clamp(v, -32768.0f, 32767.0f));
        }
    }
}

// ═══════════════════════════════════════════════════════
//  VADEngine
// ═══════════════════════════════════════════════════════

VADEngine::VADEngine(QObject *parent)
    : QObject(parent)
{}

VADEngine::~VADEngine() = default;

bool VADEngine::initialize(Backend preferred)
{
    // Note: SileroONNX requires ONNX Runtime library (not bundled yet).
    // Silero VAD is also active server-side in stt_server.py (faster-whisper vad_filter).
    // For now we use the Builtin backend which is calibrated and works well.
    if (preferred == Backend::SileroONNX) {
        hVoice() << "Silero ONNX VAD demandé mais non compilé — fallback Builtin";
    }
    m_backend = Backend::Builtin;
    resetNoiseEstimate();
    hVoice() << "VAD initialisé (backend: Builtin energy+ZCR, Silero actif côté STT server)";
    return true;
}

void VADEngine::resetNoiseEstimate()
{
    m_noiseFloor = 0.0f;
    m_noiseCalibrated = false;
    m_calibrationFrames = 0;
    m_speechFrames = 0;
    m_silenceFrames = 0;
    m_isSpeech = false;
}

float VADEngine::builtinScore(const int16_t *s, int n)
{
    if (n <= 0) return 0.0f;

    // RMS energy (normalized 0..1)
    double sumSq = 0.0;
    for (int i = 0; i < n; ++i) {
        double v = s[i] / 32768.0;
        sumSq += v * v;
    }
    float rms = static_cast<float>(std::sqrt(sumSq / n));

    // Zero-crossing rate (normalized 0..1, speech ~0.05-0.15)
    int zc = 0;
    for (int i = 1; i < n; ++i) {
        if ((s[i] >= 0) != (s[i - 1] >= 0)) ++zc;
    }
    float zcr = static_cast<float>(zc) / static_cast<float>(n);

    // Adaptive noise floor (updated only during non-speech)
    if (!m_noiseCalibrated) {
        m_noiseFloor += rms;
        ++m_calibrationFrames;
        if (m_calibrationFrames >= CALIBRATION_WINDOW) {
            m_noiseFloor /= CALIBRATION_WINDOW;
            m_noiseCalibrated = true;
            hVoice() << "VAD noise floor calibré:" << m_noiseFloor;
        }
        return 0.0f; // no detection during calibration
    }

    // Update noise floor slowly when NOT in speech
    if (!m_isSpeech) {
        m_noiseFloor = 0.95f * m_noiseFloor + 0.05f * rms;
    }

    // Signal-to-noise ratio score
    float snr = (m_noiseFloor > 1e-6f) ? (rms / m_noiseFloor) : rms * 100.0f;

    // Composite score: weigh energy heavily, penalize very high ZCR (noise)
    // Speech typically has moderate ZCR (0.02-0.2) and high energy above noise
    float zcrPenalty = (zcr > 0.35f) ? 0.5f : 1.0f;
    float score = std::min(1.0f, (snr - 1.0f) / 5.0f) * zcrPenalty;
    score = std::clamp(score, 0.0f, 1.0f);

    return score;
}

float VADEngine::processChunk(const int16_t *samples, int count)
{
    float score = builtinScore(samples, count);
    updateSpeechState(score);
    return score;
}

void VADEngine::updateSpeechState(float score)
{
    bool frameIsSpeech = score >= m_threshold;

    if (frameIsSpeech) {
        ++m_speechFrames;
        m_silenceFrames = 0;
    } else {
        ++m_silenceFrames;
        // don't reset m_speechFrames immediately — hang period
    }

    if (!m_isSpeech) {
        // transition to speech
        if (m_speechFrames >= SPEECH_START_FRAMES) {
            m_isSpeech = true;
            emit speechStarted();
        }
    } else {
        // transition to silence
        if (m_silenceFrames >= SPEECH_HANG_FRAMES) {
            m_isSpeech = false;
            m_speechFrames = 0;
            emit speechEnded();
        }
    }
}

// ═══════════════════════════════════════════════════════
//  StreamingSTT — WebSocket client for stt_server.py
// ═══════════════════════════════════════════════════════

StreamingSTT::StreamingSTT(QObject *parent)
    : QObject(parent)
{}

StreamingSTT::~StreamingSTT()
{
    if (m_ws) {
        m_ws->close();
    }
}

bool StreamingSTT::initialize(const QString &serverUrl)
{
    m_serverUrl = serverUrl;

    if (m_ws) {
        m_ws->close();
        m_ws->deleteLater();
    }

    m_ws = new QWebSocket(QString(), QWebSocketProtocol::VersionLatest, this);
    connect(m_ws, &QWebSocket::connected,
            this, &StreamingSTT::onWsConnected);
    connect(m_ws, &QWebSocket::disconnected,
            this, &StreamingSTT::onWsDisconnected);
    connect(m_ws, &QWebSocket::textMessageReceived,
            this, &StreamingSTT::onWsTextMessage);
    connect(m_ws, &QWebSocket::errorOccurred,
            this, &StreamingSTT::onWsError);

    hVoice() << "StreamingSTT: connexion à" << serverUrl;
    m_reconnectAttempts = 0;
    m_ws->open(QUrl(serverUrl));
    return true;  // async — actual availability set on connect
}

void StreamingSTT::onWsConnected()
{
    m_connected = true;
    m_reconnectAttempts = 0;
    hVoice() << "StreamingSTT: connecté au serveur STT";
    emit connected();

    // Send initial config
    QJsonObject cfg;
    cfg["type"] = "config";
    cfg["language"] = m_language;
    cfg["beam_size"] = m_beamSize;
    m_ws->sendTextMessage(QString::fromUtf8(
        QJsonDocument(cfg).toJson(QJsonDocument::Compact)));
}

void StreamingSTT::onWsDisconnected()
{
    m_connected = false;
    m_recording = false;
    hVoice() << "StreamingSTT: déconnecté du serveur STT";
    emit disconnected();
    reconnect();
}

void StreamingSTT::onWsError(QAbstractSocket::SocketError err)
{
    Q_UNUSED(err)
    hWarning(henriVoice) << "StreamingSTT erreur:" << m_ws->errorString();
    if (!m_connected) {
        reconnect();
    }
}

void StreamingSTT::reconnect()
{
    if (m_reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
        hWarning(henriVoice) << "StreamingSTT: abandon après"
                             << MAX_RECONNECT_ATTEMPTS << "tentatives";
        emit error("STT server unreachable");
        return;
    }

    int delay = RECONNECT_BASE_MS * (1 << std::min(m_reconnectAttempts, 5));
    ++m_reconnectAttempts;
    hVoice() << "StreamingSTT: reconnexion dans" << delay << "ms (tentative"
             << m_reconnectAttempts << ")";
    QTimer::singleShot(delay, this, [this]() {
        if (!m_connected && m_ws) {
            m_ws->open(QUrl(m_serverUrl));
        }
    });
}

void StreamingSTT::onWsTextMessage(const QString &msg)
{
    QJsonDocument doc = QJsonDocument::fromJson(msg.toUtf8());
    if (!doc.isObject()) return;
    QJsonObject obj = doc.object();
    QString type = obj["type"].toString();

    if (type == "partial") {
        QString text = obj["text"].toString();
        if (!text.isEmpty()) {
            emit partialTranscript(text);
        }
    } else if (type == "final") {
        QString text = obj["text"].toString();
        hVoice() << "STT final:" << text;
        emit finalTranscript(text);
    } else if (type == "ready") {
        hVoice() << "STT server prêt — modèle:" << obj["model"].toString()
                 << "device:" << obj["device"].toString();
    } else if (type == "error") {
        emit error(obj["message"].toString());
    }
}

void StreamingSTT::startUtterance()
{
    if (!m_connected) {
        emit error("STT server non connecté");
        return;
    }
    m_recording = true;
    QJsonObject msg;
    msg["type"] = "start";
    m_ws->sendTextMessage(QString::fromUtf8(
        QJsonDocument(msg).toJson(QJsonDocument::Compact)));
}

void StreamingSTT::feedAudio(const int16_t *samples, int count)
{
    if (!m_connected || !m_recording || count <= 0) return;

    // Send raw PCM16 as binary WebSocket frame
    QByteArray data(reinterpret_cast<const char *>(samples),
                    count * static_cast<int>(sizeof(int16_t)));
    m_ws->sendBinaryMessage(data);
}

void StreamingSTT::endUtterance()
{
    if (!m_connected) return;
    m_recording = false;
    QJsonObject msg;
    msg["type"] = "end";
    m_ws->sendTextMessage(QString::fromUtf8(
        QJsonDocument(msg).toJson(QJsonDocument::Compact)));
}

void StreamingSTT::cancelUtterance()
{
    if (!m_connected) return;
    m_recording = false;
    QJsonObject msg;
    msg["type"] = "cancel";
    m_ws->sendTextMessage(QString::fromUtf8(
        QJsonDocument(msg).toJson(QJsonDocument::Compact)));
}

void StreamingSTT::transcribeBuffer(const std::vector<int16_t> &pcm)
{
    // Non-streaming fallback: send entire buffer at once
    if (!m_connected || pcm.empty()) {
        emit error("STT non disponible ou audio vide");
        return;
    }

    startUtterance();
    feedAudio(pcm.data(), static_cast<int>(pcm.size()));
    endUtterance();
}

void StreamingSTT::setLanguage(const QString &lang)
{
    m_language = lang;
    if (m_connected) {
        QJsonObject cfg;
        cfg["type"] = "config";
        cfg["language"] = lang;
        m_ws->sendTextMessage(QString::fromUtf8(
            QJsonDocument(cfg).toJson(QJsonDocument::Compact)));
    }
}

void StreamingSTT::setBeamSize(int beam)
{
    m_beamSize = beam;
    if (m_connected) {
        QJsonObject cfg;
        cfg["type"] = "config";
        cfg["beam_size"] = beam;
        m_ws->sendTextMessage(QString::fromUtf8(
            QJsonDocument(cfg).toJson(QJsonDocument::Compact)));
    }
}

// ═══════════════════════════════════════════════════════
//  VoicePipeline — main orchestrator
// ═══════════════════════════════════════════════════════

VoicePipeline::VoicePipeline(QObject *parent)
    : QObject(parent)
    , m_ringBuf(SAMPLE_RATE * 10) // 10 s ring buffer
{
    m_ttsEndClock.start();
    m_lastWakeWordClock.start();

    m_utteranceTimer = new QTimer(this);
    m_utteranceTimer->setSingleShot(true);
    connect(m_utteranceTimer, &QTimer::timeout,
            this, &VoicePipeline::onUtteranceTimeout);
}

VoicePipeline::~VoicePipeline()
{
    stopListening();
}

// ── initialisation ───────────────────────────────────

bool VoicePipeline::initAudio()
{
    m_format.setSampleRate(SAMPLE_RATE);
    m_format.setChannelCount(1);
    m_format.setSampleFormat(QAudioFormat::Int16);

    const QAudioDevice &dev = QMediaDevices::defaultAudioInput();
    if (dev.isNull()) {
        hVoice() << "Aucun périphérique audio d'entrée";
        emit voiceError("Aucun micro détecté");
        return false;
    }

    if (!dev.isFormatSupported(m_format)) {
        hVoice() << "Format 16kHz/mono/Int16 non supporté, utilisation du format préféré";
        m_format = dev.preferredFormat();
        m_preproc.setSampleRate(m_format.sampleRate());
    }

    hVoice() << "Audio initialisé — device:" << dev.description()
             << "rate:" << m_format.sampleRate()
             << "ch:" << m_format.channelCount();
    return true;
}

bool VoicePipeline::initVAD(VADEngine::Backend preferred)
{
    m_vad = std::make_unique<VADEngine>(this);
    connect(m_vad.get(), &VADEngine::speechStarted,
            this, &VoicePipeline::onVADSpeechStarted);
    connect(m_vad.get(), &VADEngine::speechEnded,
            this, &VoicePipeline::onVADSpeechEnded);
    return m_vad->initialize(preferred);
}

bool VoicePipeline::initSTT(const QString &serverUrl)
{
    m_stt = std::make_unique<StreamingSTT>(this);
    connect(m_stt.get(), &StreamingSTT::partialTranscript,
            this, &VoicePipeline::onSTTPartial);
    connect(m_stt.get(), &StreamingSTT::finalTranscript,
            this, &VoicePipeline::onSTTFinal);
    connect(m_stt.get(), &StreamingSTT::error,
            this, [this](const QString &e) {
                hVoice() << "STT erreur:" << e;
                onSTTError(e);
            });
    connect(m_stt.get(), &StreamingSTT::connected,
            this, [this]() {
                hVoice() << "STT server connecté — streaming STT actif";
            });
    return m_stt->initialize(serverUrl);
}

void VoicePipeline::initTTS(const QString &ttsServerUrl)
{
    m_ttsManager = new TTSManager(this);
    m_ttsManager->initTTS();
    m_ttsManager->initDSP();

    // Initialize Piper TTS cascade
    if (!ttsServerUrl.isEmpty()) {
        m_ttsManager->initCascade(ttsServerUrl);
    }

    // Pass WebSocket for GUI broadcast
    if (m_ws)
        m_ttsManager->setWebSocket(m_ws);

    connect(m_ttsManager, &TTSManager::ttsStarted,
            this, &VoicePipeline::onTtsStarted);
    connect(m_ttsManager, &TTSManager::ttsFinished,
            this, &VoicePipeline::onTtsFinished);
    connect(m_ttsManager, &TTSManager::ttsError,
            this, &VoicePipeline::onTtsError);

    hVoice() << "TTSManager initialisé avec DSP pipeline";
}

// ── start / stop ─────────────────────────────────────

void VoicePipeline::startListening()
{
    if (m_audioRunning) return;

    const QAudioDevice &dev = QMediaDevices::defaultAudioInput();
    if (dev.isNull()) {
        emit voiceError("Aucun micro disponible");
        return;
    }

    m_audioSource = std::make_unique<QAudioSource>(dev, m_format);
    m_audioIO = m_audioSource->start();
    if (!m_audioIO) {
        emit voiceError("Impossible de démarrer la capture audio");
        return;
    }

    connect(m_audioIO, &QIODevice::readyRead,
            this, &VoicePipeline::onAudioDataReady);

    m_audioRunning = true;
    setState(PipelineState::Idle);
    emit listeningChanged();

    if (m_vad)
        m_vad->resetNoiseEstimate();

    hVoice() << "Pipeline démarré — wake-word logiciel '" << m_wakeKeyword << "' (détection dans transcript)";
}

void VoicePipeline::stopListening()
{
    if (!m_audioRunning) return;

    if (m_audioSource) {
        m_audioSource->stop();
        m_audioSource.reset();
    }
    m_audioIO = nullptr;
    m_audioRunning = false;
    m_utteranceTimer->stop();
    setState(PipelineState::Idle);
    emit listeningChanged();
    hVoice() << "Pipeline arrêté";
}

void VoicePipeline::speak(const QString &text)
{
    if (text.isEmpty() || !m_ttsManager) return;

    // Stop capture while speaking to avoid self-triggering
    if (m_audioSource)
        m_audioSource->suspend();

    hVoice() << "TTS:" << text.left(80) << "...";
    m_ttsManager->speakText(text);
}

void VoicePipeline::resetBuffers()
{
    m_utteranceBuf.clear();
    m_ringBuf.clear();
    m_wakeWordTriggered = false;
    if (m_vad)
        m_vad->resetNoiseEstimate();
    hVoice() << "Buffers réinitialisés";
}

// ── tuning ───────────────────────────────────────────

void VoicePipeline::setWakeWordSensitivity(float s)
{
    Q_UNUSED(s) // wake-word sensitivity not used with software detection
    hVoice() << "Wake word sensitivity:" << s;
}

void VoicePipeline::setVADThreshold(float t)
{
    if (m_vad) m_vad->setThreshold(t);
    hVoice() << "VAD threshold:" << t;
}

void VoicePipeline::setNoiseGate(float rms)
{
    m_preproc.setNoiseGateThreshold(rms);
}

void VoicePipeline::setAGC(bool on)
{
    m_preproc.setAGCEnabled(on);
}

void VoicePipeline::setSTTServerUrl(const QString &url)
{
    if (m_stt) m_stt->initialize(url);
    hVoice() << "STT server URL:" << url;
}

void VoicePipeline::setSTTLanguage(const QString &lang)
{
    if (m_stt) m_stt->setLanguage(lang);
    hVoice() << "STT language:" << lang;
}

// ── WebSocket bridge ─────────────────────────────────

void VoicePipeline::connectToServer(const QString &url)
{
    if (m_ws) {
        m_ws->close();
        m_ws->deleteLater();
    }
    m_ws = new QWebSocket(QString(), QWebSocketProtocol::VersionLatest, this);
    connect(m_ws, &QWebSocket::textMessageReceived,
            this, &VoicePipeline::onWsTextMessage);
    connect(m_ws, &QWebSocket::binaryMessageReceived,
            this, &VoicePipeline::onWsBinaryMessage);
    connect(m_ws, &QWebSocket::connected, this, [this]() {
        hVoice() << "WebSocket connecté";
        broadcastState();
    });
    connect(m_ws, &QWebSocket::disconnected, this, [this, url]() {
        hVoice() << "WebSocket déconnecté — reconnexion dans 5s";
        QTimer::singleShot(5000, this, [this, url]() { connectToServer(url); });
    });
    m_ws->open(QUrl(url));
}

void VoicePipeline::sendWebSocketMessage(const QString &message)
{
    if (m_ws && m_ws->isValid()) {
        m_ws->sendTextMessage(message);
    } else {
        hWarning(henriVoice) << "WebSocket non connecté — message perdu";
    }
}

void VoicePipeline::onWsTextMessage(const QString &msg)
{
    // Messages from exo_server.py (e.g. TTS response)
    QJsonDocument doc = QJsonDocument::fromJson(msg.toUtf8());
    if (!doc.isObject()) return;
    QJsonObject obj = doc.object();
    QString type = obj["type"].toString();

    if (type == "tts") {
        speak(obj["text"].toString());
    }
}

void VoicePipeline::onWsBinaryMessage(const QByteArray &msg)
{
    Q_UNUSED(msg)
}

// ── audio data callback (main thread) ────────────────

void VoicePipeline::onAudioDataReady()
{
    if (!m_audioIO) return;
    QByteArray raw = m_audioIO->readAll();
    if (raw.isEmpty()) return;

    int sampleCount = raw.size() / static_cast<int>(sizeof(int16_t));
    if (sampleCount <= 0) return;

    // Work on a mutable copy for preprocessing
    std::vector<int16_t> chunk(sampleCount);
    std::memcpy(chunk.data(), raw.constData(), sampleCount * sizeof(int16_t));

    // Preprocess (high-pass, gate, AGC)
    m_preproc.process(chunk.data(), sampleCount);

    // Write to ring buffer
    m_ringBuf.write(chunk.data(), sampleCount);

    // Process in CHUNK_SAMPLES-sized blocks
    // (remaining samples carry over via ring buffer)
    processAudioChunk(chunk.data(), sampleCount);
}

// ── core pipeline ────────────────────────────────────

void VoicePipeline::processAudioChunk(const int16_t *samples, int count)
{
    if (m_state == PipelineState::Speaking) return;

    // Guard against self-triggering right after TTS
    if (m_ttsEndClock.elapsed() < TTS_GUARD_MS) return;

    // ── VAD scoring ──
    float vadScore = 0.0f;
    if (m_vad)
        vadScore = m_vad->processChunk(samples, count);

    // ── Compute RMS for UI ──
    double sumSq = 0.0;
    for (int i = 0; i < count; ++i) {
        double v = samples[i] / 32768.0;
        sumSq += v * v;
    }
    float rms = static_cast<float>(std::sqrt(sumSq / count));
    broadcastAudioLevel(rms, vadScore);
    emit audioLevel(rms, vadScore);

    switch (m_state) {
    case PipelineState::Idle:
        // VAD déclenche le passage en DetectingSpeech
        if (m_vad && vadScore >= m_vad->threshold()) {
            handleVAD(samples, count, vadScore);
        }
        break;

    case PipelineState::DetectingSpeech:
        // Accumule audio + stream vers STT pendant le grace period
        handleRecording(samples, count);
        if (m_stt && m_stt->isConnected() && m_sttStreaming) {
            m_stt->feedAudio(samples, count);
        }
        break;

    case PipelineState::Listening:
        handleRecording(samples, count);
        // Stream audio to STT server in real-time
        if (m_stt && m_stt->isConnected() && m_sttStreaming) {
            m_stt->feedAudio(samples, count);
        }
        // End-of-speech detection via VAD
        if (m_vad && !m_vad->isSpeech()
            && m_utteranceBuf.size() > static_cast<size_t>(SAMPLE_RATE)) {
            finishUtterance();
        }
        break;

    case PipelineState::Transcribing:
    case PipelineState::Thinking:
    case PipelineState::Speaking:
        break;
    }
}

void VoicePipeline::handleVAD(const int16_t *samples, int count, float vadScore)
{
    Q_UNUSED(samples)
    Q_UNUSED(count)

    // VAD a détecté de la parole → commencer capture + streaming STT
    if (m_lastWakeWordClock.elapsed() < WAKE_COOLDOWN_MS) return;

    if (vadScore >= m_vad->threshold()) {
        hVoice() << "VAD: parole détectée (score:" << vadScore << ") → streaming STT";
        m_lastWakeWordClock.restart();
        m_utteranceBuf.clear();
        m_wakeWordTriggered = false;  // reset wake-word flag pour cette utterance
        setState(PipelineState::DetectingSpeech);
        emit speechStarted();
        emit statusChanged("Détection parole...");
        m_utteranceTimer->start(UTTERANCE_TIMEOUT_MS);

        // Start streaming STT immediately
        if (m_stt && m_stt->isConnected()) {
            m_stt->startUtterance();
            m_sttStreaming = true;
        }

        // Grace period → passer en Listening
        QTimer::singleShot(POST_WAKE_GRACE_MS, this, [this]() {
            if (m_state == PipelineState::DetectingSpeech)
                setState(PipelineState::Listening);
        });
    }
}

// ── Wake-word logiciel : détection de "EXO" dans le transcript ──

bool VoicePipeline::checkWakeWord(const QString &text)
{
    return text.toLower().contains(m_wakeKeyword);
}

void VoicePipeline::handleRecording(const int16_t *samples, int count)
{
    // Append to utterance buffer (capped)
    size_t space = MAX_UTTERANCE_SAMPLES - m_utteranceBuf.size();
    size_t toAdd = std::min(static_cast<size_t>(count), space);
    m_utteranceBuf.insert(m_utteranceBuf.end(), samples, samples + toAdd);

    if (m_utteranceBuf.size() >= MAX_UTTERANCE_SAMPLES) {
        hVoice() << "Utterance buffer plein — fin de capture";
        finishUtterance();
    }
}

void VoicePipeline::finishUtterance()
{
    m_utteranceTimer->stop();

    if (m_utteranceBuf.empty()) {
        hVoice() << "Utterance vide — retour à Idle";
        if (m_sttStreaming) {
            m_stt->cancelUtterance();
            m_sttStreaming = false;
        }
        setState(PipelineState::Idle);
        return;
    }

    setState(PipelineState::Transcribing);
    emit speechEnded();
    emit statusChanged("Transcription en cours...");

    hVoice() << "Utterance capturée:" << m_utteranceBuf.size() << "samples ("
             << (m_utteranceBuf.size() * 1000 / SAMPLE_RATE) << "ms)";

    // End the streaming utterance if we were streaming
    if (m_stt && m_stt->isConnected()) {
        if (m_sttStreaming) {
            // We were already streaming audio — just signal end
            m_stt->endUtterance();
            m_sttStreaming = false;
        } else {
            // Fallback: send entire buffer in one shot
            m_stt->transcribeBuffer(m_utteranceBuf);
        }
    } else {
        // Internal energy-based fallback (placeholder until STT server is available)
        QString text = analyzeAudioFallback(m_utteranceBuf);
        if (!text.isEmpty()) {
            dispatchTranscript(text);
        } else {
            emit voiceError("STT non disponible — parlez plus fort ou plus près du micro");
            setState(PipelineState::Idle);
        }
    }
}

void VoicePipeline::dispatchTranscript(const QString &text)
{
    m_lastCommand = text;
    hVoice() << "Transcript final:" << text;
    emit finalTranscript(text);
    emit speechTranscribed(text);
    emit commandDetected(text);

    // Send to Python backend via WebSocket
    if (m_ws && m_ws->state() == QAbstractSocket::ConnectedState) {
        QJsonObject msg;
        msg["type"] = "transcript";
        msg["text"] = text;
        msg["timestamp"] = QDateTime::currentMSecsSinceEpoch();
        m_ws->sendTextMessage(QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact)));
    }

    setState(PipelineState::Thinking);
}

// ── utterance timeout ────────────────────────────────

void VoicePipeline::onUtteranceTimeout()
{
    hVoice() << "Utterance timeout (" << UTTERANCE_TIMEOUT_MS << "ms)";
    if (m_state == PipelineState::Listening || m_state == PipelineState::DetectingSpeech) {
        finishUtterance();
    }
}

// ── VAD callbacks ────────────────────────────────────

void VoicePipeline::onVADSpeechStarted()
{
    if (m_state == PipelineState::DetectingSpeech || m_state == PipelineState::Listening) {
        emit speechStarted();
    }
}

void VoicePipeline::onVADSpeechEnded()
{
    // Speech end is handled in processAudioChunk for tighter control
}

// ── STT callbacks ────────────────────────────────────

void VoicePipeline::onSTTPartial(const QString &text)
{
    emit partialTranscript(text);
    emit statusChanged("\"" + text + "\"...");

    // Wake-word logiciel : détecter "EXO" dans le transcript partiel
    if (!m_wakeWordTriggered && checkWakeWord(text)) {
        m_wakeWordTriggered = true;
        hVoice() << "Wake-word logiciel détecté dans transcript:" << text;
        emit wakeWordDetected();
        emit statusChanged("EXO écoute...");
    }

    if (m_ws && m_ws->state() == QAbstractSocket::ConnectedState) {
        QJsonObject msg;
        msg["type"] = "partial_transcript";
        msg["text"] = text;
        m_ws->sendTextMessage(QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact)));
    }
}

void VoicePipeline::onSTTFinal(const QString &text)
{
    // Vérifier wake-word dans le transcript final aussi
    if (!m_wakeWordTriggered && checkWakeWord(text)) {
        m_wakeWordTriggered = true;
        hVoice() << "Wake-word logiciel détecté dans transcript final:" << text;
        emit wakeWordDetected();
    }

    if (m_wakeWordTriggered) {
        // Wake-word détecté → dispatch vers Claude
        // Retirer le mot-clé du texte envoyé à Claude
        QString command = text;
        command.remove(QRegularExpression("\\bexo\\b", QRegularExpression::CaseInsensitiveOption));
        command = command.trimmed();
        if (!command.isEmpty()) {
            dispatchTranscript(command);
        } else {
            hVoice() << "Transcript ne contient que le wake-word — retour Idle";
            setState(PipelineState::Idle);
        }
    } else {
        // Pas de wake-word → ignorer et retourner en Idle
        hVoice() << "Transcript sans wake-word ignoré:" << text;
        setState(PipelineState::Idle);
    }
    m_wakeWordTriggered = false;
}

void VoicePipeline::onSTTError(const QString &msg)
{
    hVoice() << "STT erreur:" << msg;
    // Fallback to internal analysis
    if (!m_utteranceBuf.empty()) {
        QString fallback = analyzeAudioFallback(m_utteranceBuf);
        if (!fallback.isEmpty()) {
            dispatchTranscript(fallback);
            return;
        }
    }
    emit voiceError("Erreur STT: " + msg);
    setState(PipelineState::Idle);
}

// ── TTS callbacks ────────────────────────────────────

void VoicePipeline::onTtsStarted()
{
    m_isSpeaking = true;
    setState(PipelineState::Speaking);
    emit speakingChanged();
}

void VoicePipeline::onTtsFinished()
{
    if (m_isSpeaking) {
        m_isSpeaking = false;
        m_ttsEndClock.restart();
        emit speakingChanged();
        hVoice() << "TTS terminé — reprise écoute dans" << TTS_GUARD_MS << "ms";

        QTimer::singleShot(TTS_GUARD_MS, this, [this]() {
            if (m_audioSource)
                m_audioSource->resume();
            resetBuffers();
            setState(PipelineState::Idle);
        });
    }
}

void VoicePipeline::onTtsError(const QString &msg)
{
    hVoice() << "TTS erreur:" << msg;
    if (m_isSpeaking) {
        m_isSpeaking = false;
        m_ttsEndClock.restart();
        emit speakingChanged();
        if (m_audioSource) m_audioSource->resume();
        setState(PipelineState::Idle);
    }
}

// ── state machine ────────────────────────────────────

void VoicePipeline::setState(PipelineState s)
{
    if (m_state == s) return;
    m_state = s;
    emit stateChanged(static_cast<int>(s));
    broadcastState();

    static const char *names[] = {"Idle", "DetectingSpeech", "Listening", "Transcribing", "Thinking", "Speaking"};
    hVoice() << "État:" << names[static_cast<int>(s)];
}

void VoicePipeline::broadcastState()
{
    if (!m_ws || m_ws->state() != QAbstractSocket::ConnectedState) return;

    static const QString stateNames[] = {"idle", "detecting_speech", "listening", "transcribing", "thinking", "speaking"};
    QJsonObject msg;
    msg["type"]  = "pipeline_state";
    msg["state"] = stateNames[static_cast<int>(m_state)];
    m_ws->sendTextMessage(QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact)));
}

void VoicePipeline::broadcastAudioLevel(float rms, float vadScore)
{
    if (!m_ws || m_ws->state() != QAbstractSocket::ConnectedState) return;

    // Throttle: send at most ~10 Hz
    static QElapsedTimer throttle;
    if (!throttle.isValid()) throttle.start();
    if (throttle.elapsed() < 100) return;
    throttle.restart();

    QJsonObject msg;
    msg["type"]      = "audio_level";
    msg["rms"]       = static_cast<double>(rms);
    msg["vad_score"] = static_cast<double>(vadScore);
    msg["is_speech"] = m_vad ? m_vad->isSpeech() : false;
    m_ws->sendTextMessage(QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact)));
}

// ── fallback STT (energy heuristic) ──────────────────

QString VoicePipeline::analyzeAudioFallback(const std::vector<int16_t> &pcm)
{
    // This is a placeholder that returns a generic "commande vocale"
    // when no real STT (Whisper) is available.
    // It signals the AssistantManager that speech was detected so it can
    // ask Claude to respond conversationally.
    if (pcm.size() < 4000) return QString(); // < 250ms → too short

    // Compute average energy
    long long total = 0;
    for (auto s : pcm) total += std::abs(static_cast<int>(s));
    int avg = static_cast<int>(total / static_cast<long long>(pcm.size()));

    int durationMs = static_cast<int>(pcm.size() * 1000 / SAMPLE_RATE);

    hVoice() << "Fallback analyse — énergie:" << avg << " durée:" << durationMs << "ms";

    if (avg < 200) return QString(); // too quiet

    // Return a generic marker that AssistantManager can handle
    // In production, this path should not be used — Whisper should be available
    return QStringLiteral("[commande_vocale:%1ms]").arg(durationMs);
}
