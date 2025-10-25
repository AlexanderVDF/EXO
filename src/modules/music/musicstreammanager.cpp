#include "musicstreammanager.h"
#include <QDebug>

MusicStreamManager::MusicStreamManager(QObject *parent)
    : QObject(parent)
    , m_isStreaming(false)
    , m_currentService(StreamingService::None)
    , m_volume(0.5)
    , m_isMuted(false)
{
    qDebug() << "MusicStreamManager initialisé";
}

MusicStreamManager::~MusicStreamManager()
{
    stopStreaming();
}

void MusicStreamManager::setVolume(double volume)
{
    double newVolume = qBound(0.0, volume, 1.0);
    if (qAbs(m_volume - newVolume) > 0.01) {
        m_volume = newVolume;
        emit volumeChanged();
        qDebug() << "Volume musique ajusté à:" << m_volume;
    }
}

void MusicStreamManager::setMuted(bool muted)
{
    if (m_isMuted != muted) {
        m_isMuted = muted;
        emit mutedChanged();
        qDebug() << "Musique" << (muted ? "coupée" : "activée");
    }
}

void MusicStreamManager::setCurrentService(StreamingService service)
{
    if (m_currentService != service) {
        m_currentService = service;
        emit currentServiceChanged();
        
        QString serviceName;
        switch (service) {
            case StreamingService::Spotify: serviceName = "Spotify"; break;
            case StreamingService::Tidal: serviceName = "Tidal"; break;
            case StreamingService::YouTube: serviceName = "YouTube Music"; break;
            default: serviceName = "Aucun"; break;
        }
        
        qDebug() << "Service de streaming changé:" << serviceName;
    }
}

void MusicStreamManager::playTrack(const QString& trackId, const QString& title, const QString& artist)
{
    if (!isServiceConnected()) {
        emit errorOccurred("Aucun service de streaming connecté");
        return;
    }
    
    m_currentTrackId = trackId;
    m_currentTitle = title;
    m_currentArtist = artist;
    
    m_isStreaming = true;
    emit streamingStateChanged();
    emit currentTrackChanged();
    
    qDebug() << "Lecture démarrée:" << artist << "-" << title;
    emit trackStarted(trackId, title, artist);
}

void MusicStreamManager::pauseStreaming()
{
    if (m_isStreaming) {
        m_isStreaming = false;
        emit streamingStateChanged();
        emit trackPaused();
        qDebug() << "Streaming mis en pause";
    }
}

void MusicStreamManager::resumeStreaming()
{
    if (!m_isStreaming && !m_currentTrackId.isEmpty()) {
        m_isStreaming = true;
        emit streamingStateChanged();
        emit trackResumed();
        qDebug() << "Streaming repris";
    }
}

void MusicStreamManager::stopStreaming()
{
    if (m_isStreaming) {
        m_isStreaming = false;
        emit streamingStateChanged();
        emit trackStopped();
        
        m_currentTrackId.clear();
        m_currentTitle.clear();
        m_currentArtist.clear();
        emit currentTrackChanged();
        
        qDebug() << "Streaming arrêté";
    }
}

void MusicStreamManager::nextTrack()
{
    qDebug() << "Piste suivante demandée";
    emit nextTrackRequested();
}

void MusicStreamManager::previousTrack()
{
    qDebug() << "Piste précédente demandée";
    emit previousTrackRequested();
}

void MusicStreamManager::searchMusic(const QString& query)
{
    if (!isServiceConnected()) {
        emit errorOccurred("Aucun service de streaming connecté pour la recherche");
        return;
    }
    
    qDebug() << "Recherche musicale:" << query;
    emit searchRequested(query);
    
    // Simulation de résultats de recherche
    QStringList results;
    results << "Jazz Café Playlist" << "Morning Jazz Collection" << "Smooth Jazz Hits";
    emit searchResults(query, results);
}

void MusicStreamManager::createPlaylist(const QString& name)
{
    qDebug() << "Création de playlist:" << name;
    emit playlistCreated(name);
}

bool MusicStreamManager::isServiceConnected() const
{
    return m_currentService != StreamingService::None;
}