import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15

// Bouton tactile optimisé pour Raspberry Pi
Button {
    id: control
    
    // Propriétés personnalisées pour l'optimisation tactile
    property string icon: ""
    property color primaryColor: "#2196F3"
    property color secondaryColor: "#1976D2"
    property bool touchOptimized: true
    property int touchMargin: 10
    property int animationDuration: 200
    
    // Taille minimale pour interaction tactile (44x44dp minimum recommandé)
    implicitWidth: Math.max(88, contentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(88, contentHeight + topPadding + bottomPadding)
    
    // Padding optimisé pour le tactile
    leftPadding: touchMargin
    rightPadding: touchMargin
    topPadding: touchMargin
    bottomPadding: touchMargin
    
    // Configuration Material Design
    Material.background: enabled ? primaryColor : "#424242"
    Material.foreground: "#ffffff"
    Material.elevation: pressed ? 8 : 4
    
    // Fond personnalisé avec effets
    background: Rectangle {
        anchors.fill: parent
        radius: 12
        color: control.enabled ? 
            (control.pressed ? secondaryColor : primaryColor) : 
            "#424242"
        
        // Effet de brillance
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#ffffff"; opacity: 0.2 }
                GradientStop { position: 1.0; color: "#ffffff"; opacity: 0.0 }
            }
        }
        
        // Animation de couleur fluide
        Behavior on color {
            ColorAnimation { 
                duration: animationDuration
                easing.type: Easing.OutCubic 
            }
        }
        
        // Effet de ripple tactile
        Rectangle {
            id: rippleEffect
            anchors.centerIn: parent
            width: 0
            height: 0
            radius: Math.min(width, height) / 2
            color: "#ffffff"
            opacity: 0
            
            SequentialAnimation {
                id: rippleAnimation
                
                ParallelAnimation {
                    NumberAnimation {
                        target: rippleEffect
                        property: "width"
                        to: control.width * 1.5
                        duration: animationDuration * 2
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: rippleEffect
                        property: "height"
                        to: control.height * 1.5
                        duration: animationDuration * 2
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: rippleEffect
                        property: "opacity"
                        to: 0.3
                        duration: animationDuration
                    }
                }
                
                NumberAnimation {
                    target: rippleEffect
                    property: "opacity"
                    to: 0
                    duration: animationDuration
                }
                
                ScriptAction {
                    script: {
                        rippleEffect.width = 0
                        rippleEffect.height = 0
                    }
                }
            }
        }
        
        // Ombre portée
        DropShadow {
            anchors.fill: parent
            source: parent
            radius: control.Material.elevation
            samples: radius * 2 + 1
            color: "#80000000"
            cached: true
        }
    }
    
    // Contenu du bouton
    contentItem: Row {
        spacing: 8
        
        // Icône (si fournie)
        Image {
            id: iconImage
            source: icon
            width: 24
            height: 24
            visible: icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            
            // Colorisation de l'icône
            ColorOverlay {
                anchors.fill: iconImage
                source: iconImage
                color: control.Material.foreground
                cached: true
            }
        }
        
        // Texte du bouton
        Label {
            text: control.text
            font: control.font
            color: control.Material.foreground
            anchors.verticalCenter: parent.verticalCenter
            
            // Taille de police optimisée pour tactile
            font.pixelSize: Math.max(16, control.font.pixelSize)
            font.weight: Font.Medium
        }
    }
    
    // Gestion des interactions tactiles
    onPressed: {
        // Animation de pression
        scaleAnimation.to = 0.95
        scaleAnimation.start()
        
        // Effet ripple
        if (touchOptimized) {
            rippleAnimation.start()
        }
        
        // Feedback haptique léger (si supporté)
        hapticFeedback()
    }
    
    onReleased: {
        // Animation de relâchement
        scaleAnimation.to = 1.0
        scaleAnimation.start()
    }
    
    onCanceled: {
        // Retour à l'état normal si annulé
        scaleAnimation.to = 1.0
        scaleAnimation.start()
    }
    
    // Animation d'échelle pour feedback visuel
    NumberAnimation {
        id: scaleAnimation
        target: control
        property: "scale"
        duration: animationDuration / 2
        easing.type: Easing.OutCubic
    }
    
    // États visuels pour différents modes
    states: [
        State {
            name: "success"
            when: primaryColor === "#4caf50"
            PropertyChanges { target: control; Material.background: "#4caf50" }
        },
        State {
            name: "warning"
            when: primaryColor === "#ff9800"
            PropertyChanges { target: control; Material.background: "#ff9800" }
        },
        State {
            name: "danger"
            when: primaryColor === "#f44336"
            PropertyChanges { target: control; Material.background: "#f44336" }
        }
    ]
    
    // Animations entre états
    transitions: [
        Transition {
            from: "*"
            to: "*"
            ColorAnimation {
                property: "Material.background"
                duration: animationDuration
                easing.type: Easing.OutCubic
            }
        }
    ]
    
    // Fonction de feedback haptique (à implémenter selon le hardware)
    function hapticFeedback() {
        // Ici on pourrait déclencher:
        // - Vibration via GPIO
        // - Son tactile
        // - Signal vers service système
        
        // Pour l'instant, un effet visuel léger
        if (touchOptimized) {
            brightFlash.start()
        }
    }
    
    // Flash visuel pour feedback
    Rectangle {
        anchors.fill: parent
        color: "#ffffff"
        opacity: 0
        radius: parent.background.radius
        
        NumberAnimation {
            id: brightFlash
            target: parent
            property: "opacity"
            from: 0
            to: 0.3
            duration: 50
            
            onFinished: fadeOut.start()
        }
        
        NumberAnimation {
            id: fadeOut
            target: parent
            property: "opacity"
            to: 0
            duration: 100
        }
    }
    
    // Accessibilité tactile améliorée
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.description: "Bouton tactile optimisé: " + text
    Accessible.onPressAction: control.clicked()
    
    // Gestion des gestes avancés
    PinchArea {
        anchors.fill: parent
        enabled: touchOptimized
        
        onPinchStarted: {
            // Désactiver temporairement le bouton pendant le pinch
            control.enabled = false
        }
        
        onPinchFinished: {
            // Réactiver après un délai
            Qt.callLater(function() {
                control.enabled = true
            })
        }
    }
}