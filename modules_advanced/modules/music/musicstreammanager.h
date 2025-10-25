#ifndef MUSICSTREAMMANAGER_H
#define MUSICSTREAMMANAGER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QTimer>
#include <QVariantMap>
#include <QVariantList>
#include <QJsonObject>
#include <QJsonArray>

/**
 * @brief Gestionnaire de streaming musical pour Tidal et Spotify
 * 
 * Cette classe gère:
 * - Authentification aux services de streaming
 * - Recherche et navigation musicale
 * - Contrôle de la lecture
 * - Playlists et favoris
 * - Audio multi-room
 * - Intégration vocale
 */
class MusicStreamManager : public QObject
{
    Q_OBJECT
    
    // Propriétés pour QML
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY connectionStateChanged)
    Q_PROPERTY(QString currentService READ currentService WRITE setCurrentService NOTIFY currentServiceChanged)
    Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY playbackStateChanged)
    Q_PROPERTY(bool isPaused READ isPaused NOTIFY playbackStateChanged)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(QVariantMap currentTrack READ getCurrentTrackVariant NOTIFY currentTrackChanged)
    Q_PROPERTY(QVariantList queue READ getQueueVariant NOTIFY queueChanged)
    Q_PROPERTY(QVariantList playlists READ getPlaylistsVariant NOTIFY playlistsChanged)
    Q_PROPERTY(int position READ position NOTIFY positionChanged)
    Q_PROPERTY(int duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(bool shuffleEnabled READ shuffleEnabled WRITE setShuffleEnabled NOTIFY shuffleModeChanged)
    Q_PROPERTY(QString repeatMode READ repeatMode WRITE setRepeatMode NOTIFY repeatModeChanged)
    
public:
    explicit MusicStreamManager(QObject *parent = nullptr);
    ~MusicStreamManager();
    
    // Services de streaming supportés
    enum StreamingService {
        None = 0,
        Spotify = 1,
        Tidal = 2,
        LocalLibrary = 3
    };
    Q_ENUM(StreamingService)
    
    // États de lecture
    enum PlaybackState {
        Stopped = 0,
        Playing = 1,
        Paused = 2,
        Loading = 3,
        Error = 4
    };
    Q_ENUM(PlaybackState)
    
    // Modes de répétition
    enum RepeatMode {
        NoRepeat = 0,
        RepeatOne = 1,
        RepeatAll = 2
    };
    Q_ENUM(RepeatMode)
    
    // Qualité audio
    enum AudioQuality {
        Normal = 0,    // 160 kbps
        High = 1,      // 320 kbps
        Lossless = 2,  // FLAC
        Master = 3     // MQA (Tidal)
    };
    Q_ENUM(AudioQuality)
    
    // Structure pour les pistes
    struct Track {
        QString id;
        QString title;
        QString artist;
        QString album;
        QString albumArt;
        int duration; // en secondes
        int trackNumber;
        int year;
        QString genre;
        bool isExplicit;
        QString streamUrl;
        AudioQuality quality;
        StreamingService service;
        QVariantMap metadata;
    };
    
    // Structure pour les playlists
    struct Playlist {
        QString id;
        QString name;
        QString description;
        QString imageUrl;
        int trackCount;
        int duration;
        QString owner;
        bool isPublic;
        bool isCollaborative;
        QList<Track> tracks;
        StreamingService service;
        QDateTime lastModified;
    };
    
    // Getters pour QML
    bool isConnected() const { return m_isConnected; }
    QString currentService() const;
    bool isPlaying() const { return m_playbackState == Playing; }
    bool isPaused() const { return m_playbackState == Paused; }
    double volume() const { return m_volume; }
    QVariantMap getCurrentTrackVariant() const;
    QVariantList getQueueVariant() const;
    QVariantList getPlaylistsVariant() const;
    int position() const;
    int duration() const;
    bool shuffleEnabled() const { return m_shuffleEnabled; }
    QString repeatMode() const;
    
    // Configuration des services
    void setSpotifyCredentials(const QString& clientId, const QString& clientSecret);
    void setTidalCredentials(const QString& clientId, const QString& clientSecret);
    void setCurrentService(const QString& service);
    
public slots:
    // Authentification
    void authenticateSpotify();
    void authenticateTidal();
    void authenticateWithToken(const QString& token);
    void logout();
    void refreshToken();
    
    // Contrôle de lecture
    void play();
    void pause();
    void stop();
    void next();
    void previous();
    void seek(int position); // en millisecondes
    void setVolume(double volume); // 0.0 - 1.0
    void setShuffleEnabled(bool enabled);
    void setRepeatMode(const QString& mode);
    void setAudioQuality(int quality);
    
    // Lecture de contenu
    void playTrack(const QString& trackId);
    void playAlbum(const QString& albumId, int startTrack = 0);
    void playPlaylist(const QString& playlistId, int startTrack = 0);
    void playArtistTopTracks(const QString& artistId);
    void playQueue();
    void playRadioStation(const QString& stationId);
    
    // Gestion de la file d'attente
    void addToQueue(const QString& trackId);
    void addAlbumToQueue(const QString& albumId);
    void addPlaylistToQueue(const QString& playlistId);
    void removeFromQueue(int index);
    void clearQueue();
    void moveQueueItem(int fromIndex, int toIndex);
    void shuffleQueue();
    
    // Recherche
    void searchTracks(const QString& query, int limit = 50);
    void searchArtists(const QString& query, int limit = 20);
    void searchAlbums(const QString& query, int limit = 20);
    void searchPlaylists(const QString& query, int limit = 20);
    void searchAll(const QString& query);
    void getRecommendations(const QStringList& seedTracks = {}, const QStringList& seedArtists = {});
    
    // Playlists et favoris
    void createPlaylist(const QString& name, const QString& description = "", bool isPublic = false);
    void deletePlaylist(const QString& playlistId);
    void addToPlaylist(const QString& playlistId, const QString& trackId);
    void removeFromPlaylist(const QString& playlistId, const QString& trackId);
    void followPlaylist(const QString& playlistId);
    void unfollowPlaylist(const QString& playlistId);
    void getUserPlaylists();
    void getFeaturedPlaylists();
    void getNewReleases();
    
    // Favoris
    void addToFavorites(const QString& trackId);
    void removeFromFavorites(const QString& trackId);
    void addAlbumToFavorites(const QString& albumId);
    void removeAlbumFromFavorites(const QString& albumId);
    void followArtist(const QString& artistId);
    void unfollowArtist(const QString& artistId);
    void getFavoriteTracks();
    void getFavoriteAlbums();
    void getFollowedArtists();
    
    // Découverte musicale
    void getTopTracks(const QString& timeRange = "medium_term"); // short, medium, long
    void getTopArtists(const QString& timeRange = "medium_term");
    void getRecentlyPlayed(int limit = 20);
    void getBrowseCategories();
    void getCategoryPlaylists(const QString& categoryId);
    void getGenreSeeds();
    
    // Audio multi-room
    void getAvailableDevices();
    void setActiveDevice(const QString& deviceId);
    void createSpeakerGroup(const QString& groupName, const QStringList& deviceIds);
    void addDeviceToGroup(const QString& groupId, const QString& deviceId);
    void removeDeviceFromGroup(const QString& groupId, const QString& deviceId);
    void setGroupVolume(const QString& groupId, double volume);
    void syncPlaybackToGroup(const QString& groupId);
    
    // Commandes vocales
    void playArtist(const QString& artistName);
    void playGenre(const QString& genreName);
    void playMood(const QString& moodName);
    void playDecade(const QString& decade);
    void playForActivity(const QString& activity); // workout, study, party, etc.
    void playMyMusic();
    void skipToNextGenre();
    void enablePartyMode();
    void disablePartyMode();
    
    // Contrôle intelligent
    void pauseForCall();
    void resumeAfterCall();
    void lowerVolumeForAnnouncement();
    void restoreVolumeAfterAnnouncement();
    void scheduleWakeUpMusic(const QDateTime& time, const QString& playlistId);
    void scheduleAutoStop(const QDateTime& time);
    
    // Tests et diagnostics
    void testConnection();
    void testAudioOutput();
    void getStreamingQuality();
    void checkNetworkBandwidth();
    
signals:
    // État de connexion
    void connectionStateChanged(bool connected);
    void currentServiceChanged(const QString& service);
    void authenticationRequired(const QString& service, const QString& authUrl);
    void authenticationSuccess(const QString& service);
    void authenticationFailed(const QString& service, const QString& error);
    
    // État de lecture
    void playbackStateChanged(int state);
    void currentTrackChanged();
    void positionChanged(int position);
    void durationChanged(int duration);
    void volumeChanged(double volume);
    void shuffleModeChanged(bool enabled);
    void repeatModeChanged(const QString& mode);
    void audioQualityChanged(int quality);
    
    // File d'attente et playlists
    void queueChanged();
    void playlistsChanged();
    void playlistCreated(const QString& playlistId);
    void playlistDeleted(const QString& playlistId);
    void trackAddedToPlaylist(const QString& playlistId, const QString& trackId);
    void trackRemovedFromPlaylist(const QString& playlistId, const QString& trackId);
    
    // Résultats de recherche
    void searchResultsReady(const QString& query, const QVariantMap& results);
    void recommendationsReady(const QVariantList& tracks);
    void featuredPlaylistsReady(const QVariantList& playlists);
    void newReleasesReady(const QVariantList& albums);
    void topTracksReady(const QVariantList& tracks);
    void recentlyPlayedReady(const QVariantList& tracks);
    
    // Favoris
    void trackAddedToFavorites(const QString& trackId);
    void trackRemovedFromFavorites(const QString& trackId);
    void artistFollowed(const QString& artistId);
    void artistUnfollowed(const QString& artistId);
    
    // Multi-room
    void devicesUpdated(const QVariantList& devices);
    void activeDeviceChanged(const QString& deviceId);
    void speakerGroupCreated(const QString& groupId);
    void speakerGroupUpdated(const QString& groupId);
    
    // Erreurs et événements
    void networkError(const QString& error);
    void streamingError(const QString& error);
    void playbackError(const QString& trackId, const QString& error);
    void bufferStatusChanged(int percent);
    void bandwidthWarning(const QString& message);
    
private slots:
    void handleSpotifyAuthReply();
    void handleTidalAuthReply();
    void handleSearchReply();
    void handlePlaybackReply();
    void handlePlaylistReply();
    void updatePosition();
    void checkBufferStatus();
    void handleMediaPlayerStateChanged();
    void handleMediaPlayerError();
    
private:
    // Configuration
    QNetworkAccessManager* m_networkManager;
    QString m_spotifyClientId;
    QString m_spotifyClientSecret;
    QString m_tidalClientId;
    QString m_tidalClientSecret;
    
    // Authentification
    StreamingService m_currentService;
    QString m_accessToken;
    QString m_refreshToken;
    QDateTime m_tokenExpiry;
    bool m_isConnected;
    
    // Lecture audio
    QMediaPlayer* m_mediaPlayer;
    QAudioOutput* m_audioOutput;
    PlaybackState m_playbackState;
    double m_volume;
    bool m_shuffleEnabled;
    RepeatMode m_repeatMode;
    AudioQuality m_audioQuality;
    
    // Contenu musical
    Track m_currentTrack;
    QList<Track> m_queue;
    QList<Playlist> m_playlists;
    int m_currentQueueIndex;
    
    // Timers et état
    QTimer* m_positionTimer;
    QTimer* m_bufferTimer;
    QTimer* m_reconnectTimer;
    
    // Multi-room
    QVariantList m_availableDevices;
    QString m_activeDeviceId;
    QVariantMap m_speakerGroups;
    
    // Méthodes privées
    void setupAudioSystem();
    void setupNetworking();
    void makeSpotifyRequest(const QString& endpoint, const QVariantMap& params = {}, const QString& method = "GET");
    void makeTidalRequest(const QString& endpoint, const QVariantMap& params = {}, const QString& method = "GET");
    QNetworkRequest createAuthorizedRequest(const QString& url);
    void processTrackData(const QJsonObject& trackJson, StreamingService service);
    void processPlaylistData(const QJsonObject& playlistJson, StreamingService service);
    void processSearchResults(const QJsonObject& resultsJson);
    void updateCurrentTrack(const Track& track);
    void advanceQueue();
    QString getStreamUrl(const Track& track);
    void handlePlaybackEnd();
    void logStreamingActivity(const QString& action, const QString& trackId = "");
    
    // Constantes API
    static const QString SPOTIFY_API_BASE;
    static const QString SPOTIFY_AUTH_URL;
    static const QString TIDAL_API_BASE;
    static const QString TIDAL_AUTH_URL;
};

#endif // MUSICSTREAMMANAGER_H