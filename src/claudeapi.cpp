#include "claudeapi.h"
#include <QNetworkRequest>
#include <QHttpMultiPart>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>
#include <QUrl>
#include <QUrlQuery>

ClaudeAPI::ClaudeAPI(QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_currentReply(nullptr)
    , m_timeoutMs(30000)
    , m_isReady(false)
    , m_model("claude-3-haiku-20240307")
    , m_baseUrl("https://api.anthropic.com/v1/messages")
    , m_requestCount(0)
{
    // Configuration du gestionnaire réseau
    m_networkManager->setTransferTimeout(m_timeoutMs);
    
    // Timer pour timeout personnalisé
    m_timeoutTimer = new QTimer(this);
    m_timeoutTimer->setSingleShot(true);
    connect(m_timeoutTimer, &QTimer::timeout, this, &ClaudeAPI::handleTimeout);
    
    qDebug() << "ClaudeAPI initialisée";
}

ClaudeAPI::~ClaudeAPI()
{
    if (m_currentReply) {
        m_currentReply->deleteLater();
    }
}

void ClaudeAPI::setApiKey(const QString& apiKey)
{
    m_apiKey = apiKey;
    m_isReady = !apiKey.isEmpty();
    
    if (m_isReady) {
        qDebug() << "Clé API Claude configurée";
        testConnection();
    }
}

void ClaudeAPI::setModel(const QString& model)
{
    m_model = model;
    qDebug() << "Modèle Claude configuré:" << model;
}

void ClaudeAPI::setTimeout(int timeoutMs)
{
    m_timeoutMs = timeoutMs;
    m_networkManager->setTransferTimeout(timeoutMs);
}

void ClaudeAPI::sendMessage(const QString& message)
{
    QJsonObject context;
    context["system"] = "Vous êtes Henri, un assistant domotique français intelligent.";
    sendMessageWithContext(message, context);
}

void ClaudeAPI::sendMessageWithContext(const QString& message, const QJsonObject& context)
{
    if (!m_isReady || m_apiKey.isEmpty()) {
        emit errorOccurred("API Claude non configurée");
        return;
    }
    
    if (m_currentReply) {
        qDebug() << "Requête en cours, annulation...";
        cancelCurrentRequest();
    }
    
    // Construction de la requête JSON pour l'API Claude
    QJsonObject requestData;
    requestData["model"] = m_model;
    requestData["max_tokens"] = 1024;
    
    // Messages au format Claude
    QJsonArray messages;
    QJsonObject userMessage;
    userMessage["role"] = "user";
    userMessage["content"] = message;
    messages.append(userMessage);
    
    requestData["messages"] = messages;
    
    // Ajout du contexte système si fourni
    if (context.contains("system")) {
        requestData["system"] = context["system"].toString();
    }
    
    // Préparation de la requête HTTP
    QNetworkRequest request;
    request.setUrl(QUrl("https://api.anthropic.com/v1/messages"));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("x-api-key", m_apiKey.toUtf8());
    request.setRawHeader("anthropic-version", "2023-06-01");
    
    // Envoi de la requête
    QJsonDocument doc(requestData);
    m_currentReply = m_networkManager->post(request, doc.toJson());
    
    // Connexion des signaux
    connect(m_currentReply, &QNetworkReply::finished, this, &ClaudeAPI::handleNetworkReply);
    connect(m_currentReply, &QNetworkReply::errorOccurred, this, &ClaudeAPI::handleNetworkError);
    
    // Démarrage du timer de timeout
    m_timeoutTimer->start(m_timeoutMs);
    
    emit requestStarted();
    qDebug() << "Requête envoyée à Claude:" << message.left(100) + "...";
}

void ClaudeAPI::cancelCurrentRequest()
{
    if (m_currentReply) {
        m_timeoutTimer->stop();
        m_currentReply->abort();
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
        qDebug() << "Requête Claude annulée";
    }
}

void ClaudeAPI::testConnection()
{
    if (!m_isReady) {
        emit errorOccurred("Impossible de tester : API non configurée");
        return;
    }
    
    qDebug() << "Test de connexion Claude...";
    sendMessage("Bonjour Henri, status ?");
}

void ClaudeAPI::handleNetworkReply()
{
    if (!m_currentReply) {
        return;
    }
    
    m_timeoutTimer->stop();
    
    QByteArray responseData = m_currentReply->readAll();
    int httpStatus = m_currentReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    
    m_currentReply->deleteLater();
    m_currentReply = nullptr;
    
    emit requestFinished();
    
    if (httpStatus == 200) {
        // Analyse de la réponse JSON
        QJsonParseError parseError;
        QJsonDocument doc = QJsonDocument::fromJson(responseData, &parseError);
        
        if (parseError.error != QJsonParseError::NoError) {
            emit errorOccurred("Erreur parsing réponse Claude: " + parseError.errorString());
            return;
        }
        
        QJsonObject responseObj = doc.object();
        
        if (responseObj.contains("content")) {
            QJsonArray contentArray = responseObj["content"].toArray();
            if (!contentArray.isEmpty()) {
                QJsonObject firstContent = contentArray[0].toObject();
                if (firstContent.contains("text")) {
                    QString response = firstContent["text"].toString();
                    emit responseReceived(response);
                    qDebug() << "Réponse Claude reçue:" << response.left(100) + "...";
                    return;
                }
            }
        }
        
        emit errorOccurred("Format de réponse Claude inattendu");
        
    } else {
        // Gestion des erreurs HTTP
        QString errorMsg = QString("Erreur API Claude (HTTP %1)").arg(httpStatus);
        
        QJsonParseError parseError;
        QJsonDocument doc = QJsonDocument::fromJson(responseData, &parseError);
        
        if (parseError.error == QJsonParseError::NoError) {
            QJsonObject errorObj = doc.object();
            if (errorObj.contains("error")) {
                QJsonObject error = errorObj["error"].toObject();
                if (error.contains("message")) {
                    errorMsg += ": " + error["message"].toString();
                }
            }
        }
        
        m_lastError = errorMsg;
        emit errorOccurred(errorMsg);
        qDebug() << "Erreur Claude:" << errorMsg;
    }
}

void ClaudeAPI::handleNetworkError(QNetworkReply::NetworkError error)
{
    m_timeoutTimer->stop();
    
    QString errorString;
    switch (error) {
        case QNetworkReply::ConnectionRefusedError:
            errorString = "Connexion refusée par l'API Claude";
            break;
        case QNetworkReply::RemoteHostClosedError:
            errorString = "Connexion fermée par le serveur Claude";
            break;
        case QNetworkReply::HostNotFoundError:
            errorString = "Serveur Claude introuvable";
            break;
        case QNetworkReply::TimeoutError:
            errorString = "Timeout de connexion Claude";
            break;
        case QNetworkReply::SslHandshakeFailedError:
            errorString = "Erreur SSL avec l'API Claude";
            break;
        case QNetworkReply::AuthenticationRequiredError:
            errorString = "Authentification Claude requise (vérifiez la clé API)";
            break;
        default:
            errorString = QString("Erreur réseau Claude: %1").arg(m_currentReply ? m_currentReply->errorString() : "Inconnue");
    }
    
    m_lastError = errorString;
    emit errorOccurred(errorString);
    
    if (m_currentReply) {
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
    }
    
    emit requestFinished();
    qDebug() << "Erreur réseau Claude:" << errorString;
}

void ClaudeAPI::handleTimeout()
{
    qDebug() << "Timeout Claude atteint";
    cancelCurrentRequest();
    emit errorOccurred("Timeout de la requête Claude");
}

void ClaudeAPI::setupNetworkManager()
{
    // Configuration supplémentaire du gestionnaire réseau si nécessaire
    m_networkManager->setTransferTimeout(m_timeoutMs);
}

QNetworkRequest ClaudeAPI::createRequest() const
{
    QNetworkRequest request;
    request.setUrl(QUrl(m_baseUrl));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("x-api-key", m_apiKey.toUtf8());
    request.setRawHeader("anthropic-version", "2023-06-01");
    return request;
}

QJsonObject ClaudeAPI::createRequestPayload(const QString& message, const QJsonObject& context) const
{
    QJsonObject requestData;
    requestData["model"] = m_model;
    requestData["max_tokens"] = 1024;
    
    // Messages au format Claude
    QJsonArray messages;
    QJsonObject userMessage;
    userMessage["role"] = "user";
    userMessage["content"] = message;
    messages.append(userMessage);
    
    requestData["messages"] = messages;
    
    // Ajout du contexte système si fourni
    if (context.contains("system")) {
        requestData["system"] = context["system"].toString();
    }
    
    return requestData;
}

void ClaudeAPI::processResponse(const QByteArray& data)
{
    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    
    if (parseError.error != QJsonParseError::NoError) {
        setError("Erreur parsing réponse Claude: " + parseError.errorString());
        return;
    }
    
    QJsonObject responseObj = doc.object();
    
    if (responseObj.contains("content")) {
        QJsonArray contentArray = responseObj["content"].toArray();
        if (!contentArray.isEmpty()) {
            QJsonObject firstContent = contentArray[0].toObject();
            if (firstContent.contains("text")) {
                QString response = firstContent["text"].toString();
                emit responseReceived(response);
                qDebug() << "Réponse Claude reçue:" << response.left(100) + "...";
                return;
            }
        }
    }
    
    setError("Format de réponse Claude inattendu");
}

void ClaudeAPI::setError(const QString& error)
{
    m_lastError = error;
    emit errorOccurred(error);
}