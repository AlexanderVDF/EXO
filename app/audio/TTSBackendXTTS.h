#ifndef TTSBACKENDXTTS_H
#define TTSBACKENDXTTS_H

#include "TTSBackend.h"

class QWebSocket;

// ─────────────────────────────────────────────────────
//  TTSBackendXTTS — XTTS v2 Python backend (DirectML)
//
//  Blocking WebSocket synthesis via processEvents.
//  Protocol: JSON control + binary PCM16 chunks.
// ─────────────────────────────────────────────────────
class TTSBackendXTTS : public TTSBackend
{
    Q_OBJECT
public:
    explicit TTSBackendXTTS(QObject *parent = nullptr);
    ~TTSBackendXTTS() override;

    QString name() const override { return QStringLiteral("XTTS"); }
    bool isAvailable() const override;
    bool synthesize(const TTSRequest &req) override;
    void cancel() override;
    void resetConnection() override;

    void setUrl(const QString &url);
    void setVoice(const QString &voice);
    void setLang(const QString &lang);

private:
    bool ensureConnected();

    QWebSocket *m_ws = nullptr;
    QString m_url;
    QString m_voice = "Claribel Dervla";
    QString m_lang  = "fr";
    bool m_connected = false;
    bool m_readyReceived = false;

    static constexpr int PY_TTS_TIMEOUT_MS = 12000;
};

#endif // TTSBACKENDXTTS_H
