#include "TTSManager.h"
#include "TTSBackend.h"
#include "TTSBackendQt.h"
#include "TTSBackendXTTS.h"
#include "core/LogManager.h"
#include "core/PipelineEvent.h"

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
    // XTTS v2 produces well-normalized audio — lighter DSP
    m_eq.configure(sampleRate, 3000.0f, 1.5f, 1.0f);  // gentle presence boost
    m_comp.configure(sampleRate, -14.0f, 1.8f, 5.0f, 50.0f); // softer compression
    m_norm.setTargetDb(-16.0f);
    m_fade.configure(sampleRate, 15.0f, 20.0f); // longer fades for neural TTS
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
//  TTSWorker — backend-based synthesis dispatcher
// ═══════════════════════════════════════════════════════

TTSWorker::TTSWorker(QObject *parent)
    : QObject(parent)
{}

TTSWorker::~TTSWorker()
{
    qWarning() << "[TTS] TTSWorker détruit";
}

void TTSWorker::resetPythonConnection()
{
    if (m_xttsBackend)
        m_xttsBackend->resetConnection();
}

void TTSWorker::init(const QString &pythonWsUrl)
{
    // Create XTTS backend (Python) — priority 1
    m_xttsBackend = new TTSBackendXTTS(this);
    m_xttsBackend->setCancelled(&m_cancelled);
    if (!pythonWsUrl.isEmpty())
        m_xttsBackend->setUrl(pythonWsUrl);
    connect(m_xttsBackend, &TTSBackend::started,  this, &TTSWorker::started);
    connect(m_xttsBackend, &TTSBackend::chunk,    this, &TTSWorker::chunk);
    connect(m_xttsBackend, &TTSBackend::finished, this, &TTSWorker::finished);
    connect(m_xttsBackend, &TTSBackend::error,    this, &TTSWorker::error);
    m_backends.append(m_xttsBackend);

    // Create Qt TTS backend — priority 2 (fallback)
    m_qtBackend = new TTSBackendQt(this);
    m_qtBackend->setCancelled(&m_cancelled);
    m_qtBackend->init();
    connect(m_qtBackend, &TTSBackend::started,  this, &TTSWorker::started);
    connect(m_qtBackend, &TTSBackend::chunk,    this, &TTSWorker::chunk);
    connect(m_qtBackend, &TTSBackend::finished, this, &TTSWorker::finished);
    connect(m_qtBackend, &TTSBackend::error,    this, &TTSWorker::error);
    connect(m_qtBackend, &TTSBackendQt::voiceInfo, this, &TTSWorker::voiceInfo);
    m_backends.append(m_qtBackend);

    qWarning() << "[TTS] Worker init:" << m_backends.size() << "backends registered";
    if (!pythonWsUrl.isEmpty())
        qWarning() << "[TTS] Worker init: XTTS URL set:" << pythonWsUrl;
}

void TTSWorker::setVoice(const QString &name)
{
    if (m_qtBackend)
        m_qtBackend->setVoice(name);
    if (m_xttsBackend)
        m_xttsBackend->setVoice(name);
}

void TTSWorker::setPythonWsUrl(const QString &url)
{
    if (m_xttsBackend)
        m_xttsBackend->setUrl(url);
}

void TTSWorker::setXTTSVoice(const QString &name)
{
    if (m_xttsBackend)
        m_xttsBackend->setVoice(name);
    qWarning() << "[TTS] XTTS voice set to:" << name;
}

void TTSWorker::setXTTSLang(const QString &lang)
{
    if (m_xttsBackend)
        m_xttsBackend->setLang(lang);
    qWarning() << "[TTS] XTTS language set to:" << lang;
}

void TTSWorker::processRequest(const TTSRequest &req)
{
    m_cancelled = false;

    // Iterate backends in priority order
    for (TTSBackend *backend : m_backends) {
        if (!backend->isAvailable())
            continue;
        if (backend->synthesize(req))
            return;
    }

    // All engines failed
    emit error("Tous les moteurs TTS ont échoué pour: " + req.text.left(40));
}

void TTSWorker::cancelCurrent()
{
    m_cancelled = true;
    for (TTSBackend *backend : m_backends)
        backend->cancel();
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
    hVoice() << "TTSManager destruction — arrêt thread TTS";
    // Signal worker to exit blocking loops (atomic flag — thread-safe)
    if (m_worker)
        m_worker->requestStop();
    m_workerThread.quit();
    if (!m_workerThread.wait(5000)) {
        hWarning(henriVoice) << "Thread TTS ne répond pas — terminate forcé";
        m_workerThread.terminate();
        m_workerThread.wait(2000);
    }
}

// ── initialisation ───────────────────────────────────

void TTSManager::initTTS(const QString &pythonWsUrl)
{
    // Create worker and move to thread
    m_worker = new TTSWorker();
    m_worker->moveToThread(&m_workerThread);

    // Wire signals: worker → manager (queued across threads)
    // Pass pythonWsUrl directly to init() so it's set BEFORE any TTS request
    connect(&m_workerThread, &QThread::started,
            m_worker, [this, pythonWsUrl]() { m_worker->init(pythonWsUrl); });
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

    m_cascadeEnabled = !pythonWsUrl.isEmpty();
    hVoice() << "TTSManager initialisé — thread TTS démarré";
    if (m_cascadeEnabled)
        hVoice() << "Cascade TTS activée — Python backend:" << pythonWsUrl;
}

void TTSManager::initDSP()
{
    m_sinkFormat.setSampleRate(SAMPLE_RATE);
    m_sinkFormat.setChannelCount(CHANNELS);
    m_sinkFormat.setSampleFormat(QAudioFormat::Int16);

    m_dsp.configure(SAMPLE_RATE);
    hVoice() << "DSP pipeline configuré — EQ 3kHz +1.5dB, compresseur -14dB 1.8:1, norm -16dBFS (XTTS v2)";
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

    // Adjust rate — conservative to avoid accelerated speech on Qt TTS
    if (isShort)
        p.rate -= 0.03f;    // slightly slower for short confirmations
    if (isLong)
        p.rate += 0.03f;    // gentle speedup for long texts
    if (isDomotic)
        p.rate += 0.02f;    // crisp for home commands
    if (isReminder)
        p.rate -= 0.04f;    // slower for important reminders

    // Adjust volume / energy
    if (isExclamation)
        p.volume = std::min(p.volume + 0.08f, 1.0f);
    if (isReminder)
        p.volume = std::min(p.volume + 0.05f, 1.0f);
    if (isWeather)
        p.rate += 0.01f;    // conversational flow for weather

    // Clamp — cap rate to ±0.05 to keep speech natural
    p.pitch  = std::clamp(p.pitch,  -1.0f, 1.0f);
    p.rate   = std::clamp(p.rate,   -0.05f, 0.05f);
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

    PIPELINE_EVENT(PipelineModule::TTS, EventType::SynthesisRequested,
                   {{"text_length", clean.length()},
                    {"pitch", prosody.pitch},
                    {"rate", prosody.rate},
                    {"volume", prosody.volume}});
    PIPELINE_STATE(PipelineModule::TTS, ModuleState::Processing);

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

void TTSManager::enqueueSentence(const QString &text)
{
    if (text.isEmpty()) return;

    QString clean = preprocessText(text);
    if (clean.isEmpty()) return;

    ProsodyProfile prosody = analyzeProsody(clean);

    TTSRequest req;
    req.text    = clean;
    req.prosody = prosody;

    hVoice() << "TTS sentence enqueued:" << clean.left(60) << "...";

    {
        QMutexLocker lk(&m_queueMutex);
        m_queue.enqueue(req);
    }

    PIPELINE_EVENT(PipelineModule::TTS, EventType::SentenceQueued,
                   {{"text_length", clean.length()},
                    {"preview", clean.left(60)}});

    // If not currently speaking, start immediately
    if (!m_speaking)
        processQueue();
}

void TTSManager::cancelSpeech()
{
    PIPELINE_EVENT(PipelineModule::TTS, EventType::SpeechCancelled);
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
    // Guard against re-entrant calls (finalizeSpeech → processQueue while still inside)
    bool expected = false;
    if (!m_processingGuard.compare_exchange_strong(expected, true))
        return;

    QMutexLocker lk(&m_queueMutex);
    if (m_queue.isEmpty() || m_speaking) {
        m_processingGuard = false;
        return;
    }

    TTSRequest req = m_queue.dequeue();
    lk.unlock();

    m_totalPcmBytes = 0;
    m_dsp.reset();
    m_processingGuard = false;
    // Sink will be started lazily on first audio chunk
    emit _doRequest(req);
}

// ── worker callbacks (main thread) ───────────────────

void TTSManager::onWorkerStarted(const QString &text)
{
    m_speaking = true;
    PIPELINE_EVENT(PipelineModule::TTS, EventType::WorkerStarted,
                   {{"text_preview", text.left(50)}});
    emit ttsStarted();
    emit speakingChanged();
    emit statusChanged("Parle...");
    broadcastState("speaking");
    hVoice() << "TTS démarré:" << text.left(50);
}

void TTSManager::onWorkerChunk(const QByteArray &pcm)
{
    PIPELINE_EVENT(PipelineModule::AudioOutput, EventType::PcmChunk,
                   {{"bytes", pcm.size()}});
    // Lazy start sink on first chunk
    if (!m_sink) {
        startSink();
        if (!m_sink || !m_sinkIO) {
            hWarning(henriVoice) << "onWorkerChunk: startSink failed — audio lost ("
                                << pcm.size() << "bytes)";
            return;
        }
    }

    // Apply DSP to chunk
    QByteArray processed = pcm;
    m_dsp.process(reinterpret_cast<int16_t *>(processed.data()),
                  processed.size() / static_cast<int>(sizeof(int16_t)),
                  false);

    m_totalPcmBytes += processed.size();
    hVoice() << "feedSink chunk" << processed.size() << "bytes — total" << m_totalPcmBytes;
    feedSink(processed);
    broadcastWaveform(processed);
    emit ttsChunk(processed);
}

void TTSManager::onWorkerFinished()
{
    // Don't stop sink immediately — let it drain buffered audio
    drainAndStop();
}

void TTSManager::onWorkerError(const QString &msg)
{
    PIPELINE_EVENT(PipelineModule::TTS, EventType::WorkerError, {{"message", msg}});
    PipelineEventBus::instance()->setModuleError(PipelineModule::TTS, msg);
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
    // Guard: prevent double sink initialization
    if (m_sink) {
        hVoice() << "startSink: sink already active — skipping";
        return;
    }

    // QAudioSink for direct PCM playback
    const QAudioDevice dev = QMediaDevices::defaultAudioOutput();
    if (dev.isNull()) {
        hVoice() << "Pas de sortie audio disponible";
        return;
    }

    hVoice() << "startSink — device:" << dev.description()
             << "format:" << m_sinkFormat.sampleRate() << "Hz"
             << m_sinkFormat.channelCount() << "ch Int16";

    m_draining = false;
    m_pcmBuffer.clear();

    m_sink = std::make_unique<QAudioSink>(dev, m_sinkFormat);
    connect(m_sink.get(), &QAudioSink::stateChanged,
            this, &TTSManager::onSinkStateChanged);
    m_sinkIO = m_sink->start();

    if (!m_sinkIO) {
        hWarning(henriVoice) << "ERREUR: QAudioSink::start() a retourné nullptr!";
        m_sink->stop();
        m_sink.reset();
        return;
    }

    // Timer to pump PCM buffer → sink at a steady pace
    if (!m_pumpTimer) {
        m_pumpTimer = new QTimer(this);
        m_pumpTimer->setInterval(20); // pump every 20 ms
        connect(m_pumpTimer, &QTimer::timeout, this, &TTSManager::pumpBuffer);
    }
    m_pumpTimer->start();

    hVoice() << "QAudioSink démarré — bufferSize:" << m_sink->bufferSize();
}

void TTSManager::feedSink(const QByteArray &pcm)
{
    if (!pcm.isEmpty())
        m_pcmBuffer.append(pcm);
}

void TTSManager::pumpBuffer()
{
    if (!m_sinkIO) {
        if (m_draining && m_pcmBuffer.isEmpty()) {
            if (m_pumpTimer) m_pumpTimer->stop();
            finalizeSpeech();
        }
        return;
    }
    if (m_pcmBuffer.isEmpty()) {
        // If draining and buffer is empty, let sink play out remaining data
        if (m_draining) {
            if (m_pumpTimer) m_pumpTimer->stop();
            // Sink will go IdleState when its internal buffer empties
            // Check immediately in case it's already idle
            if (m_sink && m_sink->state() == QAudio::IdleState) {
                finalizeSpeech();
            }
        }
        return;
    }

    // Write as much as the sink will accept
    qint64 written = m_sinkIO->write(m_pcmBuffer);
    if (written > 0)
        m_pcmBuffer.remove(0, static_cast<int>(written));
}

void TTSManager::stopSink()
{
    if (m_pumpTimer) m_pumpTimer->stop();
    m_pcmBuffer.clear();
    if (m_sink) {
        m_sink->stop();
        m_sink.reset();
    }
    m_sinkIO = nullptr;
    m_draining = false;
}

void TTSManager::drainAndStop()
{
    hVoice() << "drainAndStop — buffer:" << m_pcmBuffer.size() << "bytes, totalPcm:" << m_totalPcmBytes;
    m_draining = true;
    // If no pending data and sink idle (or absent), finalize now
    if (m_pcmBuffer.isEmpty() && (!m_sink || m_sink->state() == QAudio::IdleState)) {
        finalizeSpeech();
        return;
    }
    // pumpBuffer() will continue feeding; onSinkStateChanged handles finalization
    // Safety timer: force stop after 30 seconds
    QTimer::singleShot(30000, this, [this]() {
        if (m_draining) {
            hVoice() << "Drain timeout — forçage arrêt audio";
            finalizeSpeech();
        }
    });
}

void TTSManager::onSinkStateChanged(QAudio::State state)
{
    if (state == QAudio::IdleState && m_draining && m_pcmBuffer.isEmpty()) {
        finalizeSpeech();
    }
}

void TTSManager::finalizeSpeech()
{
    hVoice() << "finalizeSpeech — remaining buffer:" << m_pcmBuffer.size() << "bytes";
    PIPELINE_EVENT(PipelineModule::TTS, EventType::SpeechFinalized,
                   {{"total_pcm_bytes", m_totalPcmBytes}});
    PIPELINE_STATE(PipelineModule::TTS, ModuleState::Idle);
    PIPELINE_STATE(PipelineModule::AudioOutput, ModuleState::Idle);
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

// ── tuning ───────────────────────────────────────────

void TTSManager::setVoice(const QString &name)
{
    m_voiceName = name;
    if (m_worker)
        QMetaObject::invokeMethod(m_worker, [this, name]() {
            m_worker->setVoice(name);
            m_worker->setXTTSVoice(name);
        }, Qt::QueuedConnection);
}

void TTSManager::setRate(float r)   { m_baseRate   = std::clamp(r, -1.0f, 1.0f); }
void TTSManager::setPitch(float p)  { m_basePitch  = std::clamp(p, -1.0f, 1.0f); }
void TTSManager::setEnergy(float e) { m_baseEnergy = std::clamp(e, 0.0f, 1.0f); }
void TTSManager::setStyle(const QString &s) { m_baseStyle = s; }
void TTSManager::setLanguage(const QString &lang)
{
    m_language = lang;
    if (m_worker)
        QMetaObject::invokeMethod(m_worker, [this, lang]() {
            m_worker->setXTTSLang(lang);
        }, Qt::QueuedConnection);
}
void TTSManager::setDSPEnabled(bool on) { m_dsp.setEnabled(on); }
void TTSManager::setCascadeEnabled(bool on) { m_cascadeEnabled = on; }

void TTSManager::setPythonUrl(const QString &url)
{
    hVoice() << "TTS setPythonUrl:" << url;
    if (m_worker) {
        QMetaObject::invokeMethod(m_worker, [this, url]() {
            m_worker->resetPythonConnection();
            m_worker->setPythonWsUrl(url);
        }, Qt::QueuedConnection);
    }
    m_cascadeEnabled = !url.isEmpty();
}

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
