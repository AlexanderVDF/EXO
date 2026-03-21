#include "WebSocketClient.h"
#include "core/LogManager.h"
#include <algorithm>

// ═══════════════════════════════════════════════════════
//  WebSocketClient — implementation
// ═══════════════════════════════════════════════════════

WebSocketClient::WebSocketClient(const QString &name, QObject *parent)
    : QObject(parent)
    , m_name(name)
{
}

WebSocketClient::~WebSocketClient()
{
    if (m_ws) {
        m_ws->disconnect(this);   // detach all signals before close
        if (m_ws->state() != QAbstractSocket::UnconnectedState)
            m_ws->close();
        m_ws->deleteLater();
        m_ws = nullptr;
    }
}

// ── Connection lifecycle ─────────────────────────────

void WebSocketClient::open(const QUrl &url)
{
    m_url = url;
    m_reconnectAttempts = 0;

    if (m_ws) {
        m_ws->disconnect(this);
        m_ws->close();
        m_ws->deleteLater();
    }

    m_ws = new QWebSocket(QString(), QWebSocketProtocol::VersionLatest, this);
    connect(m_ws, &QWebSocket::connected,
            this, &WebSocketClient::onConnected);
    connect(m_ws, &QWebSocket::disconnected,
            this, &WebSocketClient::onDisconnected);
    connect(m_ws, &QWebSocket::textMessageReceived,
            this, &WebSocketClient::textReceived);
    connect(m_ws, &QWebSocket::binaryMessageReceived,
            this, &WebSocketClient::binaryReceived);
    connect(m_ws, &QWebSocket::errorOccurred,
            this, &WebSocketClient::onError);

    setState(State::Connecting);
    hDebug(henriMain) << "[WS:" << m_name << "] connecting to" << url.toString();
    m_ws->open(url);
}

void WebSocketClient::close()
{
    m_reconnectEnabled = false;   // explicit close → no auto-reconnect
    if (m_ws) {
        m_ws->close();
    }
    setState(State::Disconnected);
}

// ── Reconnection policy ──────────────────────────────

void WebSocketClient::setReconnectEnabled(bool enabled)
{
    m_reconnectEnabled = enabled;
}

void WebSocketClient::setReconnectParams(int baseMs, int maxAttempts, bool exponential)
{
    m_reconnectBaseMs       = baseMs;
    m_reconnectMaxAttempts  = maxAttempts;
    m_reconnectExponential  = exponential;
}

// ── Sending ──────────────────────────────────────────

void WebSocketClient::sendText(const QString &msg)
{
    if (m_state != State::Connected || !m_ws) return;
    m_ws->sendTextMessage(msg);
}

void WebSocketClient::sendJson(const QJsonObject &obj)
{
    if (m_state != State::Connected || !m_ws) return;
    m_ws->sendTextMessage(QString::fromUtf8(
        QJsonDocument(obj).toJson(QJsonDocument::Compact)));
}

void WebSocketClient::sendBinary(const QByteArray &data)
{
    if (m_state != State::Connected || !m_ws) return;
    m_ws->sendBinaryMessage(data);
}

// ── Private slots ────────────────────────────────────

void WebSocketClient::onConnected()
{
    m_reconnectAttempts = 0;
    setState(State::Connected);
    hDebug(henriMain) << "[WS:" << m_name << "] connected";
    emit connected();
}

void WebSocketClient::onDisconnected()
{
    setState(State::Disconnected);
    hDebug(henriMain) << "[WS:" << m_name << "] disconnected";
    emit disconnected();
    scheduleReconnect();
}

void WebSocketClient::onError(QAbstractSocket::SocketError err)
{
    Q_UNUSED(err)
    QString desc = m_ws ? m_ws->errorString() : QStringLiteral("unknown");
    hWarning(henriMain) << "[WS:" << m_name << "] error:" << desc;
    emit errorOccurred(desc);

    // If we were connecting and got an error, schedule reconnect
    if (m_state == State::Connecting) {
        setState(State::Disconnected);
        scheduleReconnect();
    }
}

// ── Reconnection logic ──────────────────────────────

void WebSocketClient::scheduleReconnect()
{
    if (!m_reconnectEnabled) return;
    if (m_reconnectMaxAttempts > 0 && m_reconnectAttempts >= m_reconnectMaxAttempts) {
        hWarning(henriMain) << "[WS:" << m_name << "] max reconnect attempts reached ("
                             << m_reconnectMaxAttempts << ")";
        emit errorOccurred(m_name + " server unreachable");
        return;
    }

    int delay = m_reconnectBaseMs;
    if (m_reconnectExponential) {
        delay = m_reconnectBaseMs * (1 << std::min(m_reconnectAttempts, 5));
    }
    ++m_reconnectAttempts;

    setState(State::Reconnecting);
    hDebug(henriMain) << "[WS:" << m_name << "] reconnecting in" << delay
             << "ms (attempt" << m_reconnectAttempts << ")";

    QTimer::singleShot(delay, this, [this]() {
        if (m_state == State::Reconnecting && m_ws) {
            setState(State::Connecting);
            m_ws->open(m_url);
        }
    });
}

// ── State management ─────────────────────────────────

void WebSocketClient::setState(State s)
{
    if (m_state != s) {
        m_state = s;
        emit stateChanged(s);
    }
}
