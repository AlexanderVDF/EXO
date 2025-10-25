#ifndef ROOMDESIGNERENGINE_H
#define ROOMDESIGNERENGINE_H

#include <QObject>
#include <QVector3D>
#include <QQuaternion>
#include <QColor>
#include <QVariantMap>
#include <QVariantList>
#include <Qt3DCore/QEntity>
#include <Qt3DCore/QTransform>
#include <Qt3DRender/QCamera>
#include <Qt3DRender/QMesh>
#include <Qt3DRender/QMaterial>
#include <QJsonObject>
#include <QJsonArray>

class Qt3DCore::QEntity;
class Qt3DCore::QTransform;
class Qt3DRender::QCamera;
class Qt3DExtras::Qt3DWindow;

/**
 * @brief Moteur de conception 3D pour l'aménagement d'appartement
 * 
 * Ce moteur permet de:
 * - Créer et visualiser des pièces en 3D
 * - Placer des meubles et objets
 * - Positionner des appareils domotiques
 * - Naviguer dans l'espace 3D
 * - Exporter/importer des configurations
 */
class RoomDesignerEngine : public QObject
{
    Q_OBJECT
    
    // Propriétés pour QML
    Q_PROPERTY(bool isInitialized READ isInitialized NOTIFY initializationStateChanged)
    Q_PROPERTY(QString currentRoom READ currentRoom WRITE setCurrentRoom NOTIFY currentRoomChanged)
    Q_PROPERTY(QVariantList rooms READ getRoomsVariant NOTIFY roomsChanged)
    Q_PROPERTY(QVariantList furniture READ getFurnitureVariant NOTIFY furnitureChanged)
    Q_PROPERTY(QVariantList devices READ getDevicesVariant NOTIFY devicesChanged)
    Q_PROPERTY(QVector3D cameraPosition READ cameraPosition WRITE setCameraPosition NOTIFY cameraPositionChanged)
    Q_PROPERTY(QVector3D cameraTarget READ cameraTarget WRITE setCameraTarget NOTIFY cameraTargetChanged)
    Q_PROPERTY(bool editMode READ editMode WRITE setEditMode NOTIFY editModeChanged)
    
public:
    explicit RoomDesignerEngine(QObject *parent = nullptr);
    ~RoomDesignerEngine();
    
    // Types d'éléments 3D
    enum ElementType {
        Wall = 0,
        Floor = 1,
        Ceiling = 2,
        Door = 3,
        Window = 4,
        Furniture = 5,
        Device = 6,
        Lighting = 7
    };
    Q_ENUM(ElementType)
    
    // Types de meubles
    enum FurnitureType {
        // Salon
        Sofa = 0,
        Armchair = 1,
        CoffeeTable = 2,
        TVStand = 3,
        Bookshelf = 4,
        
        // Chambre
        Bed = 10,
        Wardrobe = 11,
        Nightstand = 12,
        Dresser = 13,
        
        // Cuisine
        KitchenCounter = 20,
        Refrigerator = 21,
        Stove = 22,
        Dishwasher = 23,
        KitchenTable = 24,
        
        // Salle de bain
        Bathtub = 30,
        Shower = 31,
        Toilet = 32,
        Sink = 33,
        
        // Bureau
        Desk = 40,
        OfficeChair = 41,
        FilingCabinet = 42,
        
        // Général
        CustomFurniture = 99
    };
    Q_ENUM(FurnitureType)
    
    // Modes de vue
    enum ViewMode {
        Perspective = 0,
        TopView = 1,
        FrontView = 2,
        SideView = 3,
        WalkThrough = 4
    };
    Q_ENUM(ViewMode)
    
    // Structure pour les éléments 3D
    struct Element3D {
        QString id;
        QString name;
        ElementType type;
        QVector3D position;
        QVector3D rotation;
        QVector3D scale;
        QColor color;
        QString materialType;
        QString modelPath;
        QVariantMap properties;
        QString roomId;
        bool isVisible;
        bool isSelectable;
        
        // Transform Qt3D
        Qt3DCore::QEntity* entity;
        Qt3DCore::QTransform* transform;
    };
    
    // Structure pour les pièces
    struct Room {
        QString id;
        QString name;
        QString type; // living, bedroom, kitchen, bathroom, etc.
        QVector3D dimensions; // largeur, profondeur, hauteur
        QColor wallColor;
        QColor floorColor;
        QColor ceilingColor;
        QString floorMaterial;
        QString wallMaterial;
        QList<QString> elementIds;
        QVariantMap metadata;
    };
    
    // Getters pour QML
    bool isInitialized() const { return m_isInitialized; }
    QString currentRoom() const { return m_currentRoomId; }
    QVariantList getRoomsVariant() const;
    QVariantList getFurnitureVariant() const;
    QVariantList getDevicesVariant() const;
    QVector3D cameraPosition() const;
    QVector3D cameraTarget() const;
    bool editMode() const { return m_editMode; }
    
    // Setters
    void setCurrentRoom(const QString& roomId);
    void setCameraPosition(const QVector3D& position);
    void setCameraTarget(const QVector3D& target);
    void setEditMode(bool enabled);
    
public slots:
    // Initialisation du moteur 3D
    void initialize();
    void shutdown();
    void reset();
    
    // Gestion des pièces
    QString createRoom(const QString& name, const QString& type, const QVector3D& dimensions);
    void deleteRoom(const QString& roomId);
    void updateRoom(const QString& roomId, const QVariantMap& properties);
    void setRoomDimensions(const QString& roomId, const QVector3D& dimensions);
    void setRoomColors(const QString& roomId, const QColor& walls, const QColor& floor, const QColor& ceiling);
    void setRoomMaterials(const QString& roomId, const QString& wallMaterial, const QString& floorMaterial);
    
    // Gestion des meubles
    QString addFurniture(FurnitureType type, const QString& name, const QVector3D& position, const QString& roomId = QString());
    QString addCustomFurniture(const QString& modelPath, const QString& name, const QVector3D& position, const QString& roomId = QString());
    void removeFurniture(const QString& furnitureId);
    void moveFurniture(const QString& furnitureId, const QVector3D& newPosition);
    void rotateFurniture(const QString& furnitureId, const QVector3D& rotation);
    void scaleFurniture(const QString& furnitureId, const QVector3D& scale);
    void setFurnitureColor(const QString& furnitureId, const QColor& color);
    void setFurnitureMaterial(const QString& furnitureId, const QString& material);
    
    // Gestion des appareils domotiques
    QString addSmartDevice(const QString& deviceId, const QString& deviceType, const QVector3D& position, const QString& roomId = QString());
    void removeSmartDevice(const QString& elementId);
    void moveSmartDevice(const QString& elementId, const QVector3D& newPosition);
    void updateSmartDeviceStatus(const QString& deviceId, const QVariantMap& status);
    
    // Navigation et caméra
    void setViewMode(ViewMode mode);
    void centerCameraOnRoom(const QString& roomId = QString());
    void centerCameraOnElement(const QString& elementId);
    void zoomIn();
    void zoomOut();
    void resetCamera();
    void moveCamera(const QVector3D& direction);
    void rotateCamera(float yaw, float pitch);
    void enableFlyMode(bool enabled);
    
    // Sélection et interaction
    void selectElement(const QString& elementId);
    void deselectAll();
    QStringList getSelectedElements() const;
    QString getElementAtPosition(const QVector3D& worldPosition) const;
    void highlightElement(const QString& elementId, bool highlight = true);
    
    // Mesures et outils
    void startMeasuring();
    void stopMeasuring();
    double measureDistance(const QVector3D& point1, const QVector3D& point2) const;
    void showGrid(bool visible);
    void showAxes(bool visible);
    void showDimensions(bool visible);
    
    // Éclairage et rendu
    void setAmbientLight(const QColor& color, float intensity);
    void addDirectionalLight(const QVector3D& direction, const QColor& color, float intensity);
    void addPointLight(const QVector3D& position, const QColor& color, float intensity, float range);
    void setRenderQuality(const QString& quality); // low, medium, high, ultra
    void enableShadows(bool enabled);
    void enableReflections(bool enabled);
    
    // Textures et matériaux
    void loadTexture(const QString& name, const QString& filePath);
    void createMaterial(const QString& name, const QVariantMap& properties);
    void applyMaterialToElement(const QString& elementId, const QString& materialName);
    QStringList getAvailableMaterials() const;
    
    // Import/Export
    void saveScene(const QString& filePath);
    void loadScene(const QString& filePath);
    void exportTo3D(const QString& filePath, const QString& format = "obj"); // obj, fbx, gltf
    void exportToImage(const QString& filePath, const QSize& resolution = QSize(1920, 1080));
    void exportFloorPlan(const QString& filePath);
    
    // Configuration prédéfinie
    void createLivingRoom(const QVector3D& dimensions);
    void createBedroom(const QVector3D& dimensions);
    void createKitchen(const QVector3D& dimensions);
    void createBathroom(const QVector3D& dimensions);
    void createOffice(const QVector3D& dimensions);
    
    // Tests et débogage
    void enableDebugMode(bool enabled);
    void showBoundingBoxes(bool visible);
    void showWireframes(bool visible);
    void dumpSceneGraph() const;
    void validateScene() const;
    
signals:
    // État du moteur
    void initializationStateChanged(bool initialized);
    void currentRoomChanged(const QString& roomId);
    void editModeChanged(bool enabled);
    
    // Changements de données
    void roomsChanged();
    void furnitureChanged();
    void devicesChanged();
    void elementsChanged();
    
    // Navigation
    void cameraPositionChanged(const QVector3D& position);
    void cameraTargetChanged(const QVector3D& target);
    void viewModeChanged(int mode);
    
    // Interaction
    void elementSelected(const QString& elementId);
    void elementDeselected(const QString& elementId);
    void elementMoved(const QString& elementId, const QVector3D& newPosition);
    void elementClicked(const QString& elementId, const QVector3D& position);
    void elementDoubleClicked(const QString& elementId);
    
    // Mesures
    void measurementStarted();
    void measurementCompleted(double distance);
    void measurementCancelled();
    
    // Erreurs et événements
    void sceneError(const QString& error);
    void modelLoadError(const QString& modelPath, const QString& error);
    void renderingError(const QString& error);
    void performanceWarning(const QString& message);
    
private slots:
    void handleRenderUpdate();
    void handleCameraChanged();
    void handleElementTransformChanged();
    void checkPerformance();
    
private:
    // Moteur 3D
    Qt3DExtras::Qt3DWindow* m_3dWindow;
    Qt3DCore::QEntity* m_rootEntity;
    Qt3DRender::QCamera* m_camera;
    Qt3DCore::QEntity* m_sceneRoot;
    
    // État
    bool m_isInitialized;
    bool m_editMode;
    ViewMode m_currentViewMode;
    QString m_currentRoomId;
    
    // Données
    QMap<QString, Room> m_rooms;
    QMap<QString, Element3D> m_elements;
    QStringList m_selectedElements;
    
    // Rendu et performance
    QString m_renderQuality;
    bool m_shadowsEnabled;
    bool m_reflectionsEnabled;
    QTimer* m_performanceTimer;
    
    // Matériaux et textures
    QMap<QString, Qt3DRender::QMaterial*> m_materials;
    QMap<QString, QString> m_textures;
    
    // Outils
    bool m_measuring;
    QVector3D m_measureStart;
    bool m_debugMode;
    bool m_showGrid;
    bool m_showAxes;
    
    // Méthodes privées
    void setupScene();
    void setupCamera();
    void setupLighting();
    void setupMaterials();
    void createRoomGeometry(const QString& roomId);
    void createElementEntity(const QString& elementId);
    Qt3DCore::QEntity* loadModel(const QString& modelPath);
    Qt3DRender::QMaterial* createMaterialFromProperties(const QVariantMap& properties);
    QString getFurnitureModelPath(FurnitureType type) const;
    QString generateUniqueId() const;
    void updateElementTransform(const QString& elementId);
    void optimizePerformance();
    void validateElement(const Element3D& element) const;
    
    // Constantes
    static const QMap<FurnitureType, QString> FURNITURE_MODELS;
    static const QMap<QString, QVariantMap> DEFAULT_MATERIALS;
    static const QString MODELS_PATH;
};

#endif // ROOMDESIGNERENGINE_H