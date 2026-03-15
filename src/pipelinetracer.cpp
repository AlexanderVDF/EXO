#include "pipelinetracer.h"
#include "logmanager.h"
#include <QJsonArray>
#include <QJsonDocument>

// ─────────────────────────────────────────────────────
//  InteractionSummary::toJson
// ─────────────────────────────────────────────────────

QJsonObject InteractionSummary::toJson() const
{
    QJsonObject obj;
    obj["correlation_id"] = correlationId;
    obj["total_ms"]       = totalMs;
    obj["vad_ms"]         = vadMs;
    obj["stt_ms"]         = sttMs;
    obj["llm_ms"]         = llmMs;
    obj["llm_first_token_ms"] = llmFirstToken;
    obj["tts_ms"]         = ttsMs;
    obj["playback_ms"]    = playbackMs;
    obj["sentence_count"] = sentenceCount;
    obj["event_count"]    = eventCount;
    if (!anomalies.isEmpty()) {
        QJsonArray arr;
        for (const auto &a : anomalies) arr.append(a);
        obj["anomalies"] = arr;
    }
    return obj;
}

// ─────────────────────────────────────────────────────
//  PipelineTracer — singleton
// ─────────────────────────────────────────────────────

PipelineTracer* PipelineTracer::s_instance = nullptr;

PipelineTracer* PipelineTracer::instance()
{
    if (!s_instance)
        s_instance = new PipelineTracer();
    return s_instance;
}

PipelineTracer::PipelineTracer(QObject *parent)
    : QObject(parent)
{
    // Auto-connect au bus d'événements
    connect(PipelineEventBus::instance(), &PipelineEventBus::interactionEnded,
            this, &PipelineTracer::onInteractionEnded);
    connect(PipelineEventBus::instance(), &PipelineEventBus::interactionStarted,
            this, &PipelineTracer::onInteractionStarted);

    // Watchdog pour interactions orphelines
    m_orphanTimer = new QTimer(this);
    m_orphanTimer->setSingleShot(true);
    connect(m_orphanTimer, &QTimer::timeout, this, &PipelineTracer::checkOrphanInteraction);
}

// ─────────────────────────────────────────────────────
//  Helpers — recherche d'événements dans la trace
// ─────────────────────────────────────────────────────

qint64 PipelineTracer::firstEventMs(const InteractionTrace &trace,
                                     const QString &module,
                                     const QString &eventType) const
{
    for (const auto &evt : trace.events) {
        if (PipelineEvent::moduleToString(evt.module) == module &&
            evt.eventType == eventType)
            return evt.elapsedMs;
    }
    return -1;
}

qint64 PipelineTracer::lastEventMs(const InteractionTrace &trace,
                                    const QString &module,
                                    const QString &eventType) const
{
    qint64 last = -1;
    for (const auto &evt : trace.events) {
        if (PipelineEvent::moduleToString(evt.module) == module &&
            evt.eventType == eventType)
            last = evt.elapsedMs;
    }
    return last;
}

int PipelineTracer::countEvents(const InteractionTrace &trace,
                                const QString &module,
                                const QString &eventType) const
{
    int count = 0;
    for (const auto &evt : trace.events) {
        if (PipelineEvent::moduleToString(evt.module) == module &&
            evt.eventType == eventType)
            ++count;
    }
    return count;
}

// ─────────────────────────────────────────────────────
//  assembleTimeline — segments par module
// ─────────────────────────────────────────────────────

QVector<TimelineSegment> PipelineTracer::assembleTimeline(const InteractionTrace &trace) const
{
    QVector<TimelineSegment> segments;

    // VAD: speech_started → speech_ended
    qint64 vadStart = firstEventMs(trace, "vad", "speech_started");
    qint64 vadEnd   = firstEventMs(trace, "vad", "speech_ended");
    if (vadStart >= 0) {
        TimelineSegment seg;
        seg.moduleName = "vad";
        seg.startMs = vadStart;
        seg.endMs = vadEnd >= 0 ? vadEnd : vadStart;
        segments.append(seg);
    }

    // STT: partial_transcript (first) → final_transcript
    qint64 sttStart = firstEventMs(trace, "stt", "partial_transcript");
    if (sttStart < 0) sttStart = firstEventMs(trace, "stt", "utterance_finished");
    qint64 sttEnd = firstEventMs(trace, "stt", "final_transcript");
    if (sttStart >= 0) {
        TimelineSegment seg;
        seg.moduleName = "stt";
        seg.startMs = sttStart;
        seg.endMs = sttEnd >= 0 ? sttEnd : sttStart;
        segments.append(seg);
    }

    // Claude: request_started → response_received (ou final_response)
    qint64 llmStart = firstEventMs(trace, "claude", "request_started");
    qint64 llmEnd   = firstEventMs(trace, "claude", "response_received");
    if (llmEnd < 0) llmEnd = firstEventMs(trace, "claude", "final_response");
    if (llmStart >= 0) {
        TimelineSegment seg;
        seg.moduleName = "claude";
        seg.startMs = llmStart;
        seg.endMs = llmEnd >= 0 ? llmEnd : llmStart;
        segments.append(seg);
    }

    // TTS: synthesis_requested → speech_finalized
    qint64 ttsStart = firstEventMs(trace, "tts", "synthesis_requested");
    if (ttsStart < 0) ttsStart = firstEventMs(trace, "tts", "sentence_enqueued");
    if (ttsStart < 0) ttsStart = firstEventMs(trace, "tts", "worker_started");
    qint64 ttsEnd = lastEventMs(trace, "tts", "speech_finalized");
    if (ttsEnd < 0) ttsEnd = lastEventMs(trace, "tts", "playback_finished");
    if (ttsStart >= 0) {
        TimelineSegment seg;
        seg.moduleName = "tts";
        seg.startMs = ttsStart;
        seg.endMs = ttsEnd >= 0 ? ttsEnd : ttsStart;
        segments.append(seg);
    }

    // Playback: playback_started → playback_finished
    qint64 pbStart = firstEventMs(trace, "tts", "playback_started");
    qint64 pbEnd   = lastEventMs(trace, "tts", "playback_finished");
    if (pbStart >= 0) {
        TimelineSegment seg;
        seg.moduleName = "audio_output";
        seg.startMs = pbStart;
        seg.endMs = pbEnd >= 0 ? pbEnd : pbStart;
        segments.append(seg);
    }

    return segments;
}

// ─────────────────────────────────────────────────────
//  detectAnomalies — anomalies dans la trace
// ─────────────────────────────────────────────────────

QStringList PipelineTracer::detectAnomalies(const InteractionTrace &trace) const
{
    QStringList anomalies;
    auto timeline = assembleTimeline(trace);

    for (const auto &seg : timeline) {
        qint64 dur = seg.durationMs();

        if (seg.moduleName == "stt" && dur > m_sttThreshold)
            anomalies << QString("SLOW_STT: %1ms (seuil: %2ms)").arg(dur).arg(m_sttThreshold);

        if (seg.moduleName == "claude" && dur > m_llmThreshold)
            anomalies << QString("SLOW_LLM: %1ms (seuil: %2ms)").arg(dur).arg(m_llmThreshold);

        if (seg.moduleName == "tts" && dur > m_ttsThreshold)
            anomalies << QString("SLOW_TTS: %1ms (seuil: %2ms)").arg(dur).arg(m_ttsThreshold);
    }

    // Pas de réponse Claude
    if (firstEventMs(trace, "claude", "request_started") >= 0 &&
        firstEventMs(trace, "claude", "response_received") < 0 &&
        firstEventMs(trace, "claude", "final_response") < 0)
        anomalies << "NO_RESPONSE: Claude request sans response";

    // Double TTS (sentence_enqueued > 1 mais worker_started > 1 sans queue drain)
    int workerStarts = countEvents(trace, "tts", "worker_started");
    int speechFinalized = countEvents(trace, "tts", "speech_finalized");
    if (workerStarts > 1 && speechFinalized > 1)
        anomalies << QString("MULTI_TTS: %1 synthèses, %2 finalisations").arg(workerStarts).arg(speechFinalized);

    // Timeout total
    if (trace.durationMs() > m_totalThreshold)
        anomalies << QString("TOTAL_TIMEOUT: %1ms (seuil: %2ms)").arg(trace.durationMs()).arg(m_totalThreshold);

    return anomalies;
}

// ─────────────────────────────────────────────────────
//  buildSummary — résumé complet
// ─────────────────────────────────────────────────────

InteractionSummary PipelineTracer::buildSummary(const InteractionTrace &trace) const
{
    InteractionSummary s;
    s.correlationId = trace.correlationId;
    s.totalMs       = trace.durationMs();
    s.eventCount    = trace.events.size();

    auto timeline = assembleTimeline(trace);
    for (const auto &seg : timeline) {
        if (seg.moduleName == "vad")          s.vadMs      = seg.durationMs();
        else if (seg.moduleName == "stt")     s.sttMs      = seg.durationMs();
        else if (seg.moduleName == "claude")  s.llmMs      = seg.durationMs();
        else if (seg.moduleName == "tts")     s.ttsMs      = seg.durationMs();
        else if (seg.moduleName == "audio_output") s.playbackMs = seg.durationMs();
    }

    // First token latency
    qint64 reqStart = firstEventMs(trace, "claude", "request_started");
    qint64 firstPartial = firstEventMs(trace, "claude", "partial_response");
    if (reqStart >= 0 && firstPartial >= 0)
        s.llmFirstToken = firstPartial - reqStart;

    // Sentence count
    s.sentenceCount = countEvents(trace, "tts", "sentence_enqueued")
                    + countEvents(trace, "tts", "synthesis_requested");

    // Anomalies
    s.anomalies = detectAnomalies(trace);

    return s;
}

// ─────────────────────────────────────────────────────
//  onInteractionEnded — auto-analyze
// ─────────────────────────────────────────────────────

void PipelineTracer::onInteractionEnded(const QString &correlationId, qint64 durationMs)
{
    Q_UNUSED(durationMs);

    // Stop orphan watchdog
    m_orphanTimer->stop();
    m_activeCorrelationId.clear();

    // Retrouver la trace dans l'historique du bus
    auto traces = PipelineEventBus::instance()->recentTraces(1);
    if (traces.isEmpty()) return;

    const InteractionTrace &trace = traces.last();
    if (trace.correlationId != correlationId) return;

    InteractionSummary summary = buildSummary(trace);

    // Stocker
    m_summaries.append(summary);
    while (m_summaries.size() > MAX_SUMMARIES)
        m_summaries.removeFirst();

    // Log structuré
    hLog() << QString("[TRACER] === Interaction %1 ===").arg(correlationId);
    hLog() << QString("[TRACER]   Total: %1ms | VAD: %2ms | STT: %3ms | LLM: %4ms | TTS: %5ms | Playback: %6ms")
              .arg(summary.totalMs).arg(summary.vadMs).arg(summary.sttMs)
              .arg(summary.llmMs).arg(summary.ttsMs).arg(summary.playbackMs);
    if (summary.llmFirstToken > 0)
        hLog() << QString("[TRACER]   LLM first token: %1ms | Sentences: %2")
                  .arg(summary.llmFirstToken).arg(summary.sentenceCount);

    // Anomalies
    for (const auto &anomaly : summary.anomalies) {
        hLog() << QString("[TRACER]   ⚠ %1").arg(anomaly);
        emit anomalyDetected(anomaly, correlationId);
    }

    emit summaryReady(summary.toJson());
}

// ─────────────────────────────────────────────────────
//  Orphan interaction watchdog
// ─────────────────────────────────────────────────────

void PipelineTracer::onInteractionStarted(const QString &correlationId)
{
    m_activeCorrelationId = correlationId;
    m_orphanTimer->start(ORPHAN_TIMEOUT_MS);
}

void PipelineTracer::checkOrphanInteraction()
{
    QString cid = PipelineEventBus::instance()->currentCorrelationId();
    if (!cid.isEmpty() && cid == m_activeCorrelationId) {
        hLog() << QString("[TRACER] ⚠ Interaction orpheline détectée — ID: %1 — fermeture forcée après %2s")
                  .arg(cid).arg(ORPHAN_TIMEOUT_MS / 1000);
        PIPELINE_EVENT(PipelineModule::Orchestrator, "orphan_interaction_closed",
                       {{"correlation_id", cid}, {"timeout_ms", ORPHAN_TIMEOUT_MS}});
        PipelineEventBus::instance()->endInteraction(cid);
        emit anomalyDetected("ORPHAN_INTERACTION: forcé après timeout", cid);
    }
    m_activeCorrelationId.clear();
}

// ─────────────────────────────────────────────────────
//  QML API
// ─────────────────────────────────────────────────────

QJsonArray PipelineTracer::getRecentSummaries(int maxCount) const
{
    QJsonArray arr;
    int start = qMax(0, m_summaries.size() - maxCount);
    for (int i = start; i < m_summaries.size(); ++i)
        arr.append(m_summaries[i].toJson());
    return arr;
}

QJsonObject PipelineTracer::getLastSummary() const
{
    if (m_summaries.isEmpty())
        return {};
    return m_summaries.last().toJson();
}
