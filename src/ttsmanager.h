#ifndef TTSMANAGER_H
#define TTSMANAGER_H

#include <QObject>
#include <QAudioSink>
#include <QAudioFormat>
#include <QAudioDevice>
#include <QMediaDevices>
#include <QTextToSpeech>
#include <QWebSocket>
#include <QThread>
#include <QMutex>
#include <QQueue>
#include <QTimer>
#include <QElapsedTimer>
#include <QBuffer>
#include <QJsonObject>
#include <QJsonDocument>
#include <memory>
#include <vector>
#include <cstdint>
#include <cmath>
#include <atomic>

// ─────────────────────────────────────────────────────
//  ProsodyProfile — pitch / rate / volume per utterance
// ─────────────────────────────────────────────────────
struct ProsodyProfile
{
    float pitch  = 0.0f;   // -1.0 … +1.0
    float rate   = 0.0f;   // -1.0 … +1.0
    float volume = 0.8f;   //  0.0 … 1.0
};

// ─────────────────────────────────────────────────────
//  TTSEqualizer — 2nd-order peak EQ (presence band)
// ─────────────────────────────────────────────────────
class TTSEqualizer
{
public:
    void configure(int sampleRate, float centerHz = 3000.0f,
                   float gainDb = 3.0f, float q = 1.0f);
    void process(float *samples, int count);
    void reset();

private:
    double m_b0=1, m_b1=0, m_b2=0, m_a1=0, m_a2=0;
    double m_x1=0, m_x2=0, m_y1=0, m_y2=0;
};

// ─────────────────────────────────────────────────────
//  TTSCompressor — soft-knee downward compressor
// ─────────────────────────────────────────────────────
class TTSCompressor
{
public:
    void configure(int sampleRate, float thresholdDb = -18.0f,
                   float ratio = 2.0f, float attackMs = 5.0f,
                   float releaseMs = 50.0f);
    void process(float *samples, int count);
    void reset();

private:
    float m_threshold = -18.0f;
    float m_ratio     = 2.0f;
    float m_attack    = 0.0f;   // coefficient
    float m_release   = 0.0f;   // coefficient
    float m_envelope  = 0.0f;
};

// ─────────────────────────────────────────────────────
//  TTSNormalizer — peak / RMS normalization
// ─────────────────────────────────────────────────────
class TTSNormalizer
{
public:
    void setTargetDb(float dBFS) { m_targetDb = dBFS; }
    void process(float *samples, int count);

private:
    float m_targetDb = -14.0f;
};

// ─────────────────────────────────────────────────────
//  TTSFade — fade-in / fade-out anti-click
// ─────────────────────────────────────────────────────
class TTSFade
{
public:
    void configure(int sampleRate, float fadeInMs = 5.0f,
                   float fadeOutMs = 10.0f);
    void applyFadeIn(float *samples, int count);
    void applyFadeOut(float *samples, int count);

private:
    int m_fadeInSamples  = 80;
    int m_fadeOutSamples = 160;
};

// ─────────────────────────────────────────────────────
//  TTSDSPProcessor — modular DSP chain
//
//  Pipeline : EQ → Compressor → Normalizer → Fade
//  Operates on float buffer (normalized -1..+1)
// ─────────────────────────────────────────────────────
class TTSDSPProcessor
{
public:
    void configure(int sampleRate);
    void process(int16_t *pcm, int count, bool isFinalChunk = false);
    void reset();

    void setEnabled(bool on)       { m_enabled = on; }
    bool isEnabled() const         { return m_enabled; }
    void setEQGainDb(float db);
    void setCompressorThreshold(float db);
    void setNormTarget(float dBFS);

private:
    bool m_enabled = true;
    int  m_sampleRate = 16000;

    TTSEqualizer   m_eq;
    TTSCompressor  m_comp;
    TTSNormalizer  m_norm;
    TTSFade        m_fade;
    bool m_firstChunk = true;
};

// ─────────────────────────────────────────────────────
//  TTSRequest — queued item
// ─────────────────────────────────────────────────────
struct TTSRequest
{
    QString text;
    ProsodyProfile prosody;
    int retries = 0;
};

// ─────────────────────────────────────────────────────
//  TTSWorker — runs on dedicated QThread
//
//  Handles Qt TextToSpeech and Python backend calls.
//  Emits chunks of PCM16 data for streaming playback.
// ─────────────────────────────────────────────────────
class TTSWorker : public QObject
{
    Q_OBJECT
public:
    explicit TTSWorker(QObject *parent = nullptr);
    ~TTSWorker();

public slots:
    void init(const QString &pythonWsUrl = {});
    void processRequest(const TTSRequest &req);
    void cancelCurrent();
    void setVoice(const QString &name);
    void setPythonWsUrl(const QString &url);
    void setXTTSVoice(const QString &name);
    void setXTTSLang(const QString &lang);

signals:
    void started(const QString &text);
    void chunk(const QByteArray &pcm);
    void finished();
    void error(const QString &msg);
    void voiceInfo(const QString &name, int voiceCount);

public:
    void requestStop() { m_cancelled = true; }

private:
    bool tryPythonTTS(const TTSRequest &req);
    bool tryQtTTS(const TTSRequest &req);

    QTextToSpeech *m_tts = nullptr;
    QWebSocket    *m_pyWs = nullptr;
    QString  m_pyWsUrl;
    std::atomic<bool> m_cancelled{false};
    bool     m_pyConnected = false;
    bool     m_pyReadyReceived = false;
    QString  m_xttsVoice = "Claribel Dervla";
    QString  m_xttsLang  = "fr";

    static constexpr int QT_TTS_TIMEOUT_MS   = 30000;
    static constexpr int PY_TTS_TIMEOUT_MS   = 12000;  // idle timeout, reset on each chunk
    static constexpr int MAX_RETRIES          = 2;

    void resetPythonConnection();
};

// ─────────────────────────────────────────────────────
//  TTSManager — public-facing TTS orchestrator
//
//  • Prosody analysis (question / exclamation / context)
//  • Queue management  (cancel-on-new, drain)
//  • DSP post-processing
//  • Streaming playback via QAudioSink
//  • WebSocket broadcast (waveform + state) to React GUI
//
//  Thread layout :
//    main thread  → TTSManager (queue, prosody, DSP, sink)
//        ↓ signal
//    worker thread → TTSWorker  (Qt TTS + Python backend)
// ─────────────────────────────────────────────────────
class TTSManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isSpeaking READ isSpeaking NOTIFY speakingChanged)

public:
    explicit TTSManager(QObject *parent = nullptr);
    ~TTSManager();

    // ── lifecycle ──
    void initTTS(const QString &pythonWsUrl = {});
    void initDSP();

    // ── main API ──
    Q_INVOKABLE void speakText(const QString &text);
    Q_INVOKABLE void enqueueSentence(const QString &text);
    Q_INVOKABLE void cancelSpeech();

    // ── state ──
    bool isSpeaking() const { return m_speaking; }

    // ── tuning ──
    Q_INVOKABLE void setVoice(const QString &name);
    Q_INVOKABLE void setRate(float r);
    Q_INVOKABLE void setPitch(float p);
    Q_INVOKABLE void setEnergy(float e);
    Q_INVOKABLE void setStyle(const QString &s);
    Q_INVOKABLE void setLanguage(const QString &lang);
    Q_INVOKABLE void setDSPEnabled(bool on);
    Q_INVOKABLE void setCascadeEnabled(bool on);

    // ── WebSocket bridge (for React GUI) ──
    void setWebSocket(QWebSocket *ws);

    // ── elapsed since last speech ended (for guard timing) ──
    qint64 msSinceLastSpeech() const;

signals:
    void ttsStarted();
    void ttsChunk(const QByteArray &pcm);
    void ttsFinished();
    void speakingChanged();
    void ttsError(const QString &msg);
    void statusChanged(const QString &status);

    // internal → worker thread
    void _doRequest(const TTSRequest &req);
    void _doCancelWorker();

private slots:
    void onWorkerStarted(const QString &text);
    void onWorkerChunk(const QByteArray &pcm);
    void onWorkerFinished();
    void onWorkerError(const QString &msg);
    void processQueue();

private:
    // ── prosody ──
    ProsodyProfile analyzeProsody(const QString &text) const;
    QString preprocessText(const QString &raw) const;

    // ── streaming playback ──
    void startSink();
    void feedSink(const QByteArray &pcm);
    void pumpBuffer();
    void stopSink();
    void drainAndStop();
    void finalizeSpeech();
    void onSinkStateChanged(QAudio::State state);
    void broadcastWaveform(const QByteArray &pcm);
    void broadcastState(const QString &state);

    // ── state ──
    std::atomic<bool> m_speaking{false};
    std::atomic<bool> m_processingGuard{false}; // prevents re-entrant processQueue
    bool m_draining = false;
    bool m_cascadeEnabled = true;
    float m_baseRate   = 0.0f;
    float m_basePitch  = 0.0f;
    float m_baseEnergy = 0.8f;
    QString m_baseStyle = "neutral";
    QString m_voiceName = "Claribel Dervla";
    QString m_language  = "fr";

    // ── queue ──
    QMutex m_queueMutex;
    QQueue<TTSRequest> m_queue;

    // ── DSP ──
    TTSDSPProcessor m_dsp;

    // ── audio output ──
    QAudioFormat m_sinkFormat;
    std::unique_ptr<QAudioSink> m_sink;
    QIODevice *m_sinkIO = nullptr;
    QByteArray m_pcmBuffer;    // intermediate PCM accumulator
    QTimer    *m_pumpTimer = nullptr; // feeds sink from m_pcmBuffer
    qint64     m_totalPcmBytes = 0;  // diagnostic counter

    // ── worker thread ──
    QThread      m_workerThread;
    TTSWorker   *m_worker = nullptr;

    // ── timers ──
    QElapsedTimer m_lastSpeechEnd;

    // ── WebSocket ──
    QWebSocket *m_ws = nullptr;

    // ── constants ──
    static constexpr int SAMPLE_RATE     = 24000; // XTTS v2 native rate
    static constexpr int CHANNELS        = 1;
    static constexpr int BITS_PER_SAMPLE = 16;
};

#endif // TTSMANAGER_H
