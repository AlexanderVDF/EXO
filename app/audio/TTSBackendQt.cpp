#include "TTSBackendQt.h"
#include "TTSManager.h"

#include <QTextToSpeech>
#include <QCoreApplication>
#include <QElapsedTimer>

TTSBackendQt::TTSBackendQt(QObject *parent)
    : TTSBackend(parent)
{}

TTSBackendQt::~TTSBackendQt()
{
    delete m_tts;
}

void TTSBackendQt::init()
{
    m_tts = new QTextToSpeech();

    QVoice selected;
    int voiceCount = 0;
    for (const QVoice &v : m_tts->availableVoices()) {
        ++voiceCount;
        if (v.locale().language() == QLocale::French) {
            selected = v;
            if (v.name().contains("Julie", Qt::CaseInsensitive))
                break;
            if (v.name().contains("Hortense", Qt::CaseInsensitive))
                continue;
        }
    }
    if (!selected.name().isEmpty())
        m_tts->setVoice(selected);

    emit voiceInfo(selected.name().isEmpty() ? "default" : selected.name(),
                   voiceCount);
}

bool TTSBackendQt::isAvailable() const
{
    return m_tts != nullptr;
}

bool TTSBackendQt::synthesize(const TTSRequest &req)
{
    if (!m_tts) return false;

    // Apply prosody
    m_tts->setPitch(static_cast<double>(req.prosody.pitch));
    m_tts->setRate(static_cast<double>(req.prosody.rate));
    m_tts->setVolume(static_cast<double>(req.prosody.volume));

    emit started(req.text);

    m_tts->say(req.text);

    QElapsedTimer timeout;
    timeout.start();

    bool wasSpeaking = false;
    while (timeout.elapsed() < QT_TTS_TIMEOUT_MS && !isCancelled()) {
        QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
        auto state = m_tts->state();
        if (state == QTextToSpeech::Speaking)
            wasSpeaking = true;
        if (wasSpeaking && state == QTextToSpeech::Ready) {
            emit finished();
            return true;
        }
        if (state == QTextToSpeech::Error)
            return false;
    }

    if (isCancelled()) {
        m_tts->stop();
        emit finished();
        return true;
    }

    m_tts->stop();
    return false;
}

void TTSBackendQt::cancel()
{
    if (m_tts)
        m_tts->stop();
}

void TTSBackendQt::setVoice(const QString &name)
{
    if (!m_tts) return;
    for (const QVoice &v : m_tts->availableVoices()) {
        if (v.name().compare(name, Qt::CaseInsensitive) == 0) {
            m_tts->setVoice(v);
            return;
        }
    }
}
