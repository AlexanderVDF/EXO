import QtQuick 2.15
import QtGraphicalEffects 1.15

// Visualiseur vocal animé pour feedback pendant l'écoute
Item {
    id: root
    
    // Propriétés de configuration
    property real audioLevel: 0.5
    property color primaryColor: "#2196F3"
    property color secondaryColor: "#64B5F6"
    property bool isActive: true
    property int barCount: 12
    
    // Animation et performance
    property int animationDuration: 150
    property bool smoothAnimation: true
    
    // Conteneur des barres audio
    Row {
        id: barsContainer
        anchors.centerIn: parent
        spacing: root.width / (barCount * 2)
        
        Repeater {
            model: barCount
            
            Rectangle {
                id: audioBar
                
                // Taille et position des barres
                width: (root.width - barsContainer.spacing * (barCount - 1)) / barCount
                height: calculateBarHeight(index)
                anchors.verticalCenter: parent.verticalCenter
                
                // Style des barres
                radius: width / 2
                color: calculateBarColor(index)
                
                // Fonction pour calculer la hauteur de chaque barre
                function calculateBarHeight(barIndex) {
                    if (!isActive) return root.height * 0.1
                    
                    // Créer un pattern de vagues basé sur l'index et le niveau audio
                    var baseHeight = root.height * 0.2
                    var maxHeight = root.height * 0.9
                    
                    // Onde sinusoïdale pour effet naturel
                    var waveOffset = (barIndex / barCount) * Math.PI * 2
                    var timeOffset = Date.now() * 0.003 // Vitesse d'animation
                    var wave = Math.sin(waveOffset + timeOffset) * 0.5 + 0.5
                    
                    // Combiner avec le niveau audio
                    var heightFactor = (wave * 0.7) + (audioLevel * 0.3)
                    
                    return baseHeight + (maxHeight - baseHeight) * heightFactor
                }
                
                // Fonction pour calculer la couleur de chaque barre
                function calculateBarColor(barIndex) {
                    var intensity = height / (root.height * 0.9)
                    
                    // Gradient de couleur basé sur l'intensité
                    if (intensity > 0.8) {
                        return "#4CAF50" // Vert pour les pics
                    } else if (intensity > 0.5) {
                        return primaryColor // Bleu principal
                    } else {
                        return Qt.darker(secondaryColor, 1.5) // Bleu sombre
                    }
                }
                
                // Animation fluide de la hauteur
                Behavior on height {
                    enabled: smoothAnimation
                    NumberAnimation { 
                        duration: animationDuration
                        easing.type: Easing.OutCubic 
                    }
                }
                
                // Animation de couleur
                Behavior on color {
                    ColorAnimation { 
                        duration: animationDuration * 2 
                    }
                }
                
                // Effet de brillance sur les barres actives
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#ffffff"; opacity: 0.3 }
                        GradientStop { position: 1.0; color: "#ffffff"; opacity: 0.0 }
                    }
                    visible: parent.height > root.height * 0.4
                }
            }
        }
    }
    
    // Cercles d'onde de fond
    Repeater {
        model: 3
        
        Rectangle {
            id: waveCircle
            anchors.centerIn: parent
            width: root.width * (0.3 + index * 0.3)
            height: width
            radius: width / 2
            color: "transparent"
            border.color: Qt.rgba(primaryColor.r, primaryColor.g, primaryColor.b, 0.3 - index * 0.1)
            border.width: 2
            
            // Animation de pulsation
            SequentialAnimation on scale {
                running: isActive
                loops: Animation.Infinite
                
                NumberAnimation { 
                    to: 1.2 
                    duration: 2000 + index * 500
                    easing.type: Easing.InOutQuad 
                }
                NumberAnimation { 
                    to: 1.0 
                    duration: 2000 + index * 500
                    easing.type: Easing.InOutQuad 
                }
            }
            
            // Animation d'opacité
            SequentialAnimation on opacity {
                running: isActive
                loops: Animation.Infinite
                
                NumberAnimation { 
                    to: 0.8 
                    duration: 1500 + index * 300 
                }
                NumberAnimation { 
                    to: 0.2 
                    duration: 1500 + index * 300 
                }
            }
        }
    }
    
    // Effet de particules pour plus d'immersion
    Repeater {
        model: 8
        
        Rectangle {
            id: particle
            width: 4
            height: 4
            radius: 2
            color: secondaryColor
            opacity: 0.6
            
            // Position aléatoire autour du centre
            x: root.width/2 + Math.random() * root.width * 0.6 - root.width * 0.3
            y: root.height/2 + Math.random() * root.height * 0.6 - root.height * 0.3
            
            // Animation de flottement
            SequentialAnimation on y {
                running: isActive
                loops: Animation.Infinite
                
                NumberAnimation {
                    to: particle.y - 20 - Math.random() * 30
                    duration: 2000 + Math.random() * 1000
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: particle.y + 20 + Math.random() * 30
                    duration: 2000 + Math.random() * 1000
                    easing.type: Easing.InOutSine
                }
            }
            
            // Animation d'opacité subtile
            SequentialAnimation on opacity {
                running: isActive
                loops: Animation.Infinite
                
                NumberAnimation { 
                    to: 0.2 
                    duration: 1000 + Math.random() * 1000 
                }
                NumberAnimation { 
                    to: 0.8 
                    duration: 1000 + Math.random() * 1000 
                }
            }
        }
    }
    
    // Timer pour mise à jour continue des barres
    Timer {
        id: updateTimer
        interval: animationDuration
        running: isActive
        repeat: true
        
        onTriggered: {
            // Simulation de variation du niveau audio
            // En production, ceci serait remplacé par de vraies données audio
            audioLevel = Math.random() * 0.8 + 0.2
            
            // Forcer la mise à jour de toutes les barres
            for (var i = 0; i < barsContainer.children.length; i++) {
                var repeater = barsContainer.children[0] // Le Repeater
                if (repeater && repeater.itemAt) {
                    for (var j = 0; j < repeater.count; j++) {
                        var bar = repeater.itemAt(j)
                        if (bar) {
                            bar.height = bar.calculateBarHeight(j)
                            bar.color = bar.calculateBarColor(j)
                        }
                    }
                }
            }
        }
    }
    
    // Effet de brillance global
    RadialGradient {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(primaryColor.r, primaryColor.g, primaryColor.b, 0.1) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        visible: isActive
        
        // Animation de pulsation de la brillance
        SequentialAnimation on opacity {
            running: isActive
            loops: Animation.Infinite
            
            NumberAnimation { to: 0.3; duration: 1500 }
            NumberAnimation { to: 0.1; duration: 1500 }
        }
    }
    
    // Gestion des changements d'état
    onIsActiveChanged: {
        if (isActive) {
            // Animation d'apparition
            scaleIn.start()
            updateTimer.start()
        } else {
            // Animation de disparition
            scaleOut.start()
            updateTimer.stop()
        }
    }
    
    // Animation d'entrée
    NumberAnimation {
        id: scaleIn
        target: root
        property: "scale"
        from: 0.0
        to: 1.0
        duration: 300
        easing.type: Easing.OutBack
    }
    
    // Animation de sortie
    NumberAnimation {
        id: scaleOut
        target: root
        property: "scale"
        to: 0.0
        duration: 200
        easing.type: Easing.InCubic
    }
    
    // Initialisation
    Component.onCompleted: {
        if (isActive) {
            scale = 0
            scaleIn.start()
        }
    }
    
    // Interface pour mise à jour externe du niveau audio
    function updateAudioLevel(level) {
        audioLevel = Math.max(0, Math.min(1, level))
    }
    
    // Interface pour changer les couleurs
    function setColors(primary, secondary) {
        primaryColor = primary
        secondaryColor = secondary
    }
}