#include "claudeapi.h"
#include "logmanager.h"

#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonParseError>
#include <QUrl>
#include <QDateTime>
#include <QThread>

// ═══════════════════════════════════════════════════════
//  Construction / Destruction
// ═══════════════════════════════════════════════════════

ClaudeAPI::ClaudeAPI(QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_timeoutTimer(new QTimer(this))
    , m_retryTimer(new QTimer(this))
    , m_temperature(DEFAULT_TEMP)
    , m_maxTokens(DEFAULT_MAX_TOKENS)
    , m_topP(-1.0)
    , m_topK(-1)
    , m_timeoutMs(DEFAULT_TIMEOUT)
{
    m_timeoutTimer->setSingleShot(true);
    m_retryTimer->setSingleShot(true);

    connect(m_timeoutTimer, &QTimer::timeout,
            this, &ClaudeAPI::onTimeout);
    connect(m_retryTimer, &QTimer::timeout,
            this, &ClaudeAPI::onRetryTimer);

    hClaude() << "ClaudeAPI v4 initialisée — streaming SSE, Function Calling, retry exponentiel";
}

ClaudeAPI::~ClaudeAPI()
{
    cancelCurrentRequest();
    hClaude() << "ClaudeAPI détruite —"
              << m_totalRequests << "requêtes,"
              << m_totalErrors << "erreurs";
}

// ═══════════════════════════════════════════════════════
//  Configuration
// ═══════════════════════════════════════════════════════

void ClaudeAPI::setApiKey(const QString &apiKey)
{
    m_apiKey = apiKey;
    bool wasReady = m_isReady;
    m_isReady = !apiKey.isEmpty();

    if (m_isReady) {
        hClaude() << "Clé API configurée";
    }
    if (wasReady != m_isReady) {
        emit readyChanged();
    }
}

void ClaudeAPI::setModel(const QString &model)
{
    if (m_model != model) {
        m_model = model;
        hClaude() << "Modèle:" << model;
        emit modelChanged();
    }
}

void ClaudeAPI::setTemperature(double temp)
{
    m_temperature = qBound(0.0, temp, 1.0);
}

void ClaudeAPI::setMaxTokens(int tokens)
{
    m_maxTokens = qBound(1, tokens, 200000);
}

void ClaudeAPI::setTopP(double topP)
{
    m_topP = (topP >= 0.0 && topP <= 1.0) ? topP : -1.0;
}

void ClaudeAPI::setTopK(int topK)
{
    m_topK = (topK >= 1) ? topK : -1;
}

void ClaudeAPI::setTimeout(int timeoutMs)
{
    m_timeoutMs = qMax(1000, timeoutMs);
}

// ═══════════════════════════════════════════════════════
//  API principale
// ═══════════════════════════════════════════════════════

void ClaudeAPI::sendMessage(const QString &userMessage)
{
    // Compat QML : appel simplifié sans contexte ni outils
    sendMessageFull(userMessage,
                    QStringLiteral("Vous êtes EXO, un assistant domotique français intelligent."),
                    {}, true);
}

void ClaudeAPI::sendMessageFull(const QString &userMessage,
                                const QString &systemPrompt,
                                const QJsonArray &tools,
                                bool stream)
{
    if (!m_isReady || m_apiKey.isEmpty()) {
        setError(QStringLiteral("API Claude non configurée — clé manquante"));
        return;
    }

    if (!checkRateLimit()) {
        setError(QStringLiteral("Rate limit interne atteint — réessayez dans quelques secondes"));
        return;
    }

    // Annuler toute requête en cours
    if (m_currentReply) {
        cancelCurrentRequest();
    }

    // Stocker pour tool_result et retry
    m_pendingSystemPrompt = systemPrompt;
    m_pendingTools = tools;
    m_pendingStream = stream;

    // Ajouter le message utilisateur à l'historique
    QJsonObject userMsg;
    userMsg[QStringLiteral("role")] = QStringLiteral("user");
    userMsg[QStringLiteral("content")] = userMessage;
    m_conversationHistory.append(userMsg);

    // Construire et envoyer le payload
    QJsonObject payload = buildPayload(userMessage, systemPrompt, tools, stream);
    QJsonDocument doc(payload);
    QByteArray payloadBytes = doc.toJson(QJsonDocument::Compact);

    resetRetryState();
    m_lastPayload = payloadBytes;
    m_lastStreamFlag = stream;

    startRequest(payloadBytes, stream);
}

void ClaudeAPI::sendToolResult(const QString &toolUseId,
                               const QJsonObject &result)
{
    hClaude() << "Envoi tool_result pour" << toolUseId;

    // Reconstruire le message assistant avec les content blocks précédents
    QJsonArray assistantContent;
    for (const auto &block : m_contentBlocks) {
        QJsonObject obj;
        if (block.type == QLatin1String("text") && !block.text.isEmpty()) {
            obj[QStringLiteral("type")] = QStringLiteral("text");
            obj[QStringLiteral("text")] = block.text;
            assistantContent.append(obj);
        } else if (block.type == QLatin1String("tool_use")) {
            obj[QStringLiteral("type")] = QStringLiteral("tool_use");
            obj[QStringLiteral("id")] = block.toolUseId;
            obj[QStringLiteral("name")] = block.toolName;
            // Parser le JSON accumulé
            QJsonParseError err;
            QJsonDocument inputDoc = QJsonDocument::fromJson(
                block.toolInputJson.toUtf8(), &err);
            if (err.error == QJsonParseError::NoError) {
                obj[QStringLiteral("input")] = inputDoc.object();
            } else {
                obj[QStringLiteral("input")] = QJsonObject();
            }
            assistantContent.append(obj);
        }
    }

    // Ajouter le message assistant à l'historique
    QJsonObject assistantMsg;
    assistantMsg[QStringLiteral("role")] = QStringLiteral("assistant");
    assistantMsg[QStringLiteral("content")] = assistantContent;
    m_conversationHistory.append(assistantMsg);

    // Ajouter le tool_result à l'historique
    QJsonArray toolResultContent;
    QJsonObject toolResultBlock;
    toolResultBlock[QStringLiteral("type")] = QStringLiteral("tool_result");
    toolResultBlock[QStringLiteral("tool_use_id")] = toolUseId;

    // Sérialiser le résultat comme texte
    QJsonDocument resultDoc(result);
    toolResultBlock[QStringLiteral("content")] = QString::fromUtf8(
        resultDoc.toJson(QJsonDocument::Compact));
    toolResultContent.append(toolResultBlock);

    QJsonObject userToolMsg;
    userToolMsg[QStringLiteral("role")] = QStringLiteral("user");
    userToolMsg[QStringLiteral("content")] = toolResultContent;
    m_conversationHistory.append(userToolMsg);

    // Rebuilder le payload avec l'historique complet
    QJsonObject payload;
    payload[QStringLiteral("model")] = m_model;
    payload[QStringLiteral("max_tokens")] = m_maxTokens;
    payload[QStringLiteral("temperature")] = m_temperature;

    if (m_topP >= 0.0)
        payload[QStringLiteral("top_p")] = m_topP;
    if (m_topK >= 1)
        payload[QStringLiteral("top_k")] = m_topK;

    if (!m_pendingSystemPrompt.isEmpty())
        payload[QStringLiteral("system")] = m_pendingSystemPrompt;

    payload[QStringLiteral("messages")] = m_conversationHistory;

    if (!m_pendingTools.isEmpty())
        payload[QStringLiteral("tools")] = m_pendingTools;

    payload[QStringLiteral("stream")] = m_pendingStream;

    QJsonDocument doc(payload);
    QByteArray payloadBytes = doc.toJson(QJsonDocument::Compact);

    resetRetryState();
    m_lastPayload = payloadBytes;
    m_lastStreamFlag = m_pendingStream;

    startRequest(payloadBytes, m_pendingStream);
}

void ClaudeAPI::cancelCurrentRequest()
{
    m_timeoutTimer->stop();
    m_retryTimer->stop();

    if (m_currentReply) {
        disconnect(m_currentReply, nullptr, this, nullptr);
        m_currentReply->abort();
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
    }

    setStreaming(false);
    hClaude() << "Requête annulée";
}

void ClaudeAPI::clearConversationHistory()
{
    m_conversationHistory = QJsonArray();
    hClaude() << "Historique conversation effacé";
}

int ClaudeAPI::conversationTurnCount() const
{
    return m_conversationHistory.size();
}

// ═══════════════════════════════════════════════════════
//  Construction du payload JSON
// ═══════════════════════════════════════════════════════

QJsonObject ClaudeAPI::buildPayload(const QString &userMessage,
                                    const QString &systemPrompt,
                                    const QJsonArray &tools,
                                    bool stream) const
{
    Q_UNUSED(userMessage) // déjà dans m_conversationHistory

    QJsonObject payload;
    payload[QStringLiteral("model")] = m_model;
    payload[QStringLiteral("max_tokens")] = m_maxTokens;
    payload[QStringLiteral("temperature")] = m_temperature;

    if (m_topP >= 0.0)
        payload[QStringLiteral("top_p")] = m_topP;
    if (m_topK >= 1)
        payload[QStringLiteral("top_k")] = m_topK;

    // System prompt (top-level dans Claude Messages v1)
    if (!systemPrompt.isEmpty())
        payload[QStringLiteral("system")] = systemPrompt;

    // Messages = conversation complète
    payload[QStringLiteral("messages")] = m_conversationHistory;

    // Outils Function Calling
    if (!tools.isEmpty())
        payload[QStringLiteral("tools")] = tools;

    // Streaming
    if (stream)
        payload[QStringLiteral("stream")] = true;

    return payload;
}

QNetworkRequest ClaudeAPI::buildHttpRequest() const
{
    QNetworkRequest request;
    request.setUrl(QUrl(QLatin1String(API_URL)));
    request.setHeader(QNetworkRequest::ContentTypeHeader,
                      QStringLiteral("application/json"));
    request.setRawHeader("x-api-key", m_apiKey.toUtf8());
    request.setRawHeader("anthropic-version", API_VERSION);
    return request;
}

// ═══════════════════════════════════════════════════════
//  Lancement de requête
// ═══════════════════════════════════════════════════════

void ClaudeAPI::startRequest(const QByteArray &payload, bool stream)
{
    ++m_totalRequests;
    m_requestTimestamps.append(QDateTime::currentMSecsSinceEpoch());

    // Reset des accumulateurs streaming
    m_sseBuffer.clear();
    m_currentEventType.clear();
    m_accumulatedText.clear();
    m_contentBlocks.clear();
    m_currentBlockIdx = -1;

    QNetworkRequest request = buildHttpRequest();
    m_currentReply = m_networkManager->post(request, payload);

    if (stream) {
        setStreaming(true);
        // Connexion streaming : lire les chunks progressivement
        connect(m_currentReply, &QIODevice::readyRead,
                this, &ClaudeAPI::onStreamDataReady);
    }

    connect(m_currentReply, &QNetworkReply::finished,
            this, &ClaudeAPI::onReplyFinished);
    connect(m_currentReply, &QNetworkReply::errorOccurred,
            this, &ClaudeAPI::onNetworkError);

    m_timeoutTimer->start(m_timeoutMs);
    emit requestStarted();

    hClaude() << "Requête envoyée —"
              << (stream ? "streaming" : "sync")
              << "— modèle:" << m_model
              << "— payload:" << (payload.size() / 1024) << "KB";
}

// ═══════════════════════════════════════════════════════
//  Streaming SSE
// ═══════════════════════════════════════════════════════

void ClaudeAPI::onStreamDataReady()
{
    if (!m_currentReply) return;

    // Restart timeout à chaque chunk reçu
    m_timeoutTimer->start(m_timeoutMs);

    QByteArray newData = m_currentReply->readAll();
    processStreamChunk(newData);
}

void ClaudeAPI::processStreamChunk(const QByteArray &chunk)
{
    m_sseBuffer.append(chunk);

    // Découper en lignes SSE (séparées par \n)
    while (true) {
        int nlPos = m_sseBuffer.indexOf('\n');
        if (nlPos < 0) break;

        QByteArray lineBytes = m_sseBuffer.left(nlPos);
        m_sseBuffer.remove(0, nlPos + 1);

        // Supprimer \r éventuel
        if (lineBytes.endsWith('\r'))
            lineBytes.chop(1);

        QString line = QString::fromUtf8(lineBytes);
        processSSELine(line);
    }
}

void ClaudeAPI::processSSELine(const QString &line)
{
    // Ligne vide = fin d'un événement SSE (pas d'action ici,
    // on traite les données au fur et à mesure)
    if (line.isEmpty()) {
        m_currentEventType.clear();
        return;
    }

    // "event: xxx"
    if (line.startsWith(QLatin1String("event: "))) {
        m_currentEventType = line.mid(7).trimmed();
        return;
    }

    // "data: {...}"
    if (line.startsWith(QLatin1String("data: "))) {
        QString dataStr = line.mid(6);

        QJsonParseError err;
        QJsonDocument doc = QJsonDocument::fromJson(dataStr.toUtf8(), &err);

        if (err.error != QJsonParseError::NoError) {
            // Pas forcément une erreur — certains événements n'ont pas de JSON
            return;
        }

        processSSEEvent(m_currentEventType, doc.object());
    }
}

void ClaudeAPI::processSSEEvent(const QString &eventType,
                                const QJsonObject &data)
{
    QString type = data[QStringLiteral("type")].toString();

    if (type == QLatin1String("message_start")) {
        // Début du message — rien de spécial
        return;
    }

    if (type == QLatin1String("content_block_start")) {
        handleContentBlockStart(data);
        return;
    }

    if (type == QLatin1String("content_block_delta")) {
        handleContentBlockDelta(data);
        return;
    }

    if (type == QLatin1String("content_block_stop")) {
        handleContentBlockStop(data);
        return;
    }

    if (type == QLatin1String("message_delta")) {
        handleMessageDelta(data);
        return;
    }

    if (type == QLatin1String("message_stop")) {
        handleMessageStop();
        return;
    }

    if (type == QLatin1String("ping")) {
        return; // keepalive
    }

    if (type == QLatin1String("error")) {
        QJsonObject errObj = data[QStringLiteral("error")].toObject();
        QString errMsg = errObj[QStringLiteral("message")].toString();
        setError(QStringLiteral("Erreur streaming Claude: ") + errMsg);
        return;
    }

    Q_UNUSED(eventType)
}

void ClaudeAPI::handleContentBlockStart(const QJsonObject &data)
{
    int index = data[QStringLiteral("index")].toInt();
    QJsonObject blockObj = data[QStringLiteral("content_block")].toObject();
    QString blockType = blockObj[QStringLiteral("type")].toString();

    ContentBlock block;
    block.type = blockType;

    if (blockType == QLatin1String("tool_use")) {
        block.toolUseId = blockObj[QStringLiteral("id")].toString();
        block.toolName = blockObj[QStringLiteral("name")].toString();
        hClaude() << "Tool use détecté:" << block.toolName
                  << "— id:" << block.toolUseId;
    }

    // S'assurer que la liste est assez grande
    while (m_contentBlocks.size() <= index) {
        m_contentBlocks.append(ContentBlock());
    }
    m_contentBlocks[index] = block;
    m_currentBlockIdx = index;
}

void ClaudeAPI::handleContentBlockDelta(const QJsonObject &data)
{
    int index = data[QStringLiteral("index")].toInt();
    QJsonObject delta = data[QStringLiteral("delta")].toObject();
    QString deltaType = delta[QStringLiteral("type")].toString();

    if (index < 0 || index >= m_contentBlocks.size()) return;

    ContentBlock &block = m_contentBlocks[index];

    if (deltaType == QLatin1String("text_delta")) {
        QString text = delta[QStringLiteral("text")].toString();
        block.text += text;
        m_accumulatedText += text;

        // Émettre le token en temps réel
        emit partialResponse(text);

    } else if (deltaType == QLatin1String("input_json_delta")) {
        // Accumulation progressive du JSON pour tool_use
        QString partialJson = delta[QStringLiteral("partial_json")].toString();
        block.toolInputJson += partialJson;
    }
}

void ClaudeAPI::handleContentBlockStop(const QJsonObject &data)
{
    int index = data[QStringLiteral("index")].toInt();
    if (index < 0 || index >= m_contentBlocks.size()) return;

    const ContentBlock &block = m_contentBlocks[index];

    if (block.type == QLatin1String("tool_use")) {
        // Parser le JSON complet et émettre le signal
        QJsonParseError err;
        QJsonDocument doc = QJsonDocument::fromJson(
            block.toolInputJson.toUtf8(), &err);

        QJsonObject args;
        if (err.error == QJsonParseError::NoError) {
            args = doc.object();
        } else {
            hWarning(henriClaude) << "JSON tool_use invalide:"
                                  << err.errorString();
        }

        hClaude() << "Tool call complet:" << block.toolName
                  << "— args:" << QString::fromUtf8(
                         QJsonDocument(args).toJson(QJsonDocument::Compact));

        emit toolCallDetected(block.toolUseId, block.toolName, args);
    }
}

void ClaudeAPI::handleMessageDelta(const QJsonObject &data)
{
    QJsonObject delta = data[QStringLiteral("delta")].toObject();
    QString stopReason = delta[QStringLiteral("stop_reason")].toString();

    if (!stopReason.isEmpty()) {
        hClaude() << "Stop reason:" << stopReason;
    }
}

void ClaudeAPI::handleMessageStop()
{
    hClaude() << "Message streaming terminé —"
              << m_accumulatedText.length() << "caractères";

    setStreaming(false);

    // Si du texte a été accumulé, émettre la réponse finale
    if (!m_accumulatedText.isEmpty()) {
        // Ajouter la réponse assistant à l'historique (si pas de tool call)
        bool hasToolCalls = false;
        for (const auto &block : m_contentBlocks) {
            if (block.type == QLatin1String("tool_use")) {
                hasToolCalls = true;
                break;
            }
        }

        if (!hasToolCalls) {
            QJsonObject assistantMsg;
            assistantMsg[QStringLiteral("role")] = QStringLiteral("assistant");
            assistantMsg[QStringLiteral("content")] = m_accumulatedText;
            m_conversationHistory.append(assistantMsg);
        }

        emit finalResponse(m_accumulatedText);
        emit responseReceived(m_accumulatedText); // compat QML
    }
}

// ═══════════════════════════════════════════════════════
//  Réponse non-streaming
// ═══════════════════════════════════════════════════════

void ClaudeAPI::processFullResponse(const QByteArray &data)
{
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);

    if (parseError.error != QJsonParseError::NoError) {
        setError(QStringLiteral("JSON invalide: ") + parseError.errorString());
        return;
    }

    QJsonObject obj = doc.object();

    if (!validateJsonResponse(obj)) return;

    // Vérifier si c'est une erreur API
    if (obj.contains(QStringLiteral("error"))) {
        QJsonObject errObj = obj[QStringLiteral("error")].toObject();
        QString errType = errObj[QStringLiteral("type")].toString();
        QString errMsg = errObj[QStringLiteral("message")].toString();
        setError(QStringLiteral("Erreur Claude [%1]: %2").arg(errType, errMsg));
        return;
    }

    QJsonArray content = obj[QStringLiteral("content")].toArray();
    QString fullText;
    bool hasToolCalls = false;

    for (const QJsonValue &val : content) {
        QJsonObject block = val.toObject();
        QString type = block[QStringLiteral("type")].toString();

        if (type == QLatin1String("text")) {
            fullText += block[QStringLiteral("text")].toString();

        } else if (type == QLatin1String("tool_use")) {
            hasToolCalls = true;

            ContentBlock cb;
            cb.type = QStringLiteral("tool_use");
            cb.toolUseId = block[QStringLiteral("id")].toString();
            cb.toolName = block[QStringLiteral("name")].toString();
            cb.toolInputJson = QString::fromUtf8(
                QJsonDocument(block[QStringLiteral("input")].toObject())
                    .toJson(QJsonDocument::Compact));
            m_contentBlocks.append(cb);

            hClaude() << "Tool call (sync):" << cb.toolName;
            emit toolCallDetected(cb.toolUseId, cb.toolName,
                                  block[QStringLiteral("input")].toObject());
        }
    }

    if (!fullText.isEmpty()) {
        m_accumulatedText = fullText;

        if (!hasToolCalls) {
            QJsonObject assistantMsg;
            assistantMsg[QStringLiteral("role")] = QStringLiteral("assistant");
            assistantMsg[QStringLiteral("content")] = fullText;
            m_conversationHistory.append(assistantMsg);
        }

        emit finalResponse(fullText);
        emit responseReceived(fullText); // compat QML
        hClaude() << "Réponse (sync):" << fullText.left(100) + "...";
    }
}

// ═══════════════════════════════════════════════════════
//  Callbacks réseau
// ═══════════════════════════════════════════════════════

void ClaudeAPI::onReplyFinished()
{
    if (!m_currentReply) return;

    m_timeoutTimer->stop();

    int httpStatus = m_currentReply->attribute(
        QNetworkRequest::HttpStatusCodeAttribute).toInt();

    // Si streaming, les données ont déjà été traitées
    if (m_isStreaming || m_lastStreamFlag) {
        // Vérifier erreur HTTP même en streaming
        if (httpStatus != 200 && httpStatus != 0) {
            QByteArray errorData = m_currentReply->readAll();
            handleHttpError(httpStatus, errorData);
        }
        cleanup();
        emit requestFinished();
        return;
    }

    // Mode non-streaming : lire la réponse complète
    QByteArray responseData = m_currentReply->readAll();
    cleanup();

    if (httpStatus == 200) {
        processFullResponse(responseData);
    } else {
        handleHttpError(httpStatus, responseData);
    }

    emit requestFinished();
}

void ClaudeAPI::onNetworkError(QNetworkReply::NetworkError error)
{
    m_timeoutTimer->stop();

    if (error == QNetworkReply::OperationCanceledError) {
        return; // Annulation volontaire
    }

    ++m_totalErrors;

    QString errorString;
    switch (error) {
    case QNetworkReply::ConnectionRefusedError:
        errorString = QStringLiteral("Connexion refusée par l'API Claude");
        break;
    case QNetworkReply::RemoteHostClosedError:
        errorString = QStringLiteral("Connexion fermée par le serveur Claude");
        break;
    case QNetworkReply::HostNotFoundError:
        errorString = QStringLiteral("Serveur Claude introuvable");
        break;
    case QNetworkReply::TimeoutError:
        errorString = QStringLiteral("Timeout de connexion Claude");
        break;
    case QNetworkReply::SslHandshakeFailedError:
        errorString = QStringLiteral("Erreur SSL avec l'API Claude");
        break;
    case QNetworkReply::AuthenticationRequiredError:
        errorString = QStringLiteral("Authentification requise — vérifiez la clé API");
        break;
    default:
        errorString = QStringLiteral("Erreur réseau: %1").arg(
            m_currentReply ? m_currentReply->errorString()
                           : QStringLiteral("inconnue"));
    }

    hClaude() << "Erreur réseau:" << errorString;

    // Retry si possible
    if (m_retryCount < MAX_RETRIES) {
        retryWithBackoff();
    } else {
        setError(errorString);
        cleanup();
        emit requestFinished();
    }
}

void ClaudeAPI::onTimeout()
{
    hClaude() << "Timeout atteint (" << m_timeoutMs << "ms)";

    if (m_retryCount < MAX_RETRIES) {
        cancelCurrentRequest();
        retryWithBackoff();
    } else {
        cancelCurrentRequest();
        setError(QStringLiteral("Timeout après %1 tentatives").arg(MAX_RETRIES));
        emit requestFinished();
    }
}

// ═══════════════════════════════════════════════════════
//  Gestion erreurs HTTP
// ═══════════════════════════════════════════════════════

void ClaudeAPI::handleHttpError(int httpStatus, const QByteArray &data)
{
    QString errorMsg = QStringLiteral("Erreur API Claude (HTTP %1)").arg(httpStatus);

    // Tenter de parser le corps d'erreur pour plus de détails
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);

    if (parseError.error == QJsonParseError::NoError) {
        QJsonObject obj = doc.object();
        if (obj.contains(QStringLiteral("error"))) {
            QJsonObject errObj = obj[QStringLiteral("error")].toObject();
            QString errType = errObj[QStringLiteral("type")].toString();
            QString errMessage = errObj[QStringLiteral("message")].toString();
            if (!errMessage.isEmpty()) {
                errorMsg += QStringLiteral(" [%1]: %2").arg(errType, errMessage);
            }
        }
    }

    // Retry pour erreurs transitoires (429, 500, 502, 503, 529)
    bool retryable = (httpStatus == 429 || httpStatus == 500
                      || httpStatus == 502 || httpStatus == 503
                      || httpStatus == 529);

    if (retryable && m_retryCount < MAX_RETRIES) {
        hClaude() << errorMsg << "— retry possible";
        retryWithBackoff();
    } else {
        setError(errorMsg);
    }
}

// ═══════════════════════════════════════════════════════
//  Robustesse : retry exponentiel
// ═══════════════════════════════════════════════════════

void ClaudeAPI::retryWithBackoff()
{
    ++m_retryCount;

    // Backoff exponentiel : 1s, 2s, 4s
    int delayMs = 1000 * (1 << (m_retryCount - 1));

    hClaude() << "Retry" << m_retryCount << "/" << MAX_RETRIES
              << "— délai:" << delayMs << "ms";

    // Nettoyer la connexion actuelle
    if (m_currentReply) {
        disconnect(m_currentReply, nullptr, this, nullptr);
        m_currentReply->abort();
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
    }

    setStreaming(false);
    m_retryTimer->start(delayMs);
}

void ClaudeAPI::onRetryTimer()
{
    hClaude() << "Retry en cours...";
    startRequest(m_lastPayload, m_lastStreamFlag);
}

void ClaudeAPI::resetRetryState()
{
    m_retryCount = 0;
    m_retryTimer->stop();
}

// ═══════════════════════════════════════════════════════
//  Rate limiting
// ═══════════════════════════════════════════════════════

bool ClaudeAPI::checkRateLimit()
{
    qint64 now = QDateTime::currentMSecsSinceEpoch();
    qint64 oneMinuteAgo = now - 60000;

    // Purger les timestamps anciens
    while (!m_requestTimestamps.isEmpty()
           && m_requestTimestamps.first() < oneMinuteAgo) {
        m_requestTimestamps.removeFirst();
    }

    if (m_requestTimestamps.size() >= RATE_LIMIT_PER_MIN) {
        hWarning(henriClaude) << "Rate limit:"
                              << m_requestTimestamps.size()
                              << "requêtes dans la dernière minute";
        return false;
    }

    return true;
}

// ═══════════════════════════════════════════════════════
//  Validation JSON
// ═══════════════════════════════════════════════════════

bool ClaudeAPI::validateJsonResponse(const QJsonObject &obj) const
{
    // Vérifier la structure minimale d'une réponse Claude
    if (obj.isEmpty()) {
        return false;
    }

    // Si c'est une erreur, c'est un JSON valide (traitement en amont)
    if (obj.contains(QStringLiteral("error"))) {
        return true;
    }

    // Réponse normale : doit avoir "content" et "role"
    if (!obj.contains(QStringLiteral("content"))) {
        hWarning(henriClaude) << "Réponse sans champ 'content'";
        return false;
    }

    return true;
}

// ═══════════════════════════════════════════════════════
//  Outils EXO (Function Calling)
// ═══════════════════════════════════════════════════════

QJsonObject ClaudeAPI::buildToolSchema(const QString &name,
                                       const QString &description,
                                       const QJsonObject &inputSchema)
{
    QJsonObject tool;
    tool[QStringLiteral("name")] = name;
    tool[QStringLiteral("description")] = description;
    tool[QStringLiteral("input_schema")] = inputSchema;
    return tool;
}

QJsonArray ClaudeAPI::buildEXOTools()
{
    QJsonArray tools;

    // ── ha_turn_on : allumer une entité HA ──────────
    {
        QJsonObject schema;
        schema[QStringLiteral("type")] = QStringLiteral("object");

        QJsonObject props;
        QJsonObject entityProp;
        entityProp[QStringLiteral("type")] = QStringLiteral("string");
        entityProp[QStringLiteral("description")] =
            QStringLiteral("L'entity_id Home Assistant (ex: light.salon, switch.tv)");
        props[QStringLiteral("entity_id")] = entityProp;
        schema[QStringLiteral("properties")] = props;

        QJsonArray required;
        required.append(QStringLiteral("entity_id"));
        schema[QStringLiteral("required")] = required;

        tools.append(buildToolSchema(
            QStringLiteral("ha_turn_on"),
            QStringLiteral("Allumer une entité Home Assistant (lumière, switch, prise, etc.)"),
            schema));
    }

    // ── ha_turn_off : éteindre une entité HA ────────
    {
        QJsonObject schema;
        schema[QStringLiteral("type")] = QStringLiteral("object");

        QJsonObject props;
        QJsonObject entityProp;
        entityProp[QStringLiteral("type")] = QStringLiteral("string");
        entityProp[QStringLiteral("description")] =
            QStringLiteral("L'entity_id Home Assistant à éteindre");
        props[QStringLiteral("entity_id")] = entityProp;
        schema[QStringLiteral("properties")] = props;

        QJsonArray required;
        required.append(QStringLiteral("entity_id"));
        schema[QStringLiteral("required")] = required;

        tools.append(buildToolSchema(
            QStringLiteral("ha_turn_off"),
            QStringLiteral("Éteindre une entité Home Assistant"),
            schema));
    }

    // ── ha_toggle : basculer une entité ─────────────
    {
        QJsonObject schema;
        schema[QStringLiteral("type")] = QStringLiteral("object");

        QJsonObject props;
        QJsonObject entityProp;
        entityProp[QStringLiteral("type")] = QStringLiteral("string");
        entityProp[QStringLiteral("description")] =
            QStringLiteral("L'entity_id Home Assistant à basculer");
        props[QStringLiteral("entity_id")] = entityProp;
        schema[QStringLiteral("properties")] = props;

        QJsonArray required;
        required.append(QStringLiteral("entity_id"));
        schema[QStringLiteral("required")] = required;

        tools.append(buildToolSchema(
            QStringLiteral("ha_toggle"),
            QStringLiteral("Basculer une entité Home Assistant (on↔off)"),
            schema));
    }

    // ── ha_set_brightness : régler luminosité ───────
    {
        QJsonObject schema;
        schema[QStringLiteral("type")] = QStringLiteral("object");

        QJsonObject props;
        QJsonObject entityProp;
        entityProp[QStringLiteral("type")] = QStringLiteral("string");
        entityProp[QStringLiteral("description")] =
            QStringLiteral("L'entity_id de la lumière");
        props[QStringLiteral("entity_id")] = entityProp;

        QJsonObject brightProp;
        brightProp[QStringLiteral("type")] = QStringLiteral("integer");
        brightProp[QStringLiteral("description")] =
            QStringLiteral("Luminosité entre 0 et 255");
        brightProp[QStringLiteral("minimum")] = 0;
        brightProp[QStringLiteral("maximum")] = 255;
        props[QStringLiteral("brightness")] = brightProp;

        schema[QStringLiteral("properties")] = props;

        QJsonArray required;
        required.append(QStringLiteral("entity_id"));
        required.append(QStringLiteral("brightness"));
        schema[QStringLiteral("required")] = required;

        tools.append(buildToolSchema(
            QStringLiteral("ha_set_brightness"),
            QStringLiteral("Régler la luminosité d'une lumière Home Assistant"),
            schema));
    }

    // ── ha_set_temperature : régler thermostat ──────
    {
        QJsonObject schema;
        schema[QStringLiteral("type")] = QStringLiteral("object");

        QJsonObject props;
        QJsonObject entityProp;
        entityProp[QStringLiteral("type")] = QStringLiteral("string");
        entityProp[QStringLiteral("description")] =
            QStringLiteral("L'entity_id du thermostat");
        props[QStringLiteral("entity_id")] = entityProp;

        QJsonObject tempProp;
        tempProp[QStringLiteral("type")] = QStringLiteral("number");
        tempProp[QStringLiteral("description")] =
            QStringLiteral("Température cible en °C");
        props[QStringLiteral("temperature")] = tempProp;

        schema[QStringLiteral("properties")] = props;

        QJsonArray required;
        required.append(QStringLiteral("entity_id"));
        required.append(QStringLiteral("temperature"));
        schema[QStringLiteral("required")] = required;

        tools.append(buildToolSchema(
            QStringLiteral("ha_set_temperature"),
            QStringLiteral("Régler la température d'un thermostat Home Assistant"),
            schema));
    }

    // ── ha_get_state : lire l'état d'une entité ─────
    {
        QJsonObject schema;
        schema[QStringLiteral("type")] = QStringLiteral("object");

        QJsonObject props;
        QJsonObject entityProp;
        entityProp[QStringLiteral("type")] = QStringLiteral("string");
        entityProp[QStringLiteral("description")] =
            QStringLiteral("L'entity_id dont on veut l'état");
        props[QStringLiteral("entity_id")] = entityProp;
        schema[QStringLiteral("properties")] = props;

        QJsonArray required;
        required.append(QStringLiteral("entity_id"));
        schema[QStringLiteral("required")] = required;

        tools.append(buildToolSchema(
            QStringLiteral("ha_get_state"),
            QStringLiteral("Obtenir l'état actuel d'une entité Home Assistant"),
            schema));
    }

    // ── get_weather : obtenir la météo ──────────────
    {
        QJsonObject schema;
        schema[QStringLiteral("type")] = QStringLiteral("object");

        QJsonObject props;
        QJsonObject cityProp;
        cityProp[QStringLiteral("type")] = QStringLiteral("string");
        cityProp[QStringLiteral("description")] =
            QStringLiteral("Nom de la ville (optionnel, défaut: Paris)");
        props[QStringLiteral("city")] = cityProp;
        schema[QStringLiteral("properties")] = props;

        tools.append(buildToolSchema(
            QStringLiteral("get_weather"),
            QStringLiteral("Obtenir la météo actuelle d'une ville"),
            schema));
    }

    // ── get_datetime : obtenir date et heure ────────
    {
        QJsonObject schema;
        schema[QStringLiteral("type")] = QStringLiteral("object");
        schema[QStringLiteral("properties")] = QJsonObject();

        tools.append(buildToolSchema(
            QStringLiteral("get_datetime"),
            QStringLiteral("Obtenir la date et l'heure actuelles"),
            schema));
    }

    hClaude() << "Outils EXO construits:" << tools.size() << "outils";
    return tools;
}

// ═══════════════════════════════════════════════════════
//  Helpers
// ═══════════════════════════════════════════════════════

void ClaudeAPI::setError(const QString &error)
{
    ++m_totalErrors;
    m_lastError = error;
    hWarning(henriClaude) << error;
    emit errorOccurred(error);
}

void ClaudeAPI::cleanup()
{
    if (m_currentReply) {
        disconnect(m_currentReply, nullptr, this, nullptr);
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
    }
    setStreaming(false);
}

void ClaudeAPI::setStreaming(bool on)
{
    if (m_isStreaming != on) {
        m_isStreaming = on;
        emit streamingChanged();
    }
}