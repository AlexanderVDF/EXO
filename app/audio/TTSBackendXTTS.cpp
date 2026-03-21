#include "TTSBackendXTTS.h"
#include "TTSManager.h"

#include <QWebSocket>
#include <QCoreApplication>
#include <QElapsedTimer>
#include <QJsonObject>
#include <QJsonDocument>

TTSBackendXTTS::TTSBackendXTTS(QObject *parent)
    : TTSBackend(parent)
{}

TTSBackendXTTS::~TTSBackendXTTS()
{
    if (m_ws) {
        m_ws->close();
        delete m_ws;
    }
}

bool TTSBackendXTTS::isAvailable() const
{
    return !m_url.isEmpty();
}

void TTSBackendXTTS::setUrl(const QString &url)
{
    m_url = url;
    qWarning() << "[TTS] XTTS URL set:" << m_url;
}

void TTSBackendXTTS::setVoice(const QString &voice)
{
    m_voice = voice;
    qWarning() << "[TTS] XTTS voice set to:" << voice;
}

void TTSBackendXTTS::setLang(const QString &lang)
{
    m_lang = lang;
    qWarning() << "[TTS] XTTS language set to:" << lang;
}

void TTSBackendXTTS::resetConnection()
{
    if (m_ws) {
        m_ws->close();
        m_ws->deleteLater();
        m_ws = nullptr;
    }
    m_connected = false;
    m_readyReceived = false;
    qWarning() << "[TTS] Connexion Python réinitialisée";
}

void TTSBackendXTTS::cancel()
{
    if (m_ws && m_connected)
        m_ws->sendTextMessage(QStringLiteral(R"({"type":"cancel"})"));
}

bool TTSBackendXTTS::ensureConnected()
{
    if (m_ws && m_connected)
        return true;

    // Fresh connection
    if (m_ws)
        resetConnection();

    m_ws = new QWebSocket();
    qWarning() << "[TTS] tryPythonTTS: connexion à" << m_url;
    m_ws->open(QUrl(m_url));

    QElapsedTimer connectTimer;
    connectTimer.start();
    while (m_ws->state() != QAbstractSocket::ConnectedState
           && connectTimer.elapsed() < 5000 && !isCancelled()) {
        QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
    }
    m_connected = (m_ws->state() == QAbstractSocket::ConnectedState);
    qWarning() << "[TTS] tryPythonTTS: connected =" << m_connected
               << "state:" << m_ws->state()
               << "après" << connectTimer.elapsed() << "ms";
    if (m_connected)
        qWarning() << "[TTS] Connected to XTTS DirectML server";

    // Drain initial "ready" message from XTTS v2 server
    if (m_connected && !m_readyReceived) {
        QElapsedTimer readyTimer;
        readyTimer.start();
        bool gotReady = false;
        QMetaObject::Connection readyConn = connect(m_ws, &QWebSocket::textMessageReceived,
            this, [&gotReady](const QString &txt) {
                QJsonDocument d = QJsonDocument::fromJson(txt.toUtf8());
                if (d.isObject() && d.object()["type"].toString() == "ready")
                    gotReady = true;
            });
        while (!gotReady && readyTimer.elapsed() < 3000 && !isCancelled())
            QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
        disconnect(readyConn);
        m_readyReceived = gotReady;
        qWarning() << "[TTS] XTTS v2 ready message:" << (gotReady ? "OK" : "timeout");
    }

    if (!m_connected) {
        // Retry once
        qWarning() << "[TTS] tryPythonTTS: non connecté — retry connexion...";
        resetConnection();
        m_ws = new QWebSocket();
        m_ws->open(QUrl(m_url));

        QElapsedTimer retryTimer;
        retryTimer.start();
        while (m_ws->state() != QAbstractSocket::ConnectedState
               && retryTimer.elapsed() < 3000 && !isCancelled()) {
            QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
        }
        m_connected = (m_ws->state() == QAbstractSocket::ConnectedState);
        qWarning() << "[TTS] tryPythonTTS retry: connected =" << m_connected
                    << "après" << retryTimer.elapsed() << "ms";

        if (m_connected && !m_readyReceived) {
            QElapsedTimer readyTimer;
            readyTimer.start();
            bool gotReady = false;
            QMetaObject::Connection readyConn = connect(m_ws, &QWebSocket::textMessageReceived,
                this, [&gotReady](const QString &txt) {
                    QJsonDocument d = QJsonDocument::fromJson(txt.toUtf8());
                    if (d.isObject() && d.object()["type"].toString() == "ready")
                        gotReady = true;
                });
            while (!gotReady && readyTimer.elapsed() < 3000 && !isCancelled())
                QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
            disconnect(readyConn);
            m_readyReceived = gotReady;
        }

        if (!m_connected) {
            qWarning() << "[TTS] Python TTS unavailable — fallback Qt TTS";
            return false;
        }
    }

    return true;
}

bool TTSBackendXTTS::synthesize(const TTSRequest &req)
{
    if (m_url.isEmpty()) {
        qWarning() << "[TTS] tryPythonTTS: URL vide — skip XTTS";
        return false;
    }

    if (!ensureConnected())
        return false;

    emit started(req.text);

    // Send synthesis request (XTTS v2 tts_server.py protocol)
    QJsonObject msg;
    msg["type"]  = "synthesize";
    msg["text"]  = req.text;
    msg["voice"] = m_voice;
    msg["lang"]  = m_lang;
    msg["rate"]  = static_cast<double>(1.0 + req.prosody.rate * 0.5);   // [-1,1] → [0.5, 1.5]
    msg["pitch"] = static_cast<double>(1.0 + req.prosody.pitch * 0.3);  // [-1,1] → [0.7, 1.3]
    m_ws->sendTextMessage(
        QString::fromUtf8(QJsonDocument(msg).toJson(QJsonDocument::Compact)));

    // Wait for: JSON "start" → binary PCM chunks → JSON "end"
    QElapsedTimer timeout;
    timeout.start();
    bool done = false;
    bool gotStart = false;

    QMetaObject::Connection binConn = connect(m_ws, &QWebSocket::binaryMessageReceived,
        this, [this, &timeout](const QByteArray &data) {
            timeout.restart();
            emit chunk(data);
        });
    QMetaObject::Connection txtConn = connect(m_ws, &QWebSocket::textMessageReceived,
        this, [&done, &gotStart, &timeout](const QString &txtMsg) {
            QJsonDocument d = QJsonDocument::fromJson(txtMsg.toUtf8());
            if (!d.isObject()) return;
            QString type = d.object()["type"].toString();
            if (type == "start") {
                gotStart = true;
                timeout.restart();
            }
            else if (type == "end")
                done = true;
            else if (type == "error")
                done = true;
        });

    while (!done && timeout.elapsed() < PY_TTS_TIMEOUT_MS && !isCancelled()) {
        QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
    }

    disconnect(binConn);
    disconnect(txtConn);

    if (done || isCancelled()) {
        emit finished();
        return true;
    }

    // Timeout — reset connection so next call starts fresh
    qWarning() << "[TTS] XTTS timeout après" << PY_TTS_TIMEOUT_MS << "ms — reset connexion";
    resetConnection();
    return false;
}
