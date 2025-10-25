#include "roomdesignerengine.h"
#include <QDebug>

RoomDesignerEngine::RoomDesignerEngine(QObject *parent)
    : QObject(parent)
    , m_isEnabled(false)
    , m_currentRoom("salon")
    , m_renderMode(RenderMode::Perspective)
{
    qDebug() << "RoomDesignerEngine initialisé";
}

RoomDesignerEngine::~RoomDesignerEngine()
{
    stopRendering();
}

void RoomDesignerEngine::setEnabled(bool enabled)
{
    if (m_isEnabled != enabled) {
        m_isEnabled = enabled;
        emit enabledChanged();
        
        if (enabled) {
            initializeEngine();
        } else {
            stopRendering();
        }
    }
}

void RoomDesignerEngine::loadRoom(const QString& roomName)
{
    if (m_currentRoom != roomName) {
        m_currentRoom = roomName;
        emit currentRoomChanged();
        
        // Simulation de chargement
        qDebug() << "Chargement de la pièce 3D:" << roomName;
        emit roomLoaded(roomName);
    }
}

void RoomDesignerEngine::setRenderMode(RenderMode mode)
{
    if (m_renderMode != mode) {
        m_renderMode = mode;
        emit renderModeChanged();
        
        qDebug() << "Mode de rendu changé:" << static_cast<int>(mode);
    }
}

void RoomDesignerEngine::addFurniture(const QString& type, double x, double y, double z)
{
    qDebug() << "Ajout meuble:" << type << "à position" << x << y << z;
    emit furnitureAdded(type, x, y, z);
}

void RoomDesignerEngine::removeFurniture(const QString& id)
{
    qDebug() << "Suppression meuble:" << id;
    emit furnitureRemoved(id);
}

void RoomDesignerEngine::saveRoom()
{
    qDebug() << "Sauvegarde de la pièce:" << m_currentRoom;
    emit roomSaved(m_currentRoom);
}

void RoomDesignerEngine::initializeEngine()
{
    qDebug() << "Initialisation moteur 3D...";
    // Simulation d'initialisation
    emit engineInitialized();
}

void RoomDesignerEngine::stopRendering()
{
    qDebug() << "Arrêt du moteur 3D";
}