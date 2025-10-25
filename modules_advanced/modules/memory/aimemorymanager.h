#ifndef AIMEMORYMANAGER_H
#define AIMEMORYMANAGER_H

#include <QObject>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include <QVariantMap>
#include <QVariantList>
#include <QDateTime>
#include <QTimer>
#include <QJsonObject>
#include <QJsonArray>

/**
 * @brief Gestionnaire de mémoire AI persistante
 * 
 * Ce système gère:
 * - Stockage des préférences utilisateur
 * - Historique des conversations avec Claude
 * - Profil comportemental de l'utilisateur
 * - Contexte et apprentissage adaptatif
 * - Suggestions personnalisées
 * - Habitudes et routines détectées
 */
class AIMemoryManager : public QObject
{
    Q_OBJECT
    
    // Propriétés pour QML
    Q_PROPERTY(bool isInitialized READ isInitialized NOTIFY initializationStateChanged)
    Q_PROPERTY(QVariantMap userProfile READ getUserProfileVariant NOTIFY userProfileChanged)
    Q_PROPERTY(QVariantList recentConversations READ getRecentConversationsVariant NOTIFY conversationsChanged)
    Q_PROPERTY(QVariantList personalizedSuggestions READ getPersonalizedSuggestionsVariant NOTIFY suggestionsUpdated)
    Q_PROPERTY(QVariantMap dailyStats READ getDailyStatsVariant NOTIFY statsUpdated)
    Q_PROPERTY(int memoryUsage READ memoryUsage NOTIFY memoryUsageChanged)
    
public:
    explicit AIMemoryManager(QObject *parent = nullptr);
    ~AIMemoryManager();
    
    // Types d'informations stockées
    enum MemoryType {
        UserPreference = 0,
        Conversation = 1,
        Context = 2,
        Behavior = 3,
        Suggestion = 4,
        Routine = 5,
        Device = 6,
        Location = 7
    };
    Q_ENUM(MemoryType)
    
    // Niveaux d'importance
    enum ImportanceLevel {
        Low = 1,
        Medium = 2,
        High = 3,
        Critical = 4
    };
    Q_ENUM(ImportanceLevel)
    
    // Types de contexte
    enum ContextType {
        TimeOfDay = 0,
        DayOfWeek = 1,
        Weather = 2,
        Location = 3,
        Activity = 4,
        Mood = 5,
        Social = 6,
        Event = 7
    };
    Q_ENUM(ContextType)
    
    // Structure pour les préférences utilisateur
    struct UserPreference {
        QString key;
        QString category;
        QVariant value;
        ImportanceLevel importance;
        QDateTime lastUpdated;
        QDateTime createdAt;
        int usageCount;
        QVariantMap metadata;
    };
    
    // Structure pour les conversations
    struct Conversation {
        QString id;
        QDateTime timestamp;
        QString userMessage;
        QString assistantResponse;
        QVariantMap context;
        QStringList topics;
        double sentimentScore;
        ImportanceLevel importance;
        QVariantMap metadata;
    };
    
    // Structure pour les routines détectées
    struct DetectedRoutine {
        QString id;
        QString name;
        QString description;
        QTime timePattern;
        QList<int> daysOfWeek; // 1=Lundi, 7=Dimanche
        QStringList actions;
        double confidence;
        int occurrenceCount;
        QDateTime firstDetected;
        QDateTime lastOccurrence;
        bool isActive;
    };
    
    // Structure pour les suggestions
    struct Suggestion {
        QString id;
        QString type;
        QString title;
        QString description;
        QString action;
        QVariantMap parameters;
        double relevanceScore;
        QDateTime validUntil;
        bool isShown;
        bool isAccepted;
        QDateTime createdAt;
    };
    
    // Getters pour QML
    bool isInitialized() const { return m_isInitialized; }
    QVariantMap getUserProfileVariant() const;
    QVariantList getRecentConversationsVariant() const;
    QVariantList getPersonalizedSuggestionsVariant() const;
    QVariantMap getDailyStatsVariant() const;
    int memoryUsage() const { return m_memoryUsageMB; }
    
public slots:
    // Initialisation et configuration
    void initialize(const QString& databasePath = "");
    void shutdown();
    void clearAllMemory();
    void backup(const QString& backupPath);
    void restore(const QString& backupPath);
    void optimize();
    
    // === GESTION DES PRÉFÉRENCES ===
    // Préférences utilisateur
    void setUserPreference(const QString& key, const QVariant& value, 
                          const QString& category = "general", ImportanceLevel importance = Medium);
    QVariant getUserPreference(const QString& key, const QVariant& defaultValue = QVariant()) const;
    void removeUserPreference(const QString& key);
    QVariantMap getUserPreferencesByCategory(const QString& category) const;
    void incrementPreferenceUsage(const QString& key);
    
    // Préférences contextuelles
    void setContextualPreference(const QString& key, const QVariant& value, const QVariantMap& context);
    QVariant getContextualPreference(const QString& key, const QVariantMap& currentContext) const;
    void learnFromUserChoice(const QString& choice, const QVariantMap& context);
    
    // === GESTION DES CONVERSATIONS ===
    // Historique des conversations
    QString storeConversation(const QString& userMessage, const QString& assistantResponse, 
                             const QVariantMap& context = {});
    void updateConversationMetadata(const QString& conversationId, const QVariantMap& metadata);
    QList<Conversation> getRecentConversations(int count = 20) const;
    QList<Conversation> searchConversations(const QString& query, int maxResults = 50) const;
    QList<Conversation> getConversationsByTopic(const QString& topic) const;
    QList<Conversation> getConversationsByTimeRange(const QDateTime& start, const QDateTime& end) const;
    
    // Analyse des conversations
    void analyzeConversationSentiment(const QString& conversationId);
    void extractTopicsFromConversation(const QString& conversationId);
    void identifyUserIntents(const QStringList& recentMessages);
    QStringList getMostDiscussedTopics(int days = 30) const;
    double getUserSatisfactionScore(int days = 7) const;
    
    // === CONTEXTE ET COMPORTEMENT ===
    // Gestion du contexte
    void setCurrentContext(ContextType type, const QVariant& value);
    QVariantMap getCurrentContext() const;
    void recordUserActivity(const QString& activity, const QVariantMap& details = {});
    void recordDeviceInteraction(const QString& deviceId, const QString& action, const QVariantMap& context = {});
    void recordLocationContext(const QString& location, const QVariantMap& details = {});
    
    // Analyse comportementale
    void detectUserPatterns();
    QList<DetectedRoutine> getDetectedRoutines() const;
    void confirmRoutine(const QString& routineId, bool confirmed = true);
    void suggestRoutineAutomation(const QString& routineId);
    QVariantMap getUserBehaviorProfile() const;
    QStringList getPredictedNextActions(const QVariantMap& currentContext) const;
    
    // === APPRENTISSAGE ET SUGGESTIONS ===
    // Système de suggestions
    void generatePersonalizedSuggestions();
    QList<Suggestion> getActiveSuggestions() const;
    void markSuggestionAsShown(const QString& suggestionId);
    void acceptSuggestion(const QString& suggestionId);
    void rejectSuggestion(const QString& suggestionId);
    void rateSuggestion(const QString& suggestionId, int rating); // 1-5
    
    // Apprentissage adaptatif
    void learnFromUserFeedback(const QString& action, bool positive, const QVariantMap& context = {});
    void adaptToUserBehavior();
    void updateRelevanceScores();
    void improveResponseQuality();
    
    // Recommandations intelligentes
    QStringList recommendMusic(const QVariantMap& context = {}) const;
    QStringList recommendApps(const QVariantMap& context = {}) const;
    QStringList recommendSettings(const QVariantMap& context = {}) const;
    QVariantList recommendSmartDeviceActions(const QVariantMap& context = {}) const;
    QString recommendResponse(const QString& userMessage, const QVariantMap& context = {}) const;
    
    // === HABITUDES ET ROUTINES ===
    // Détection de routines
    void recordTimeBasedAction(const QString& action, const QDateTime& timestamp, const QVariantMap& context = {});
    void analyzeTemporalPatterns();
    void detectMorningRoutine();
    void detectEveningRoutine();
    void detectWeekendRoutines();
    void detectSeasonalPatterns();
    
    // Suggestions de routines
    void suggestMorningOptimizations();
    void suggestEveningOptimizations();
    void suggestEnergyEfficiencyActions();
    void suggestHealthAndWellnessActions();
    void suggestSecurityOptimizations();
    
    // === PROFIL UTILISATEUR ===
    // Profil complet
    void buildUserProfile();
    void updateUserDemographics(const QVariantMap& demographics);
    void updateUserInterests(const QStringList& interests);
    void updateUserSkillLevel(const QString& domain, int level); // 1-10
    QVariantMap getPersonalizedSettings() const;
    
    // Préférences d'interaction
    void setPreferredInteractionStyle(const QString& style); // formal, casual, technical, friendly
    void setPreferredResponseLength(int preferredLength); // 1=short, 2=medium, 3=detailed
    void setPreferredTopics(const QStringList& topics);
    void setAvoidedTopics(const QStringList& topics);
    void setLanguagePreferences(const QVariantMap& preferences);
    
    // === ANALYTICS ET INSIGHTS ===
    // Statistiques d'usage
    QVariantMap getDailyUsageStats(const QDate& date = QDate::currentDate()) const;
    QVariantMap getWeeklyUsageStats() const;
    QVariantMap getMonthlyUsageStats() const;
    QVariantList getMostUsedFeatures(int count = 10) const;
    QVariantMap getInteractionPatterns() const;
    
    // Insights personnalisés
    void generatePersonalizedInsights();
    QStringList getProductivityInsights() const;
    QStringList getWellnessInsights() const;
    QStringList getEfficiencyInsights() const;
    QStringList getSecurityInsights() const;
    
    // === CONFIDENTIALITÉ ET SÉCURITÉ ===
    // Gestion de la confidentialité
    void setDataRetentionPolicy(int dayCount);
    void anonymizeOldData();
    void deletePersonalData(const QStringList& categories = {});
    void exportPersonalData(const QString& exportPath) const;
    void setConsentSettings(const QVariantMap& consent);
    
    // Sécurité des données
    void encryptSensitiveData();
    void decryptSensitiveData();
    bool validateDataIntegrity() const;
    void createSecureBackup(const QString& backupPath, const QString& password);
    
    // Tests et diagnostics
    void testDatabaseConnection();
    void validateMemoryStructure();
    void performanceTest();
    void generateMemoryReport() const;
    
signals:
    // État du système
    void initializationStateChanged(bool initialized);
    void memoryUsageChanged(int usageMB);
    void databaseError(const QString& error);
    void backupCompleted(const QString& backupPath);
    void optimizationCompleted();
    
    // Changements de données
    void userProfileChanged();
    void conversationsChanged();
    void suggestionsUpdated();
    void routinesUpdated();
    void statsUpdated();
    
    // Nouvelles détections
    void newRoutineDetected(const QString& routineName, double confidence);
    void behaviorPatternChanged(const QString& pattern, const QVariantMap& details);
    void newSuggestionGenerated(const QString& suggestionId, const QString& title);
    void userPreferenceUpdated(const QString& key, const QVariant& value);
    
    // Insights et recommandations
    void personalizedInsightReady(const QString& insight, const QString& category);
    void recommendationGenerated(const QString& type, const QVariantMap& recommendation);
    void adaptationCompleted(const QString& domain, double improvementScore);
    
    // Confidentialité et sécurité
    void dataRetentionTriggered(int recordsDeleted);
    void privacySettingsChanged(const QVariantMap& settings);
    void dataIntegrityIssue(const QString& issue);
    
private slots:
    void performPeriodicMaintenance();
    void analyzeRecentActivity();
    void updateStatistics();
    void checkMemoryUsage();
    void cleanupExpiredData();
    
private:
    // Base de données
    QSqlDatabase m_database;
    QString m_databasePath;
    bool m_isInitialized;
    int m_memoryUsageMB;
    
    // Cache en mémoire
    QMap<QString, UserPreference> m_preferencesCache;
    QList<Conversation> m_recentConversations;
    QList<DetectedRoutine> m_detectedRoutines;
    QList<Suggestion> m_activeSuggestions;
    QVariantMap m_currentContext;
    QVariantMap m_userProfile;
    
    // Timers et maintenance
    QTimer* m_maintenanceTimer;
    QTimer* m_analysisTimer;
    QTimer* m_cleanupTimer;
    
    // Configuration
    int m_dataRetentionDays;
    QVariantMap m_consentSettings;
    QVariantMap m_privacySettings;
    
    // Méthodes privées de base de données
    bool initializeDatabase();
    bool createTables();
    bool upgradeDatabase(int currentVersion);
    void optimizeDatabase();
    void validateTables();
    
    // Méthodes d'analyse
    void analyzeUserInteractions();
    void calculateRelevanceScores();
    void detectAnomalies();
    void updatePredictionModels();
    void generateInsights();
    
    // Méthodes utilitaires
    QString generateUniqueId() const;
    QByteArray encryptData(const QByteArray& data) const;
    QByteArray decryptData(const QByteArray& encryptedData) const;
    bool executeSqlQuery(const QString& query, const QVariantList& bindings = {});
    QVariantList executeSqlSelect(const QString& query, const QVariantList& bindings = {});
    void logMemoryOperation(const QString& operation, const QVariantMap& details = {});
    
    // Constantes
    static const int DATABASE_VERSION;
    static const int DEFAULT_RETENTION_DAYS;
    static const int MAX_CONVERSATIONS_CACHE;
    static const int MAX_SUGGESTIONS_ACTIVE;
};

#endif // AIMEMORYMANAGER_H