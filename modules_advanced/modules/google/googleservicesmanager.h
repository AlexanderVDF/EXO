#ifndef GOOGLESERVICESMANAGER_H
#define GOOGLESERVICESMANAGER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <QVariantMap>
#include <QVariantList>
#include <QGeoCoordinate>
#include <QTimer>

/**
 * @brief Gestionnaire des services Google intégrés
 * 
 * Cette classe gère l'intégration avec:
 * - Google Calendar (événements, rappels)
 * - Gmail (emails, notifications)
 * - Google Drive (stockage de fichiers)
 * - Google Maps (navigation, trafic)
 * - Google Assistant (commandes vocales)
 * - Google Photos (gestion des photos)
 */
class GoogleServicesManager : public QObject
{
    Q_OBJECT
    
    // Propriétés pour QML
    Q_PROPERTY(bool isAuthenticated READ isAuthenticated NOTIFY authenticationStateChanged)
    Q_PROPERTY(QVariantList upcomingEvents READ getUpcomingEventsVariant NOTIFY calendarEventsChanged)
    Q_PROPERTY(QVariantList unreadEmails READ getUnreadEmailsVariant NOTIFY emailsChanged)
    Q_PROPERTY(int unreadEmailCount READ unreadEmailCount NOTIFY emailCountChanged)
    Q_PROPERTY(QVariantMap currentLocation READ getCurrentLocationVariant NOTIFY locationChanged)
    Q_PROPERTY(QVariantMap trafficInfo READ getTrafficInfoVariant NOTIFY trafficInfoChanged)
    Q_PROPERTY(QVariantList recentFiles READ getRecentFilesVariant NOTIFY driveFilesChanged)
    Q_PROPERTY(QString driveStorageUsed READ driveStorageUsed NOTIFY driveStorageChanged)
    
public:
    explicit GoogleServicesManager(QObject *parent = nullptr);
    
    // Services Google supportés
    enum GoogleService {
        Calendar = 0,
        Gmail = 1,
        Drive = 2,
        Maps = 3,
        Photos = 4,
        Assistant = 5
    };
    Q_ENUM(GoogleService)
    
    // Types d'événements Calendar
    enum EventType {
        Meeting = 0,
        Reminder = 1,
        Birthday = 2,
        Holiday = 3,
        Task = 4,
        Custom = 5
    };
    Q_ENUM(EventType)
    
    // Priorités d'email
    enum EmailPriority {
        Low = 0,
        Normal = 1,
        High = 2,
        Urgent = 3
    };
    Q_ENUM(EmailPriority)
    
    // Types de fichiers Drive
    enum DriveFileType {
        Document = 0,
        Spreadsheet = 1,
        Presentation = 2,
        PDF = 3,
        Image = 4,
        Video = 5,
        Audio = 6,
        Archive = 7,
        Folder = 8,
        Other = 9
    };
    Q_ENUM(DriveFileType)
    
    // Modes de navigation Maps
    enum NavigationMode {
        Driving = 0,
        Walking = 1,
        Transit = 2,
        Cycling = 3
    };
    Q_ENUM(NavigationMode)
    
    // Structure pour les événements Calendar
    struct CalendarEvent {
        QString id;
        QString title;
        QString description;
        QDateTime startTime;
        QDateTime endTime;
        QString location;
        QString calendarId;
        EventType type;
        bool isAllDay;
        QStringList attendees;
        QVariantMap reminders;
        QString recurrence;
        QVariantMap metadata;
    };
    
    // Structure pour les emails
    struct Email {
        QString id;
        QString threadId;
        QString from;
        QString to;
        QString cc;
        QString bcc;
        QString subject;
        QString body;
        QString snippet;
        QDateTime dateTime;
        bool isUnread;
        bool isImportant;
        bool isStarred;
        EmailPriority priority;
        QStringList labels;
        QStringList attachments;
        QVariantMap metadata;
    };
    
    // Structure pour les fichiers Drive
    struct DriveFile {
        QString id;
        QString name;
        QString mimeType;
        DriveFileType type;
        qint64 size;
        QDateTime createdTime;
        QDateTime modifiedTime;
        QString webViewLink;
        QString downloadLink;
        QString thumbnailLink;
        QString parentId;
        bool isShared;
        QStringList permissions;
        QVariantMap properties;
    };
    
    // Getters pour QML
    bool isAuthenticated() const { return m_isAuthenticated; }
    QVariantList getUpcomingEventsVariant() const;
    QVariantList getUnreadEmailsVariant() const;
    int unreadEmailCount() const { return m_unreadEmailCount; }
    QVariantMap getCurrentLocationVariant() const;
    QVariantMap getTrafficInfoVariant() const;
    QVariantList getRecentFilesVariant() const;
    QString driveStorageUsed() const { return m_driveStorageUsed; }
    
    // Configuration
    void setGoogleCredentials(const QString& clientId, const QString& clientSecret);
    void setApiKey(const QString& apiKey);
    
public slots:
    // Authentification OAuth2
    void authenticate();
    void authenticateWithRefreshToken(const QString& refreshToken);
    void logout();
    void refreshAccessToken();
    
    // === GOOGLE CALENDAR ===
    // Gestion des événements
    void getCalendarEvents(const QDate& startDate = QDate::currentDate(), int dayCount = 7);
    void getTodayEvents();
    void getUpcomingEvents(int hours = 24);
    QString createEvent(const QString& title, const QDateTime& startTime, const QDateTime& endTime, 
                       const QString& description = "", const QString& location = "");
    void updateEvent(const QString& eventId, const QVariantMap& updates);
    void deleteEvent(const QString& eventId);
    void addEventReminder(const QString& eventId, int minutesBefore);
    
    // Calendriers
    void getCalendars();
    void createCalendar(const QString& name, const QString& description = "");
    void deleteCalendar(const QString& calendarId);
    void setDefaultCalendar(const QString& calendarId);
    
    // Recherche et filtres
    void searchEvents(const QString& query, const QDate& startDate = QDate(), const QDate& endDate = QDate());
    void getEventsByLocation(const QString& location);
    void getRecurringEvents();
    void getBirthdaysThisMonth();
    
    // === GMAIL ===
    // Gestion des emails
    void getUnreadEmails(int maxResults = 10);
    void getRecentEmails(int maxResults = 20);
    void searchEmails(const QString& query);
    void getEmailThread(const QString& threadId);
    void markEmailAsRead(const QString& emailId);
    void markEmailAsUnread(const QString& emailId);
    void starEmail(const QString& emailId, bool starred = true);
    void deleteEmail(const QString& emailId);
    void archiveEmail(const QString& emailId);
    
    // Envoi d'emails
    void sendEmail(const QString& to, const QString& subject, const QString& body, 
                   const QString& cc = "", const QString& bcc = "");
    void replyToEmail(const QString& emailId, const QString& body);
    void forwardEmail(const QString& emailId, const QString& to, const QString& message = "");
    void sendEmailWithAttachment(const QString& to, const QString& subject, const QString& body,
                                const QString& attachmentPath);
    
    // Labels et filtres
    void addLabelToEmail(const QString& emailId, const QString& label);
    void removeLabelFromEmail(const QString& emailId, const QString& label);
    void createEmailFilter(const QString& criteria, const QString& action);
    void getImportantEmails();
    void getPromotionEmails();
    void getSocialEmails();
    
    // === GOOGLE DRIVE ===
    // Gestion des fichiers
    void getRecentFiles(int maxResults = 10);
    void getSharedFiles();
    void getFilesByType(DriveFileType type);
    void searchFiles(const QString& query);
    void getFileInfo(const QString& fileId);
    void downloadFile(const QString& fileId, const QString& localPath);
    void uploadFile(const QString& localPath, const QString& parentFolderId = "");
    void deleteFile(const QString& fileId);
    void moveFileToTrash(const QString& fileId);
    void restoreFileFromTrash(const QString& fileId);
    
    // Dossiers
    void createFolder(const QString& name, const QString& parentFolderId = "");
    void getFolderContents(const QString& folderId);
    void moveFile(const QString& fileId, const QString& newParentId);
    void copyFile(const QString& fileId, const QString& newName = "");
    
    // Partage
    void shareFile(const QString& fileId, const QString& email, const QString& role = "reader");
    void removeFileShare(const QString& fileId, const QString& email);
    void makeFilePublic(const QString& fileId);
    void makeFilePrivate(const QString& fileId);
    void getFilePermissions(const QString& fileId);
    
    // Stockage
    void getDriveStorageInfo();
    void getStorageQuota();
    void cleanupLargeFiles();
    void emptyTrash();
    
    // === GOOGLE MAPS ===
    // Navigation et directions
    void getCurrentLocation();
    void searchPlaces(const QString& query, const QGeoCoordinate& center = QGeoCoordinate());
    void getDirections(const QGeoCoordinate& origin, const QGeoCoordinate& destination, 
                      NavigationMode mode = Driving);
    void getDirectionsToHome();
    void getDirectionsToWork();
    void startNavigation(const QGeoCoordinate& destination);
    void stopNavigation();
    
    // Trafic et itinéraires
    void getTrafficInfo();
    void getAlternativeRoutes(const QGeoCoordinate& origin, const QGeoCoordinate& destination);
    void getETAToDestination(const QGeoCoordinate& destination);
    void getCommuteInfo();
    void getTravelTimeToWork();
    void getTravelTimeToHome();
    
    // Points d'intérêt
    void findNearbyPlaces(const QString& type, int radiusMeters = 5000);
    void findRestaurants(const QString& cuisine = "");
    void findGasStations();
    void findParking();
    void findHotels();
    void getPlaceDetails(const QString& placeId);
    void ratePlaces(const QString& placeId, int rating);
    
    // Lieux favoris
    void saveHomeAddress(const QGeoCoordinate& coordinate);
    void saveWorkAddress(const QGeoCoordinate& coordinate);
    void addFavoritePlace(const QString& name, const QGeoCoordinate& coordinate);
    void removeFavoritePlace(const QString& placeId);
    void getFavoritePlaces();
    
    // === GOOGLE PHOTOS ===
    void getRecentPhotos(int count = 20);
    void uploadPhoto(const QString& filePath);
    void createAlbum(const QString& name);
    void addPhotoToAlbum(const QString& photoId, const QString& albumId);
    void searchPhotos(const QString& query);
    void getPhotosByDate(const QDate& date);
    void getPhotosByLocation(const QGeoCoordinate& location, int radiusKm = 1);
    
    // === INTÉGRATION ASSISTANT ===
    // Commandes vocales
    void processVoiceCommand(const QString& command);
    void getWeatherFromAssistant();
    void setTimerViaAssistant(int minutes, const QString& label = "");
    void setAlarmViaAssistant(const QTime& time, const QString& label = "");
    void askAssistantQuestion(const QString& question);
    void controlSmartDevicesViaAssistant(const QString& command);
    
    // Routines et automatisation
    void createMorningRoutine();
    void createEveningRoutine();
    void triggerCustomRoutine(const QString& routineName);
    void scheduleRoutine(const QString& routineName, const QDateTime& time);
    
    // Tests et diagnostics
    void testGoogleConnection();
    void validateApiCredentials();
    void checkServiceQuotas();
    
signals:
    // Authentification
    void authenticationStateChanged(bool authenticated);
    void authenticationRequired(const QString& authUrl);
    void authenticationSuccess();
    void authenticationFailed(const QString& error);
    void tokenRefreshed();
    
    // Calendar
    void calendarEventsChanged();
    void eventCreated(const QString& eventId);
    void eventUpdated(const QString& eventId);
    void eventDeleted(const QString& eventId);
    void eventReminder(const QString& eventId, const QString& title, int minutesUntil);
    void upcomingEventNotification(const QString& eventId, const QString& title, const QDateTime& startTime);
    
    // Gmail
    void emailsChanged();
    void emailCountChanged(int count);
    void newEmailReceived(const QString& from, const QString& subject);
    void emailSent(const QString& to, const QString& subject);
    void importantEmailReceived(const QString& emailId);
    
    // Drive
    void driveFilesChanged();
    void driveStorageChanged(const QString& used, const QString& total);
    void fileUploaded(const QString& fileId, const QString& name);
    void fileDownloaded(const QString& fileId, const QString& localPath);
    void fileShared(const QString& fileId, const QString& email);
    void driveQuotaWarning(int percentUsed);
    
    // Maps
    void locationChanged(const QGeoCoordinate& location);
    void trafficInfoChanged();
    void directionsReceived(const QVariantMap& directions);
    void navigationStarted(const QString& destination);
    void navigationStopped();
    void placeSearchResults(const QVariantList& places);
    void etaUpdated(const QString& destination, int minutes);
    
    // Photos
    void recentPhotosUpdated();
    void photoUploaded(const QString& photoId);
    void albumCreated(const QString& albumId, const QString& name);
    
    // Assistant
    void voiceCommandProcessed(const QString& command, const QString& response);
    void assistantResponse(const QString& response);
    void routineExecuted(const QString& routineName);
    
    // Erreurs et événements
    void networkError(const QString& service, const QString& error);
    void apiError(const QString& service, const QString& error);
    void quotaExceeded(const QString& service);
    void serviceUnavailable(const QString& service);
    
private slots:
    void handleAuthenticationReply();
    void handleCalendarReply();
    void handleGmailReply();
    void handleDriveReply();
    void handleMapsReply();
    void handlePhotosReply();
    void checkForUpdates();
    void refreshData();
    
private:
    // Configuration
    QNetworkAccessManager* m_networkManager;
    QString m_clientId;
    QString m_clientSecret;
    QString m_apiKey;
    
    // Authentification OAuth2
    bool m_isAuthenticated;
    QString m_accessToken;
    QString m_refreshToken;
    QDateTime m_tokenExpiry;
    
    // Données en cache
    QList<CalendarEvent> m_calendarEvents;
    QList<Email> m_emails;
    int m_unreadEmailCount;
    QList<DriveFile> m_driveFiles;
    QString m_driveStorageUsed;
    QString m_driveStorageTotal;
    QGeoCoordinate m_currentLocation;
    QVariantMap m_trafficInfo;
    
    // Timers
    QTimer* m_updateTimer;
    QTimer* m_locationTimer;
    QTimer* m_trafficTimer;
    
    // Lieux favoris
    QGeoCoordinate m_homeAddress;
    QGeoCoordinate m_workAddress;
    QVariantList m_favoritePlaces;
    
    // Méthodes privées
    void setupNetworking();
    void makeGoogleApiRequest(const QString& service, const QString& endpoint, 
                             const QVariantMap& params = {}, const QString& method = "GET");
    QNetworkRequest createAuthorizedRequest(const QString& url);
    void processCalendarEvents(const QJsonArray& eventsArray);
    void processEmails(const QJsonArray& emailsArray);
    void processDriveFiles(const QJsonArray& filesArray);
    void processPlacesResults(const QJsonArray& placesArray);
    CalendarEvent parseCalendarEvent(const QJsonObject& eventJson);
    Email parseEmail(const QJsonObject& emailJson);
    DriveFile parseDriveFile(const QJsonObject& fileJson);
    QString formatEmailBody(const QJsonObject& bodyJson);
    DriveFileType getDriveFileType(const QString& mimeType);
    void logGoogleApiCall(const QString& service, const QString& endpoint, const QString& method);
    
    // Constantes API
    static const QString GOOGLE_OAUTH_URL;
    static const QString GOOGLE_API_BASE;
    static const QString CALENDAR_API_VERSION;
    static const QString GMAIL_API_VERSION;
    static const QString DRIVE_API_VERSION;
    static const QString MAPS_API_VERSION;
    static const QString PHOTOS_API_VERSION;
};

#endif // GOOGLESERVICESMANAGER_H