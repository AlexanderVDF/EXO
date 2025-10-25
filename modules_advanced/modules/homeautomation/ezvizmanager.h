#ifndef EZVIZMANAGER_H
#define EZVIZMANAGER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QTimer>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariantMap>
#include <QVariantList>
#include <QDateTime>

/**
 * @brief Gestionnaire EZVIZ pour contrôler les appareils domotiques
 * 
 * Cette classe gère la communication avec l'API EZVIZ pour contrôler:
 * - Caméras de sécurité  
 * - Prises connectées
 * - Ampoules intelligentes
 * - Thermostats
 * - Détecteurs (mouvement, porte, etc.)
 */
class EzvizManager : public QObject
{
    Q_OBJECT
    
    // Propriétés pour QML
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY connectionStateChanged)
    Q_PROPERTY(bool isAuthenticating READ isAuthenticating NOTIFY authenticationStateChanged)
    Q_PROPERTY(QVariantList devices READ getDevicesVariant NOTIFY devicesUpdated)
    Q_PROPERTY(QVariantMap homeStatus READ getHomeStatusVariant NOTIFY homeStatusUpdated)
    Q_PROPERTY(QString currentHomeId READ currentHomeId WRITE setCurrentHomeId NOTIFY currentHomeChanged)
    
public:
    explicit EzvizManager(QObject *parent = nullptr);
    
    // Types d'appareils EZVIZ
    enum DeviceType {
        Camera = 0,
        SmartPlug = 1,
        SmartBulb = 2,
        Thermostat = 3,
        DoorSensor = 4,
        MotionSensor = 5,
        SmokeSensor = 6,
        Unknown = 99
    };
    Q_ENUM(DeviceType)
    
    // États des appareils
    enum DeviceStatus {
        Online = 0,
        Offline = 1,
        Sleeping = 2,
        Error = 3
    };
    Q_ENUM(DeviceStatus)
    
    // Modes de sécurité
    enum SecurityMode {
        Disarmed = 0,   // Désarmé
        Home = 1,       // Mode maison
        Away = 2        // Mode absence
    };
    Q_ENUM(SecurityMode)
    
    // Structure pour appareil EZVIZ
    struct Device {
        QString deviceId;
        QString name;
        DeviceType type;
        DeviceStatus status;
        QVariantMap properties;
        QString roomName;
        QDateTime lastUpdate;
        bool isOnline() const { return status == Online; }
    };
    
    // Configuration et authentification
    void setCredentials(const QString& appKey, const QString& appSecret);
    void setUserCredentials(const QString& account, const QString& password);
    
    // Getters pour QML
    bool isConnected() const { return m_isConnected; }
    bool isAuthenticating() const { return m_isAuthenticating; }
    QVariantList getDevicesVariant() const;
    QVariantMap getHomeStatusVariant() const;
    QString currentHomeId() const { return m_currentHomeId; }
    
    // Gestion des maisons/localisations
    void setCurrentHomeId(const QString& homeId);
    
public slots:
    // Authentification et connexion
    void authenticate();
    void disconnect();
    void refreshDevices();
    void refreshHomeStatus();
    
    // Contrôle des caméras
    void startCameraLiveView(const QString& deviceId);
    void stopCameraLiveView(const QString& deviceId);
    void takeCameraSnapshot(const QString& deviceId);
    void setCameraRecording(const QString& deviceId, bool enabled);
    void setCameraPrivacyMode(const QString& deviceId, bool enabled);
    void setCameraNightVision(const QString& deviceId, bool enabled);
    void setCameraMotionDetection(const QString& deviceId, bool enabled);
    
    // Contrôle des prises connectées
    void setSmartPlugPower(const QString& deviceId, bool powered);
    void toggleSmartPlug(const QString& deviceId);
    void setSmartPlugSchedule(const QString& deviceId, const QVariantMap& schedule);
    
    // Contrôle des ampoules
    void setSmartBulbPower(const QString& deviceId, bool powered);
    void setSmartBulbBrightness(const QString& deviceId, int brightness); // 0-100
    void setSmartBulbColor(const QString& deviceId, const QColor& color);
    void setSmartBulbColorTemperature(const QString& deviceId, int temperature); // 2700-6500K
    
    // Contrôle des thermostats
    void setThermostatTemperature(const QString& deviceId, double temperature);
    void setThermostatMode(const QString& deviceId, const QString& mode); // heat, cool, auto, off
    void setThermostatSchedule(const QString& deviceId, const QVariantMap& schedule);
    
    // Gestion de la sécurité
    void setSecurityMode(SecurityMode mode);
    void armSecuritySystem();
    void disarmSecuritySystem();
    void triggerAlarm(const QString& reason = "Test");
    
    // Scénarios et automatisation
    void executeScene(const QString& sceneId);
    void createCustomScene(const QString& name, const QVariantList& actions);
    void setDeviceTimer(const QString& deviceId, const QVariantMap& timerConfig);
    
    // Tests et diagnostics
    void testConnection();
    void testDevice(const QString& deviceId);
    void getDeviceLog(const QString& deviceId);
    
signals:
    // États de connexion
    void connectionStateChanged(bool connected);
    void authenticationStateChanged(bool authenticating);
    void authenticationSuccess();
    void authenticationFailed(const QString& error);
    
    // Mise à jour des données
    void devicesUpdated();
    void homeStatusUpdated();
    void currentHomeChanged(const QString& homeId);
    
    // Événements des appareils
    void deviceStatusChanged(const QString& deviceId, int status);
    void devicePropertyChanged(const QString& deviceId, const QString& property, const QVariant& value);
    
    // Événements caméras
    void cameraSnapshotReady(const QString& deviceId, const QString& imageUrl);
    void cameraMotionDetected(const QString& deviceId, const QVariantMap& details);
    void cameraRecordingStarted(const QString& deviceId);
    void cameraRecordingStopped(const QString& deviceId);
    
    // Événements sécurité
    void securityModeChanged(int mode);
    void alarmTriggered(const QString& deviceId, const QString& reason);
    void securityBreachDetected(const QString& details);
    
    // Événements capteurs
    void motionDetected(const QString& deviceId, const QVariantMap& details);
    void doorOpened(const QString& deviceId);
    void doorClosed(const QString& deviceId);
    void smokeDetected(const QString& deviceId);
    
    // Erreurs et diagnostics
    void networkError(const QString& error);
    void deviceError(const QString& deviceId, const QString& error);
    void apiError(const QString& endpoint, const QString& error);
    
private slots:
    void handleAuthenticationReply();
    void handleDevicesReply();
    void handleDeviceControlReply();
    void handleHomeStatusReply();
    void handleWebSocketMessage(const QString& message);
    void refreshAccessToken();
    void checkDevicesStatus();
    
private:
    // Configuration API
    QNetworkAccessManager* m_networkManager;
    QString m_appKey;
    QString m_appSecret;
    QString m_userAccount;
    QString m_userPassword;
    QString m_accessToken;
    QString m_refreshToken;
    QDateTime m_tokenExpiry;
    
    // État de connexion
    bool m_isConnected;
    bool m_isAuthenticating;
    QString m_currentHomeId;
    SecurityMode m_currentSecurityMode;
    
    // Données des appareils
    QMap<QString, Device> m_devices;
    QVariantMap m_homeStatus;
    QTimer* m_refreshTimer;
    QTimer* m_statusTimer;
    
    // WebSocket pour événements temps réel
    class QWebSocket* m_webSocket;
    QString m_webSocketUrl;
    
    // Méthodes privées
    void setupNetworking();
    void setupWebSocket();
    void makeApiRequest(const QString& endpoint, const QJsonObject& data = {}, 
                       const QString& method = "GET");
    void updateDeviceFromJson(const QJsonObject& deviceJson);
    void processDeviceEvent(const QJsonObject& eventJson);
    DeviceType parseDeviceType(const QString& typeString);
    QNetworkRequest createAuthorizedRequest(const QString& endpoint);
    QString getApiBaseUrl() const;
    void logApiCall(const QString& endpoint, const QString& method, const QJsonObject& data);
    
    // Constantes API
    static const QString API_BASE_URL;
    static const QString AUTH_ENDPOINT;
    static const QString DEVICES_ENDPOINT;
    static const QString CONTROL_ENDPOINT;
    static const QString WEBSOCKET_ENDPOINT;
};

#endif // EZVIZMANAGER_H