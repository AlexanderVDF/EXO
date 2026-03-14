#include "ttsmanager.h"
#include "logmanager.h"

#include <QCoreApplication>
#include <QRegularExpression>
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>
#include <QtEndian>
#include <algorithm>
#include <cstring>
#include <cmath>

// ═══════════════════════════════════════════════════════
//  TTSEqualizer — 2nd-order peaking EQ (presence band)
// ═══════════════════════════════════════════════════════

void TTSEqualizer::configure(int sampleRate, float centerHz,
                              float gainDb, float q)
{
    // Peaking EQ via Audio-EQ-Cookbook (Robert Bristow-Johnson)
    const double pi = 3.14159265358979323846;
    double w0 = 2.0 * pi * centerHz / sampleRate;
    double A  = std::pow(10.0, gainDb / 40.0);
    double alpha = std::sin(w0) / (2.0 * q);

    double b0 =  1.0 + alpha * A;
    double b1 = -2.0 * std::cos(w0);
    double b2 =  1.0 - alpha * A;
    double a0 =  1.0 + alpha / A;
    double a1 = -2.0 * std::cos(w0);
    double a2 =  1.0 - alpha / A;

    // Normalise so a0 == 1
    m_b0 = b0 / a0;
    m_b1 = b1 / a0;
    m_b2 = b2 / a0;
    m_a1 = a1 / a0;
    m_a2 = a2 / a0;

    reset();
}

void TTSEqualizer::process(float *samples, int count)
{
    for (int i = 0; i < count; ++i) {
        double x0 = samples[i];
        double y0 = m_b0 * x0 + m_b1 * m_x1 + m_b2 * m_x2
                   - m_a1 * m_y1 - m_a2 * m_y2;
        m_x2 = m_x1; m_x1 = x0;
        m_y2 = m_y1; m_y1 = y0;
        samples[i] = static_cast<float>(y0);
    }
}

void TTSEqualizer::reset()
{
    m_x1 = m_x2 = m_y1 = m_y2 = 0.0;
}

// ═══════════════════════════════════════════════════════
//  TTSCompressor — soft-knee downward compressor
// ═══════════════════════════════════════════════════════

void TTSCompressor::configure(int sampleRate, float thresholdDb,
                               float ratio, float attackMs,
                               float releaseMs)
{
    m_threshold = thresholdDb;
    m_ratio     = ratio;
    // Attack / release as one-pole coefficients
    m_attack  = 1.0f - std::exp(-1.0f / (sampleRate * attackMs / 1000.0f));
    m_release = 1.0f - std::exp(-1.0f / (sampleRate * releaseMs / 1000.0f));
    reset();
}

void TTSCompressor::process(float *samples, int count)
{
    float threshLin = std::pow(10.0f, m_threshold / 20.0f);

    for (int i = 0; i < count; ++i) {
        float absVal = std::fabs(samples[i]);

        // Smooth envelope follower
        float coeff = (absVal > m_envelope) ? m_attack : m_release;
        m_envelope += coeff * (absVal - m_envelope);

        if (m_envelope > threshLin) {
            float envDb   = 20.0f * std::log10(m_envelope + 1e-12f);
            float overDb  = envDb - m_threshold;
            float gainDb  = overDb - overDb / m_ratio;
            float gainLin = std::pow(10.0f, -gainDb / 20.0f);
            samples[i] *= gainLin;
        }
    }
}

void TTSCompressor::reset()
{
    m_envelope = 0.0f;
}

// ═══════════════════════════════════════════════════════
//  TTSNormalizer — peak normalization to target dBFS
// ═══════════════════════════════════════════════════════

void TTSNormalizer::process(float *samples, int count)
{
    if (count <= 0) return;

    // Find peak
    float peak = 0.0f;
    for (int i = 0; i < count; ++i)
        peak = std::max(peak, std::fabs(samples[i]));

    if (peak < 1e-6f) return; // silence

    float targetLin = std::pow(10.0f, m_targetDb / 20.0f);
    float gain = targetLin / peak;
    // Don't amplify more than 20 dB
    gain = std::min(gain, 10.0f);

    for (int i = 0; i < count; ++i)
        samples[i] *= gain;
}

// ═══════════════════════════════════════════════════════
//  TTSFade — anti-click fade-in / fade-out
// ═══════════════════════════════════════════════════════

void TTSFade::configure(int sampleRate, float fadeInMs, float fadeOutMs)
{
    m_fadeInSamples  = static_cast<int>(sampleRate * fadeInMs / 1000.0f);
    m_fadeOutSamples = static_cast<int>(sampleRate * fadeOutMs / 1000.0f);
    if (m_fadeInSamples  < 1) m_fadeInSamples  = 1;
    if (m_fadeOutSamples < 1) m_fadeOutSamples = 1;
}

void TTSFade::applyFadeIn(float *samples, int count)
{
    int n = std::min(count, m_fadeInSamples);
    for (int i = 0; i < n; ++i) {
        float t = static_cast<float>(i) / static_cast<float>(m_fadeInSamples);
        // Raised-cosine fade (smoother than linear)
        float gain = 0.5f * (1.0f - std::cos(3.14159265f * t));
        samples[i] *= gain;
    }
}

void TTSFade::applyFadeOut(float *samples, int count)
{
    int n = std::min(count, m_fadeOutSamples);
    int offset = count - n;
    for (int i = 0; i < n; ++i) {
        float t = static_cast<float>(i) / static_cast<float>(m_fadeOutSamples);
        float gain = 0.5f * (1.0f + std::cos(3.14159265f * t));
        samples[offset + i] *= gain;
    }
}

// ═══════════════════════════════════════════════════════
//  TTSDSPProcessor — modular DSP pipeline
//  EQ → Compressor → Normalizer → Fade → Anti-clip
// ═══════════════════════════════════════════════════════

void TTSDSPProcessor::configure(int sampleRate)
{
    m_sampleRate = sampleRate;
    m_eq.configure(sampleRate, 3000.0f, 3.0f, 1.0f);
    m_comp.configure(sampleRate, -18.0f, 2.0f, 5.0f, 50.0f);
    m_norm.setTargetDb(-14.0f);
    m_fade.configure(sampleRate, 5.0f, 10.0f);
    m_firstChunk = true;
}

void TTSDSPProcessor::process(int16_t *pcm, int count, bool isFinalChunk)
{
    if (!m_enabled || count <= 0) return;

    // Convert int16 → float [-1, +1]
    std::vector<float> fbuf(count);
    for (int i = 0; i < count; ++i)
        fbuf[i] = pcm[i] / 32768.0f;

    // 1. Presence EQ (2-4 kHz boost)
    m_eq.process(fbuf.data(), count);

    // 2. Compressor (ratio 2:1)
    m_comp.process(fbuf.data(), count);

    // 3. Normalize to -14 dBFS peak
    m_norm.process(fbuf.data(), count);

    // 4. Fade
    if (m_firstChunk) {
        m_fade.applyFadeIn(fbuf.data(), count);
        m_firstChunk = false;
    }
    if (isFinalChunk)
        m_fade.applyFadeOut(fbuf.data(), count);

    // 5. Anti-clipping (hard limiter at ±1.0)
    for (int i = 0; i < count; ++i)
        fbuf[i] = std::clamp(fbuf[i], -1.0f, 1.0f);

    // Convert float → int16
    for (int i = 0; i < count; ++i)
        pcm[i] = static_cast<int16_t>(fbuf[i] * 32767.0f);
}

void TTSDSPProcessor::reset()
{
    m_eq.reset();
    m_comp.reset();
    m_firstChunk = true;
}

void TTSDSPProcessor::setEQGainDb(float db)
{
    m_eq.configure(m_sampleRate, 3000.0f, db, 1.0f);
}

void TTSDSPProcessor::setCompressorThreshold(float db)
{
    m_comp.configure(m_sampleRate, db, 2.0f, 5.0f, 50.0f);
}

void TTSDSPProcessor::setNormTarget(float dBFS)
{
    m_norm.setTargetDb(dBFS);
}

// ═══════════════════════════════════════════════════════
//  TTSWorker — runs on dedicated QThread
// ═══════════════════════════════════════════════════════

TTSWorker::TTSWorker(QObject *parent)
    : QObject(parent)
{}

TTSWorker::~TTSWorker()
{
    if (m_pyWs) {
        m_pyWs->close();
        delete m_pyWs;
    }
    delete m_tts;
}

void TTSWorker::init()
{
    // Create QTextToSpeech on the worker thread so it lives there
    m_tts = new QTextToSpeech();

    // Select best French voice
    QVoice selected;
    int voiceCount = 0;
    for (const QVoice &v : m_tts->availableVoices()) {
        ++voiceCount;
        if (v.locale().language() == QLocale::French) {
            selected = v;
            // Prefer Julie > Hortense > Paul
            if (v.name().contains("Julie", Qt::CaseInsensitive))
                break;
            if (v.name().contains("Hortense", Qt::CaseInsensitive))
                continue; // keep looking for Julie
        }
    }
    if (!selected.name().isEmpty())
        m_tts->setVoice(selected);

    emit voiceInfo(selected.name().isEmpty() ? "default" : selected.name(),
                   voiceCount);
}

void TTSWorker::setVoice(const QString &name)
{
    if (!m_tts) return;
    for (const QVoice &v : m_tts->availableVoices()) {
        if (v.name().compare(name, Qt::CaseInsensitive) == 0) {
            m_tts->setVoice(v);
            return;
        }
    }
}

void TTSWorker::setPythonWsUrl(const QString &url)
{
    m_pyWsUrl = url;
}

void TTSWorker::processRequest(const TTSRequest &req)
{
    m_cancelled = false;

    // Apply prosody
    if (m_tts) {
        m_tts->setPitch(static_cast<double>(req.prosody.pitch));
        m_tts->setRate(static_cast<double>(req.prosody.rate));
        m_tts->setVolume(static_cast<double>(req.prosody.volume));
    }

    // Cascade: try Piper (Python) first → Qt TTS fallback
    if (tryPythonTTS(req))
        return;

    if (tryQtTTS(req))
        return;

    // All engines failed
    emit error("Tous les moteurs TTS ont échoué pour: " + req.text.left(40));
}

void TTSWorker::cancelCurrent()
{
    m_cancelled = true;
    if (m_tts)
        m_tts->stop();
}

bool TTSWorker::tryQtTTS(const TTSRequest &req)
{
    if (!m_tts) return false;

    emit started(req.text);

    // Synchronous wait approach: tell QTextToSpeech to say, then
    // poll state in a local event loop with timeout.
    m_tts->say(req.text);

    QElapsedTimer timeout;
    timeout.start();

    // Wait for Speaking→Ready transition
    bool wasSpeaking = false;
    while (timeout.elapsed() < QT_TTS_TIMEOUT_MS && !m_cancelled) {
        QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
        auto state = m_tts->state();
        if (state == QTextToSpeech::Speaking)
            wasSpeaking = true;
        if (wasSpeaking && state == QTextToSpeech::Ready) {
            emit finished();
            return true;
        }
        if (state == QTextToSpeech::Error) {
            return false;
        }
    }

    if (m_cancelled) {
        m_tts->stop();
        emit finished();
        return true; // cancelled is not a failure
    }

    // Timeout
    m_tts->stop();
    return false;
}

bool TTSWorker::tryPythonTTS(const TTSRequest &req)
{
    if (m_pyWsUrl.isEmpty()) return false;

    // Connect to Piper TTS server if not already
    if (!m_pyWs) {
        m_pyWs = new QWebSocket();
        m_pyWs->open(QUrl(m_pyWsUrl));

        QElapsedTimer connectTimer;
        connectTimer.start();
        while (m_pyWs->state() != QAbstractSocket::ConnectedState
               && connectTimer.elapsed() < 5000 && !m_cancelled) {
            QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
        }
        m_pyConnected = (m_pyWs->state() == QAbstractSocket::ConnectedState);
    }

    if (!m_pyConnected) return false;

    emit started(req.text);

    // Send synthesis request (Piper tts_server.py protocol)
    QJsonObject msg;
    msg["type"]  = "synthesize";
    msg["text"]  = req.text;
    msg["rate"]  = static_cast<double>(1.0 + req.prosody.rate * 0.5);  // map [-1,1] → [0.5, 1.5]
    msg["pitch"] = static_cast<double>(1.0 + req.prosody.pitch * 0.3); // map [-1,1] → [0.7, 1.3]
    m_pyWs->sendTextMessage(
        QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact)));

    // Wait for: JSON "start" → binary PCM chunks → JSON "end"
    QElapsedTimer timeout;
    timeout.start();
    bool done = false;
    bool gotStart = false;

    QMetaObject::Connection binConn = connect(m_pyWs, &QWebSocket::binaryMessageReceived,
        this, [this](const QByteArray &data) {
            emit chunk(data);
        });
    QMetaObject::Connection txtConn = connect(m_pyWs, &QWebSocket::textMessageReceived,
        this, [&done, &gotStart](const QString &txtMsg) {
            QJsonDocument d = QJsonDocument::fromJson(txtMsg.toUtf8());
            if (!d.isObject()) return;
            QString type = d.object()["type"].toString();
            if (type == "start")
                gotStart = true;
            else if (type == "end")
                done = true;
            else if (type == "error")
                done = true;  // error terminates as well
        });

    while (!done && timeout.elapsed() < PY_TTS_TIMEOUT_MS && !m_cancelled) {
        QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
    }

    disconnect(binConn);
    disconnect(txtConn);

    if (done || m_cancelled) {
        emit finished();
        return true;
    }
    return false; // timeout
}

// ═══════════════════════════════════════════════════════
//  TTSManager — main-thread orchestrator
// ═══════════════════════════════════════════════════════

TTSManager::TTSManager(QObject *parent)
    : QObject(parent)
{
    m_lastSpeechEnd.start();
}

TTSManager::~TTSManager()
{
    m_workerThread.quit();
    m_workerThread.wait(3000);
}

// ── initialisation ───────────────────────────────────

void TTSManager::initTTS()
{
    // Create worker and move to thread
    m_worker = new TTSWorker();
    m_worker->moveToThread(&m_workerThread);

    // Wire signals: worker → manager (queued across threads)
    connect(&m_workerThread, &QThread::started,
            m_worker, &TTSWorker::init);
    connect(&m_workerThread, &QThread::finished,
            m_worker, &QObject::deleteLater);

    connect(m_worker, &TTSWorker::started,
            this, &TTSManager::onWorkerStarted, Qt::QueuedConnection);
    connect(m_worker, &TTSWorker::chunk,
            this, &TTSManager::onWorkerChunk, Qt::QueuedConnection);
    connect(m_worker, &TTSWorker::finished,
            this, &TTSManager::onWorkerFinished, Qt::QueuedConnection);
    connect(m_worker, &TTSWorker::error,
            this, &TTSManager::onWorkerError, Qt::QueuedConnection);
    connect(m_worker, &TTSWorker::voiceInfo,
            this, [](const QString &name, int count) {
                hVoice() << "TTS worker voix:" << name
                         << "(" << count << "voix disponibles)";
            }, Qt::QueuedConnection);

    // Manager → worker (queued)
    connect(this, &TTSManager::_doRequest,
            m_worker, &TTSWorker::processRequest, Qt::QueuedConnection);
    connect(this, &TTSManager::_doCancelWorker,
            m_worker, &TTSWorker::cancelCurrent, Qt::QueuedConnection);

    m_workerThread.setObjectName("EXO-TTS");
    m_workerThread.start();

    hVoice() << "TTSManager initialisé — thread TTS démarré";
}

void TTSManager::initDSP()
{
    m_sinkFormat.setSampleRate(SAMPLE_RATE);
    m_sinkFormat.setChannelCount(CHANNELS);
    m_sinkFormat.setSampleFormat(QAudioFormat::Int16);

    m_dsp.configure(SAMPLE_RATE);
    hVoice() << "DSP pipeline configuré — EQ 3kHz +3dB, compresseur -18dB 2:1, norm -14dBFS";
}

void TTSManager::initCascade(const QString &pythonWsUrl)
{
    if (!pythonWsUrl.isEmpty() && m_worker) {
        QMetaObject::invokeMethod(m_worker, [this, pythonWsUrl]() {
            m_worker->setPythonWsUrl(pythonWsUrl);
        }, Qt::QueuedConnection);
        hVoice() << "Cascade TTS activée — Python backend:" << pythonWsUrl;
    }
    m_cascadeEnabled = true;
}

// ── prosody analysis ─────────────────────────────────

ProsodyProfile TTSManager::analyzeProsody(const QString &text) const
{
    ProsodyProfile p;
    p.pitch  = m_basePitch;
    p.rate   = m_baseRate;
    p.volume = m_baseEnergy;

    if (text.isEmpty()) return p;

    // Detect sentence type
    bool isQuestion    = text.endsWith('?');
    bool isExclamation = text.endsWith('!');
    int  wordCount     = text.split(QRegularExpression("\\s+"),
                                    Qt::SkipEmptyParts).count();
    bool isShort       = (wordCount <= 5);
    bool isLong        = (wordCount > 30);

    // Detect context keywords (case-insensitive)
    QString low = text.toLower();
    bool isDomotic  = low.contains("lumière") || low.contains("lampe")
                   || low.contains("volet")   || low.contains("chauffage")
                   || low.contains("allume")  || low.contains("éteins");
    bool isWeather  = low.contains("météo")   || low.contains("temps")
                   || low.contains("pluie")   || low.contains("soleil")
                   || low.contains("température");
    bool isReminder = low.contains("rappel")  || low.contains("alarme")
                   || low.contains("timer")   || low.contains("minuteur");
    bool isGreeting = low.contains("bonjour") || low.contains("bonsoir")
                   || low.contains("salut")   || low.contains("bienvenue");

    // Adjust pitch
    if (isQuestion)
        p.pitch += 0.12f;   // rising intonation
    if (isExclamation)
        p.pitch += 0.06f;
    if (isGreeting)
        p.pitch += 0.04f;

    // Adjust rate
    if (isShort)
        p.rate -= 0.05f;    // slightly slower for short confirmations
    if (isLong)
        p.rate += 0.08f;    // speed up long texts
    if (isDomotic)
        p.rate += 0.04f;    // crisp for home commands
    if (isReminder)
        p.rate -= 0.06f;    // slower for important reminders

    // Adjust volume / energy
    if (isExclamation)
        p.volume = std::min(p.volume + 0.08f, 1.0f);
    if (isReminder)
        p.volume = std::min(p.volume + 0.05f, 1.0f);
    if (isWeather)
        p.rate += 0.02f;    // conversational flow for weather

    // Clamp
    p.pitch  = std::clamp(p.pitch,  -1.0f, 1.0f);
    p.rate   = std::clamp(p.rate,   -1.0f, 1.0f);
    p.volume = std::clamp(p.volume,  0.0f, 1.0f);

    return p;
}

QString TTSManager::preprocessText(const QString &raw) const
{
    QString t = raw;
    // Collapse multiple newlines to spaces
    t.replace(QRegularExpression("\\n+"), " ");
    // Remove markdown-like formatting
    t.remove(QRegularExpression("[*_`#]"));
    // Collapse multiple spaces
    t.replace(QRegularExpression("\\s{2,}"), " ");
    return t.trimmed();
}

// ── main API ─────────────────────────────────────────

void TTSManager::speakText(const QString &text)
{
    if (text.isEmpty()) return;

    QString clean = preprocessText(text);
    if (clean.isEmpty()) return;

    ProsodyProfile prosody = analyzeProsody(clean);

    TTSRequest req;
    req.text    = clean;
    req.prosody = prosody;

    hVoice() << "TTS demande — pitch:" << prosody.pitch
             << "rate:" << prosody.rate
             << "vol:" << prosody.volume
             << "texte:" << clean.left(60) << "...";

    // If already speaking, cancel current and enqueue
    if (m_speaking) {
        emit _doCancelWorker();
        // Clear queue (newest wins)
        QMutexLocker lk(&m_queueMutex);
        m_queue.clear();
        m_queue.enqueue(req);
        return;
    }

    // Start immediately
    {
        QMutexLocker lk(&m_queueMutex);
        m_queue.enqueue(req);
    }
    processQueue();
}

void TTSManager::cancelSpeech()
{
    {
        QMutexLocker lk(&m_queueMutex);
        m_queue.clear();
    }
    emit _doCancelWorker();
    stopSink();

    if (m_speaking) {
        m_speaking = false;
        m_lastSpeechEnd.restart();
        emit speakingChanged();
        emit ttsFinished();
        broadcastState("idle");
    }
}

void TTSManager::processQueue()
{
    QMutexLocker lk(&m_queueMutex);
    if (m_queue.isEmpty() || m_speaking) return;

    TTSRequest req = m_queue.dequeue();
    lk.unlock();

    m_dsp.reset();
    startSink();
    emit _doRequest(req);
}

// ── worker callbacks (main thread) ───────────────────

void TTSManager::onWorkerStarted(const QString &text)
{
    m_speaking = true;
    emit ttsStarted();
    emit speakingChanged();
    emit statusChanged("Parle...");
    broadcastState("speaking");
    hVoice() << "TTS démarré:" << text.left(50);
}

void TTSManager::onWorkerChunk(const QByteArray &pcm)
{
    // Apply DSP to chunk
    QByteArray processed = pcm;
    m_dsp.process(reinterpret_cast<int16_t *>(processed.data()),
                  processed.size() / static_cast<int>(sizeof(int16_t)),
                  false);

    feedSink(processed);
    broadcastWaveform(processed);
    emit ttsChunk(processed);
}

void TTSManager::onWorkerFinished()
{
    stopSink();
    m_speaking = false;
    m_lastSpeechEnd.restart();
    emit ttsFinished();
    emit speakingChanged();
    emit statusChanged("Prêt");
    broadcastState("idle");
    hVoice() << "TTS terminé";

    // Process next in queue
    QTimer::singleShot(100, this, &TTSManager::processQueue);
}

void TTSManager::onWorkerError(const QString &msg)
{
    hVoice() << "TTS erreur:" << msg;
    emit ttsError(msg);

    // Try next in queue anyway
    m_speaking = false;
    m_lastSpeechEnd.restart();
    emit speakingChanged();
    broadcastState("idle");
    QTimer::singleShot(200, this, &TTSManager::processQueue);
}

// ── streaming audio output ───────────────────────────

void TTSManager::startSink()
{
    // QAudioSink for direct PCM playback
    const QAudioDevice dev = QMediaDevices::defaultAudioOutput();
    if (dev.isNull()) {
        hVoice() << "Pas de sortie audio disponible";
        return;
    }

    m_sink = std::make_unique<QAudioSink>(dev, m_sinkFormat);
    m_sinkIO = m_sink->start();
}

void TTSManager::feedSink(const QByteArray &pcm)
{
    if (m_sinkIO && !pcm.isEmpty())
        m_sinkIO->write(pcm);
}

void TTSManager::stopSink()
{
    if (m_sink) {
        m_sink->stop();
        m_sink.reset();
    }
    m_sinkIO = nullptr;
}

// ── tuning ───────────────────────────────────────────

void TTSManager::setVoice(const QString &name)
{
    if (m_worker)
        QMetaObject::invokeMethod(m_worker, [this, name]() {
            m_worker->setVoice(name);
        }, Qt::QueuedConnection);
}

void TTSManager::setRate(float r)   { m_baseRate   = std::clamp(r, -1.0f, 1.0f); }
void TTSManager::setPitch(float p)  { m_basePitch  = std::clamp(p, -1.0f, 1.0f); }
void TTSManager::setEnergy(float e) { m_baseEnergy = std::clamp(e, 0.0f, 1.0f); }
void TTSManager::setDSPEnabled(bool on) { m_dsp.setEnabled(on); }
void TTSManager::setCascadeEnabled(bool on) { m_cascadeEnabled = on; }

// ── WebSocket ────────────────────────────────────────

void TTSManager::setWebSocket(QWebSocket *ws)
{
    m_ws = ws;
}

qint64 TTSManager::msSinceLastSpeech() const
{
    return m_lastSpeechEnd.elapsed();
}

void TTSManager::broadcastWaveform(const QByteArray &pcm)
{
    if (!m_ws || m_ws->state() != QAbstractSocket::ConnectedState)
        return;

    // Downsample waveform for GUI: send RMS of every 320 samples (~20ms)
    const int16_t *samples = reinterpret_cast<const int16_t *>(pcm.constData());
    int count = pcm.size() / static_cast<int>(sizeof(int16_t));

    QJsonArray waveform;
    constexpr int BLOCK = 320;
    for (int offset = 0; offset < count; offset += BLOCK) {
        int end = std::min(offset + BLOCK, count);
        double sumSq = 0;
        for (int i = offset; i < end; ++i) {
            double v = samples[i] / 32768.0;
            sumSq += v * v;
        }
        double rms = std::sqrt(sumSq / (end - offset));
        waveform.append(QJsonValue(rms));
    }

    QJsonObject msg;
    msg["type"]     = "tts_waveform";
    msg["waveform"] = waveform;
    m_ws->sendTextMessage(
        QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact)));
}

void TTSManager::broadcastState(const QString &state)
{
    if (!m_ws || m_ws->state() != QAbstractSocket::ConnectedState)
        return;

    QJsonObject msg;
    msg["type"]  = "tts_state";
    msg["state"] = state;
    m_ws->sendTextMessage(
        QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact)));
}
