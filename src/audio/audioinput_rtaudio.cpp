#ifdef ENABLE_RTAUDIO

#include "audioinput_rtaudio.h"
#include <QDebug>

AudioInputRtAudio::AudioInputRtAudio(QObject *parent)
    : AudioInput(parent)
{}

AudioInputRtAudio::~AudioInputRtAudio()
{
    stop();
}

bool AudioInputRtAudio::open(int sampleRate, int channels)
{
    m_sampleRate = sampleRate;
    m_channels   = channels;

    try {
#ifdef _WIN32
        m_rt = std::make_unique<RtAudio>(RtAudio::WINDOWS_WASAPI);
#else
        m_rt = std::make_unique<RtAudio>();
#endif
    } catch (const RtAudioErrorType &) {
        emit error(QStringLiteral("AudioInputRtAudio: impossible de créer l'instance RtAudio"));
        return false;
    }

    if (m_rt->getDeviceCount() == 0) {
        emit error(QStringLiteral("AudioInputRtAudio: aucun périphérique audio détecté"));
        return false;
    }

    unsigned int defaultDev = m_rt->getDefaultInputDevice();
    RtAudio::DeviceInfo info = m_rt->getDeviceInfo(defaultDev);
    qDebug() << "AudioInputRtAudio: ouvert —" << QString::fromStdString(info.name)
             << "rate:" << m_sampleRate << "ch:" << m_channels;
    return true;
}

bool AudioInputRtAudio::start()
{
    if (m_running) return true;
    if (!m_rt) {
        emit error(QStringLiteral("AudioInputRtAudio: open() non appelé"));
        return false;
    }

    RtAudio::StreamParameters params;
    params.deviceId    = m_rt->getDefaultInputDevice();
    params.nChannels   = static_cast<unsigned int>(m_channels);
    params.firstChannel = 0;

    m_bufferFrames = 512;

    try {
        m_rt->openStream(nullptr, &params,
                         RTAUDIO_SINT16,
                         static_cast<unsigned int>(m_sampleRate),
                         &m_bufferFrames,
                         &AudioInputRtAudio::rtCallback,
                         this);
        m_rt->startStream();
    } catch (const RtAudioErrorType &) {
        emit error(QStringLiteral("AudioInputRtAudio: impossible de démarrer le stream"));
        return false;
    }

    m_running = true;
    m_suspended = false;
    qDebug() << "AudioInputRtAudio: stream démarré — bufferFrames:" << m_bufferFrames;
    return true;
}

void AudioInputRtAudio::stop()
{
    if (!m_running) return;
    m_running = false;
    m_suspended = false;

    if (m_rt && m_rt->isStreamOpen()) {
        if (m_rt->isStreamRunning())
            m_rt->stopStream();
        m_rt->closeStream();
    }
    qDebug() << "AudioInputRtAudio: stream arrêté";
}

void AudioInputRtAudio::suspend()
{
    m_suspended = true;
}

void AudioInputRtAudio::resume()
{
    m_suspended = false;
}

bool AudioInputRtAudio::isRunning() const
{
    return m_running;
}

int AudioInputRtAudio::rtCallback(void * /*outputBuffer*/, void *inputBuffer,
                                   unsigned int nFrames,
                                   double /*streamTime*/,
                                   RtAudioStreamStatus status,
                                   void *userData)
{
    auto *self = static_cast<AudioInputRtAudio *>(userData);
    if (status)
        qWarning() << "AudioInputRtAudio: stream overflow/underflow";

    if (self->m_suspended || !self->m_callback)
        return 0;

    auto *samples = static_cast<const int16_t *>(inputBuffer);
    self->m_callback(samples, static_cast<int>(nFrames));
    return 0;
}

#endif // ENABLE_RTAUDIO
