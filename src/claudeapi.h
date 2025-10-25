#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonObject>
#include <QTimer>

/**
 * @brief Interface pour l'API Claude d'Anthropic
 * 
 * Gère les communications avec Claude Haiku via l'API REST d'Anthropic.
 * Optimisé pour les performances sur Raspberry Pi 5.
 */
class ClaudeAPI : public QObject
{
    Q_OBJECT

public:
    explicit ClaudeAPI(QObject *parent = nullptr);
    ~ClaudeAPI();

    // Configuration
    void setApiKey(const QString& apiKey);
    void setModel(const QString& model = "claude-3-haiku-20240307");
    void setTimeout(int timeoutMs = 30000);

    // État de connexion
    bool isReady() const { return m_isReady; }
    QString lastError() const { return m_lastError; }

public slots:
    void sendMessage(const QString& message);
    void sendMessageWithContext(const QString& message, const QJsonObject& context);
    void cancelCurrentRequest();
    void testConnection();

signals:
    void responseReceived(const QString& response);
    void errorOccurred(const QString& error);
    void connectionStatusChanged(bool connected);
    void requestStarted();
    void requestFinished();

private slots:
    void handleNetworkReply();
    void handleNetworkError(QNetworkReply::NetworkError error);
    void handleTimeout();

private:
    void setupNetworkManager();
    QNetworkRequest createRequest() const;
    QJsonObject createRequestPayload(const QString& message, const QJsonObject& context = {}) const;
    void processResponse(const QByteArray& data);
    void setError(const QString& error);

    QNetworkAccessManager* m_networkManager;
    QNetworkReply* m_currentReply;
    QTimer* m_timeoutTimer;
    
    QString m_apiKey;
    QString m_model;
    QString m_baseUrl;
    int m_timeoutMs;
    
    bool m_isReady;
    QString m_lastError;
    
    // Statistiques et limitations
    int m_requestCount;
    QDateTime m_lastRequestTime;
    static const int MAX_REQUESTS_PER_MINUTE = 50;
};