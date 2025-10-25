#include "ezvizmanager.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkRequest>
#include <QUrlQuery>
#include <QWebSocket>
#include <QCryptographicHash>
#include <QRandomGenerator>
#include <QDebug>
#include <QColor>

// URLs de base de l'API EZVIZ
const QString EzvizManager::API_BASE_URL = "https://open.ys7.com/api/lapp";
const QString EzvizManager::AUTH_ENDPOINT = "/token/get";
const QString EzvizManager::DEVICES_ENDPOINT = "/device/list";
const QString EzvizManager::CONTROL_ENDPOINT = "/device/control";
const QString EzvizManager::WEBSOCKET_ENDPOINT = "wss://open.ys7.com/websocket";

EzvizManager::EzvizManager(QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_isConnected(false)
    , m_isAuthenticating(false)
    , m_currentSecurityMode(Disarmed)
    , m_refreshTimer(new QTimer(this))
    , m_statusTimer(new QTimer(this))
    , m_webSocket(nullptr)
{
    setupNetworking();
    
    qDebug() << "EZVIZ Manager initialisé";
}

void EzvizManager::setupNetworking()
{
    // Configuration des timers de rafraîchissement
    m_refreshTimer->setSingleShot(false);
    m_refreshTimer->setInterval(300000); // 5 minutes
    connect(m_refreshTimer, &QTimer::timeout, this, &EzvizManager::refreshDevices);
    
    m_statusTimer->setSingleShot(false);
    m_statusTimer->setInterval(30000); // 30 secondes
    connect(m_statusTimer, &QTimer::timeout, this, &EzvizManager::checkDevicesStatus);
    
    qDebug() << "Réseau EZVIZ configuré";
}

void EzvizManager::setupWebSocket()
{
    if (m_webSocket) {
        m_webSocket->deleteLater();
    }
    
    m_webSocket = new QWebSocket(QString(), QWebSocketProtocol::VersionLatest, this);
    
    connect(m_webSocket, &QWebSocket::connected, [this]() {
        qDebug() << "WebSocket EZVIZ connecté";
    });
    
    connect(m_webSocket, &QWebSocket::textMessageReceived, 
            this, &EzvizManager::handleWebSocketMessage);
    
    connect(m_webSocket, QOverload<QAbstractSocket::SocketError>::of(&QWebSocket::error),
            [this](QAbstractSocket::SocketError error) {
        qDebug() << "Erreur WebSocket EZVIZ:" << error;
    });
}

void EzvizManager::setCredentials(const QString& appKey, const QString& appSecret)
{
    m_appKey = appKey;
    m_appSecret = appSecret;
    
    qDebug() << "Identifiants API EZVIZ configurés";
}

void EzvizManager::setUserCredentials(const QString& account, const QString& password)
{
    m_userAccount = account;
    m_userPassword = password;
    
    qDebug() << "Identifiants utilisateur EZVIZ configurés";
}

void EzvizManager::authenticate()
{
    if (m_appKey.isEmpty() || m_appSecret.isEmpty() || 
        m_userAccount.isEmpty() || m_userPassword.isEmpty()) {
        emit authenticationFailed("Identifiants manquants");
        return;
    }
    
    m_isAuthenticating = true;
    emit authenticationStateChanged(true);
    
    // Générer timestamp et signature pour l'authentification
    QString timestamp = QString::number(QDateTime::currentMSecsSinceEpoch());
    QString nonce = QString::number(QRandomGenerator::global()->bounded(100000, 999999));
    
    // Créer la signature MD5
    QString signatureString = QString("%1%2%3%4")
                             .arg(m_appKey, m_userAccount, m_userPassword, timestamp);
    QString signature = QCryptographicHash::hash(signatureString.toUtf8(), 
                                               QCryptographicHash::Md5).toHex();
    
    // Préparer la requête d'authentification
    QJsonObject authData;
    authData["appKey"] = m_appKey;
    authData["appSecret"] = m_appSecret;
    authData["account"] = m_userAccount;
    authData["password"] = m_userPassword;
    authData["timestamp"] = timestamp;
    authData["nonce"] = nonce;
    authData["signature"] = signature;
    
    QNetworkRequest request(QUrl(API_BASE_URL + AUTH_ENDPOINT));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    
    QNetworkReply* reply = m_networkManager->post(request, 
                                                 QJsonDocument(authData).toJson());
    
    connect(reply, &QNetworkReply::finished, this, &EzvizManager::handleAuthenticationReply);
    
    qDebug() << "Authentification EZVIZ en cours...";
}

void EzvizManager::handleAuthenticationReply()
{
    QNetworkReply* reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) return;
    
    m_isAuthenticating = false;
    emit authenticationStateChanged(false);
    
    if (reply->error() == QNetworkReply::NoError) {
        QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        QJsonObject response = doc.object();
        
        if (response["code"].toString() == "200") {
            QJsonObject data = response["data"].toObject();
            
            m_accessToken = data["accessToken"].toString();
            m_refreshToken = data["refreshToken"].toString();
            
            // Calculer l'expiration du token (généralement 7 jours)
            int expiresIn = data["expireTime"].toInt();
            m_tokenExpiry = QDateTime::currentDateTime().addSecs(expiresIn);
            
            m_isConnected = true;
            emit connectionStateChanged(true);
            emit authenticationSuccess();
            
            // Démarrer la mise à jour automatique
            refreshDevices();
            m_refreshTimer->start();
            m_statusTimer->start();
            
            // Configurer WebSocket pour événements temps réel
            setupWebSocket();
            if (!m_accessToken.isEmpty()) {
                QString wsUrl = WEBSOCKET_ENDPOINT + "?accessToken=" + m_accessToken;
                m_webSocket->open(QUrl(wsUrl));
            }
            
            qDebug() << "Authentification EZVIZ réussie";
        } else {
            QString error = response["msg"].toString();
            emit authenticationFailed(QString("Erreur API: %1").arg(error));
        }
    } else {
        emit authenticationFailed(reply->errorString());
    }
    
    reply->deleteLater();
}

void EzvizManager::refreshDevices()
{
    if (!m_isConnected) {
        return;
    }
    
    QNetworkRequest request = createAuthorizedRequest(DEVICES_ENDPOINT);
    QNetworkReply* reply = m_networkManager->get(request);
    
    connect(reply, &QNetworkReply::finished, this, &EzvizManager::handleDevicesReply);
    
    logApiCall("devices", "GET", {});
}

void EzvizManager::handleDevicesReply()
{
    QNetworkReply* reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) return;
    
    if (reply->error() == QNetworkReply::NoError) {
        QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        QJsonObject response = doc.object();
        
        if (response["code"].toString() == "200") {
            QJsonArray devices = response["data"].toArray();
            
            // Nettoyer la liste existante
            m_devices.clear();
            
            // Traiter chaque appareil
            for (const QJsonValue& deviceValue : devices) {
                updateDeviceFromJson(deviceValue.toObject());
            }
            
            emit devicesUpdated();
            qDebug() << "Liste des appareils EZVIZ mise à jour:" << m_devices.size() << "appareils";
        }
    } else {
        emit networkError(reply->errorString());
    }
    
    reply->deleteLater();
}

void EzvizManager::updateDeviceFromJson(const QJsonObject& deviceJson)
{
    Device device;
    device.deviceId = deviceJson["deviceSerial"].toString();
    device.name = deviceJson["deviceName"].toString();
    device.type = parseDeviceType(deviceJson["deviceType"].toString());
    device.roomName = deviceJson["roomName"].toString();
    device.lastUpdate = QDateTime::currentDateTime();
    
    // Status de l'appareil
    int status = deviceJson["status"].toInt();
    device.status = static_cast<DeviceStatus>(status);
    
    // Propriétés spécifiques selon le type
    QVariantMap properties;
    
    switch (device.type) {
    case Camera:
        properties["isRecording"] = deviceJson["isRecording"].toBool();
        properties["privacyMode"] = deviceJson["privacyMode"].toBool();
        properties["nightVision"] = deviceJson["nightVision"].toBool();
        properties["motionDetection"] = deviceJson["motionDetection"].toBool();
        properties["resolution"] = deviceJson["resolution"].toString();
        break;
        
    case SmartPlug:
        properties["powered"] = deviceJson["switchStatus"].toBool();
        properties["powerConsumption"] = deviceJson["power"].toDouble();
        properties["voltage"] = deviceJson["voltage"].toDouble();
        properties["current"] = deviceJson["current"].toDouble();
        break;
        
    case SmartBulb:
        properties["powered"] = deviceJson["switchStatus"].toBool();
        properties["brightness"] = deviceJson["brightness"].toInt();
        properties["colorTemperature"] = deviceJson["colorTemperature"].toInt();
        properties["rgbColor"] = deviceJson["rgbColor"].toString();
        break;
        
    case Thermostat:
        properties["currentTemperature"] = deviceJson["currentTemperature"].toDouble();
        properties["targetTemperature"] = deviceJson["targetTemperature"].toDouble();
        properties["mode"] = deviceJson["mode"].toString();
        properties["humidity"] = deviceJson["humidity"].toInt();
        break;
        
    case DoorSensor:
    case MotionSensor:
    case SmokeSensor:
        properties["triggered"] = deviceJson["alarmStatus"].toBool();
        properties["batteryLevel"] = deviceJson["battery"].toInt();
        properties["lastTrigger"] = deviceJson["lastAlarmTime"].toString();
        break;
    }
    
    device.properties = properties;
    m_devices[device.deviceId] = device;
}

EzvizManager::DeviceType EzvizManager::parseDeviceType(const QString& typeString)
{
    if (typeString.contains("camera", Qt::CaseInsensitive)) return Camera;
    if (typeString.contains("plug", Qt::CaseInsensitive)) return SmartPlug;
    if (typeString.contains("bulb", Qt::CaseInsensitive) || 
        typeString.contains("light", Qt::CaseInsensitive)) return SmartBulb;
    if (typeString.contains("thermostat", Qt::CaseInsensitive)) return Thermostat;
    if (typeString.contains("door", Qt::CaseInsensitive)) return DoorSensor;
    if (typeString.contains("motion", Qt::CaseInsensitive) || 
        typeString.contains("pir", Qt::CaseInsensitive)) return MotionSensor;
    if (typeString.contains("smoke", Qt::CaseInsensitive)) return SmokeSensor;
    
    return Unknown;
}

void EzvizManager::setSmartPlugPower(const QString& deviceId, bool powered)
{
    if (!m_devices.contains(deviceId)) {
        emit deviceError(deviceId, "Appareil introuvable");
        return;
    }
    
    QJsonObject controlData;
    controlData["deviceSerial"] = deviceId;
    controlData["command"] = "switch";
    controlData["value"] = powered ? 1 : 0;
    
    makeApiRequest(CONTROL_ENDPOINT, controlData, "POST");
    
    // Mettre à jour localement
    m_devices[deviceId].properties["powered"] = powered;
    emit devicePropertyChanged(deviceId, "powered", powered);
    
    qDebug() << "Prise" << deviceId << (powered ? "allumée" : "éteinte");
}

void EzvizManager::setSmartBulbBrightness(const QString& deviceId, int brightness)
{
    brightness = qBound(0, brightness, 100);
    
    QJsonObject controlData;
    controlData["deviceSerial"] = deviceId;
    controlData["command"] = "brightness";
    controlData["value"] = brightness;
    
    makeApiRequest(CONTROL_ENDPOINT, controlData, "POST");
    
    m_devices[deviceId].properties["brightness"] = brightness;
    emit devicePropertyChanged(deviceId, "brightness", brightness);
    
    qDebug() << "Luminosité ampoule" << deviceId << "réglée à" << brightness << "%";
}

void EzvizManager::setThermostatTemperature(const QString& deviceId, double temperature)
{
    QJsonObject controlData;
    controlData["deviceSerial"] = deviceId;
    controlData["command"] = "setTemperature";
    controlData["value"] = temperature;
    
    makeApiRequest(CONTROL_ENDPOINT, controlData, "POST");
    
    m_devices[deviceId].properties["targetTemperature"] = temperature;
    emit devicePropertyChanged(deviceId, "targetTemperature", temperature);
    
    qDebug() << "Température thermostat" << deviceId << "réglée à" << temperature << "°C";
}

void EzvizManager::setSecurityMode(SecurityMode mode)
{
    if (m_currentSecurityMode != mode) {
        m_currentSecurityMode = mode;
        
        QJsonObject controlData;
        controlData["command"] = "securityMode";
        controlData["mode"] = static_cast<int>(mode);
        
        makeApiRequest("/security/mode", controlData, "POST");
        
        emit securityModeChanged(static_cast<int>(mode));
        
        QString modeStr;
        switch (mode) {
        case Disarmed: modeStr = "Désarmé"; break;
        case Home: modeStr = "Mode maison"; break;
        case Away: modeStr = "Mode absence"; break;
        }
        
        qDebug() << "Mode sécurité changé:" << modeStr;
    }
}

QVariantList EzvizManager::getDevicesVariant() const
{
    QVariantList devicesList;
    
    for (const Device& device : m_devices) {
        QVariantMap deviceMap;
        deviceMap["deviceId"] = device.deviceId;
        deviceMap["name"] = device.name;
        deviceMap["type"] = static_cast<int>(device.type);
        deviceMap["status"] = static_cast<int>(device.status);
        deviceMap["roomName"] = device.roomName;
        deviceMap["properties"] = device.properties;
        deviceMap["lastUpdate"] = device.lastUpdate;
        deviceMap["isOnline"] = device.isOnline();
        
        devicesList.append(deviceMap);
    }
    
    return devicesList;
}

QVariantMap EzvizManager::getHomeStatusVariant() const
{
    return m_homeStatus;
}

void EzvizManager::setCurrentHomeId(const QString& homeId)
{
    if (m_currentHomeId != homeId) {
        m_currentHomeId = homeId;
        emit currentHomeChanged(homeId);
        
        // Rafraîchir les appareils pour cette maison
        refreshDevices();
    }
}

QNetworkRequest EzvizManager::createAuthorizedRequest(const QString& endpoint)
{
    QNetworkRequest request(QUrl(API_BASE_URL + endpoint));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Authorization", QString("Bearer %1").arg(m_accessToken).toUtf8());
    
    return request;
}

void EzvizManager::makeApiRequest(const QString& endpoint, const QJsonObject& data, const QString& method)
{
    QNetworkRequest request = createAuthorizedRequest(endpoint);
    QNetworkReply* reply = nullptr;
    
    if (method == "GET") {
        reply = m_networkManager->get(request);
    } else if (method == "POST") {
        reply = m_networkManager->post(request, QJsonDocument(data).toJson());
    } else if (method == "PUT") {
        reply = m_networkManager->put(request, QJsonDocument(data).toJson());
    }
    
    if (reply) {
        connect(reply, &QNetworkReply::finished, this, &EzvizManager::handleDeviceControlReply);
    }
    
    logApiCall(endpoint, method, data);
}

void EzvizManager::handleDeviceControlReply()
{
    QNetworkReply* reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) return;
    
    if (reply->error() != QNetworkReply::NoError) {
        emit networkError(reply->errorString());
    } else {
        QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        QJsonObject response = doc.object();
        
        if (response["code"].toString() != "200") {
            QString error = response["msg"].toString();
            emit apiError(reply->url().path(), error);
        }
    }
    
    reply->deleteLater();
}

void EzvizManager::handleWebSocketMessage(const QString& message)
{
    QJsonDocument doc = QJsonDocument::fromJson(message.toUtf8());
    QJsonObject eventData = doc.object();
    
    processDeviceEvent(eventData);
}

void EzvizManager::processDeviceEvent(const QJsonObject& eventJson)
{
    QString deviceId = eventJson["deviceSerial"].toString();
    QString eventType = eventJson["eventType"].toString();
    QVariantMap details = eventJson["details"].toObject().toVariantMap();
    
    if (eventType == "motionDetection") {
        emit motionDetected(deviceId, details);
    } else if (eventType == "doorOpen") {
        emit doorOpened(deviceId);
    } else if (eventType == "doorClose") {
        emit doorClosed(deviceId);
    } else if (eventType == "smokeAlarm") {
        emit smokeDetected(deviceId);
    } else if (eventType == "deviceOffline") {
        if (m_devices.contains(deviceId)) {
            m_devices[deviceId].status = Offline;
            emit deviceStatusChanged(deviceId, static_cast<int>(Offline));
        }
    }
}

void EzvizManager::testConnection()
{
    if (m_isConnected) {
        refreshDevices();
        qDebug() << "Test de connexion EZVIZ - OK";
    } else {
        qDebug() << "Test de connexion EZVIZ - Échec (non connecté)";
        emit networkError("Non connecté à EZVIZ");
    }
}

void EzvizManager::logApiCall(const QString& endpoint, const QString& method, const QJsonObject& data)
{
    Q_UNUSED(data)
    qDebug() << "API EZVIZ:" << method << endpoint;
}