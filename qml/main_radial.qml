import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15
import "components"

ApplicationWindow {
    id: mainWindow
    
    visible: true
    width: 1024
    height: 600
    title: "EXO - Assistant Personnel"
    
    // Configuration Material Design dynamique
    Material.theme: Material.Dark
    Material.accent: accentColor
    Material.primary: backgroundColor
    
    // Propriétés d'état
    property bool menuExpanded: false
    property string currentSection: ""
    property var assistant: assistantManager
    
    // Couleurs du thème (dynamiques depuis ConfigManager)
    property var currentThemeColors: assistant ? assistant.configManager.getThemeColors(assistant.configManager.currentTheme) : ({
        "primary": "#00BCD4",
        "secondary": "#0097A7",
        "accent": "#FF9800",
        "background": "#0D4F5C",
        "surface": "#1E1E1E",
        "text": "#FFFFFF"
    })
    
    readonly property color backgroundColor: currentThemeColors.background || "#0D4F5C"
    readonly property color accentColor: currentThemeColors.primary || "#00BCD4"
    readonly property color secondaryColor: currentThemeColors.secondary || "#0097A7"
    readonly property color surfaceColor: currentThemeColors.surface || "#1E1E1E"
    readonly property color textColor: currentThemeColors.text || "#FFFFFF"
    readonly property color accentColorSecondary: currentThemeColors.accent || "#FF9800"
    
    // Connexion aux changements de thème
    Connections {
        target: assistant ? assistant.configManager : null
        function onThemeChanged() {
            console.log("🎨 Thème de la fenêtre principale mis à jour");
            // Force la mise à jour des couleurs
            currentThemeColors = assistant.configManager.getThemeColors(assistant.configManager.currentTheme);
        }
    }
    
    // Background avec dégradé dynamique basé sur le thème
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.darker(backgroundColor, 1.3) }
            GradientStop { position: 0.5; color: backgroundColor }
            GradientStop { position: 1.0; color: Qt.lighter(backgroundColor, 1.2) }
        }
    }
    
    // Particules d'ambiance en arrière-plan
    Repeater {
        model: 15
        Rectangle {
            id: particle
            width: Math.random() * 4 + 2
            height: width
            radius: width / 2
            color: Qt.rgba(1, 1, 1, Math.random() * 0.3 + 0.1)
            x: Math.random() * mainWindow.width
            y: Math.random() * mainWindow.height
            
            SequentialAnimation on y {
                loops: Animation.Infinite
                PropertyAnimation {
                    from: particle.y
                    to: particle.y - 100
                    duration: 3000 + Math.random() * 2000
                    easing.type: Easing.InOutSine
                }
                PropertyAnimation {
                    from: particle.y - 100
                    to: particle.y
                    duration: 3000 + Math.random() * 2000
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
    
    // Logo EXO central
    Item {
        id: centerLogo
        anchors.centerIn: parent
        width: 120
        height: 120
        
        // Cercle extérieur animé (aura)
        Rectangle {
            id: outerRing
            anchors.centerIn: parent
            width: parent.width + 40
            height: parent.height + 40
            radius: width / 2
            color: "transparent"
            border.color: accentColor
            border.width: 2
            opacity: 0.6
            
            RotationAnimation on rotation {
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 8000
                easing.type: Easing.Linear
            }
        }
        
        // Cercle principal EXO
        Rectangle {
            id: mainCircle
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: width / 2
            
            gradient: Gradient {
                GradientStop { position: 0.0; color: accentColor }
                GradientStop { position: 1.0; color: secondaryColor }
            }
            
            border.color: Qt.lighter(accentColor, 1.3)
            border.width: 3
            
            // Texte EXO
            Text {
                anchors.centerIn: parent
                text: "EXO"
                font.family: "Arial Black"
                font.pixelSize: 32
                font.bold: true
                color: "white"
                style: Text.Outline
                styleColor: "black"
            }
            
            // Animation de pulsation
            SequentialAnimation on scale {
                loops: Animation.Infinite
                PropertyAnimation {
                    from: 1.0
                    to: 1.05
                    duration: 2000
                    easing.type: Easing.InOutQuad
                }
                PropertyAnimation {
                    from: 1.05
                    to: 1.0
                    duration: 2000
                    easing.type: Easing.InOutQuad
                }
            }
            
            // Zone cliquable
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    menuExpanded = !menuExpanded
                    if (menuExpanded) {
                        expandMenu.start()
                    } else {
                        collapseMenu.start()
                    }
                }
            }
            
            // Effet de survol
            states: State {
                name: "hovered"
                PropertyChanges { target: mainCircle; scale: 1.1 }
            }
            
            transitions: Transition {
                PropertyAnimation { 
                    properties: "scale"
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
    
    // Boutons du menu radial
    Item {
        id: radialMenu
        anchors.centerIn: parent
        width: 400
        height: 400
        
        // Configuration des sections du menu (couleurs dynamiques)
        property var menuItems: [
            {name: "Configuration", icon: "⚙️", angle: 0, color: accentColorSecondary},
            {name: "Médias", icon: "🎵", angle: 72, color: Qt.lighter(accentColor, 1.2)},
            {name: "Maison", icon: "🏠", angle: 144, color: Qt.darker(accentColor, 1.1)},
            {name: "Agenda", icon: "📅", angle: 216, color: secondaryColor},
            {name: "Chat", icon: "💬", angle: 288, color: Qt.lighter(secondaryColor, 1.3)}
        ]
        
        Repeater {
            model: parent.menuItems
            
            Item {
                id: menuButton
                
                property real targetX: parent.width/2 + 150 * Math.cos((modelData.angle - 90) * Math.PI / 180) - width/2
                property real targetY: parent.height/2 + 150 * Math.sin((modelData.angle - 90) * Math.PI / 180) - height/2
                property real centerX: parent.width/2 - width/2
                property real centerY: parent.height/2 - height/2
                
                x: menuExpanded ? targetX : centerX
                y: menuExpanded ? targetY : centerY
                
                width: 80
                height: 80
                opacity: menuExpanded ? 1 : 0
                scale: menuExpanded ? 1 : 0.1
                
                Behavior on x { 
                    SequentialAnimation {
                        PauseAnimation { duration: index * 60 }
                        PropertyAnimation { 
                            duration: 500
                            easing.type: Easing.OutBack
                        }
                    }
                }
                Behavior on y { 
                    SequentialAnimation {
                        PauseAnimation { duration: index * 60 }
                        PropertyAnimation { 
                            duration: 500
                            easing.type: Easing.OutBack
                        }
                    }
                }
                Behavior on opacity { 
                    SequentialAnimation {
                        PauseAnimation { duration: index * 60 }
                        PropertyAnimation { duration: 400 }
                    }
                }
                Behavior on scale { 
                    SequentialAnimation {
                        PauseAnimation { duration: index * 60 }
                        PropertyAnimation { 
                            duration: 500
                            easing.type: Easing.OutBack
                        }
                    }
                }
                
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: modelData.color
                    border.color: Qt.lighter(modelData.color, 1.2)
                    border.width: 2
                    
                    // Icône de la section
                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        font.pixelSize: 28
                        anchors.verticalCenterOffset: -5
                    }
                    
                    // Nom de la section
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 8
                        text: modelData.name
                        color: "white"
                        font.pixelSize: 12
                        font.bold: true
                        opacity: menuExpanded ? 1 : 0
                        
                        Behavior on opacity { PropertyAnimation { duration: 600 } }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: openSection(modelData.name)
                        
                        onPressed: parent.scale = 0.9
                        onReleased: parent.scale = 1.0
                        onCanceled: parent.scale = 1.0
                    }
                    
                    Behavior on scale { PropertyAnimation { duration: 100 } }
                }
            }
        }
    }
    
    // Section d'affichage plein écran
    Rectangle {
        id: sectionDisplay
        anchors.fill: parent
        color: backgroundColor
        opacity: 0
        scale: 0.1
        visible: opacity > 0
        
        // En-tête de section
        Rectangle {
            id: sectionHeader
            anchors.top: parent.top
            width: parent.width
            height: 80
            color: Qt.rgba(0, 0, 0, 0.3)
            
            Text {
                id: sectionTitle
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.verticalCenter: parent.verticalCenter
                text: currentSection
                color: "white"
                font.pixelSize: 28
                font.bold: true
            }
            
            // Bouton retour
            CloseButton {
                anchors.right: parent.right
                anchors.rightMargin: 30
                anchors.verticalCenter: parent.verticalCenter
                buttonSize: 50
                backgroundColor: accentColor
                hoverColor: Qt.lighter(accentColor, 1.2)
                onCloseRequested: closeSection()
            }
        }
        
        // Contenu de la section
        Rectangle {
            anchors.top: sectionHeader.bottom
            anchors.bottom: parent.bottom
            width: parent.width
            color: "transparent"
            
            Loader {
                id: sectionLoader
                anchors.fill: parent
                
                Component.onCompleted: updateSectionContent()
            }
        }
    }
    
    // Animations
    SequentialAnimation {
        id: expandMenu
        PropertyAnimation {
            target: centerLogo
            property: "scale"
            to: 0.8
            duration: 200
        }
    }
    
    SequentialAnimation {
        id: collapseMenu
        PropertyAnimation {
            target: centerLogo
            property: "scale"
            to: 1.0
            duration: 200
        }
    }
    
    // Fonctions
    function openSection(sectionName) {
        currentSection = sectionName
        menuExpanded = false
        
        // Animation de fermeture du menu radial
        collapseMenu.start()
        
        // Charger le contenu de la section
        updateSectionContent()
        
        // Animation d'ouverture de la section
        sectionDisplay.opacity = 1
        sectionDisplay.scale = 1
    }
    
    function closeSection() {
        sectionDisplay.opacity = 0
        sectionDisplay.scale = 0.1
        currentSection = ""
        sectionLoader.source = ""
    }
    
    function updateSectionContent() {
        switch(currentSection) {
            case "Configuration":
                sectionLoader.source = "components/ConfigurationSection.qml"
                break
            case "Médias":
                sectionLoader.source = "components/MediasSection.qml"
                break
            case "Maison":
                sectionLoader.source = "components/MaisonSection.qml"
                break
            case "Agenda":
                sectionLoader.source = "components/AgendaSection.qml"
                break
            case "Chat":
                sectionLoader.source = "components/ChatSection.qml"
                break
            default:
                sectionLoader.source = ""
        }
        
        // Passer la référence assistant aux composants une fois qu'ils sont chargés
        sectionLoader.onLoaded.connect(function() {
            if (sectionLoader.item && assistant) {
                sectionLoader.item.assistant = assistant
                console.log("Assistant assigné à", currentSection)
            }
            // Passer la référence du ThemeEditor à ConfigurationSection
            if (sectionLoader.item && currentSection === "Configuration") {
                sectionLoader.item.mainThemeEditor = themeEditor
            }
        })
    }
    
    // Gestion des transitions de section
    Behavior on opacity { PropertyAnimation { duration: 300 } }
    
    PropertyAnimation {
        id: sectionOpenAnim
        target: sectionDisplay
        properties: "opacity,scale"
        to: 1
        duration: 400
        easing.type: Easing.OutQuad
    }
    
    PropertyAnimation {
        id: sectionCloseAnim
        target: sectionDisplay
        properties: "opacity,scale"
        to: 0
        duration: 300
        easing.type: Easing.InQuad
    }
    
    // Connexion pour les changements de thème
    Connections {
        target: assistantManager ? assistantManager.configManager : null
        function onThemeChanged(themeName, colors) {
            mainWindow.currentThemeColors = colors
            // Mettre à jour Material Design
            Material.accent = colors.primary
            Material.primary = colors.secondary
        }
    }
    
    // Éditeur de thème plein écran
    ThemeEditor {
        id: themeEditor
        anchors.fill: parent
        configManager: assistantManager ? assistantManager.configManager : null
        
        onThemeCreated: {
            // Appliquer le nouveau thème immédiatement
            var colors = configManager.getThemeColors(themeName)
            mainWindow.currentThemeColors = colors
            Material.accent = colors.primary
            Material.primary = colors.secondary
            
            // Notifier la section configuration si elle est ouverte
            if (sectionLoader.item && sectionLoader.item.refreshThemes) {
                sectionLoader.item.refreshThemes(themeName)
            }
        }
        
        onThemeUpdated: {
            // Appliquer les modifications du thème
            var colors = configManager.getThemeColors(themeName)
            mainWindow.currentThemeColors = colors
            Material.accent = colors.primary
            Material.primary = colors.secondary
        }
    }

    // Initialisation du thème au démarrage
    Component.onCompleted: {
        if (assistantManager && assistantManager.configManager) {
            var themeName = assistantManager.configManager.getCurrentTheme()
            var colors = assistantManager.configManager.getThemeColors(themeName)
            mainWindow.currentThemeColors = colors
            Material.accent = colors.primary
            Material.primary = colors.secondary
        }
    }
}