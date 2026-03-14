import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15

// Composant CloseButton - Bouton de fermeture standardisé et thématisé
Button {
    id: closeButton
    
    // Propriétés configurables
    property int buttonSize: 32
    property color backgroundColor: Material.theme === Material.Dark ? "#2C2C2C" : "#F0F0F0"
    property color hoverColor: "#F44336"
    property color iconColor: Material.theme === Material.Dark ? "#E0E0E0" : "#424242"
    property color hoverIconColor: "#FFFFFF"
    property bool useThemeColors: false
    
    // Adaptation automatique au thème si activée
    property color dynamicBackgroundColor: useThemeColors ? 
        (Material.theme === Material.Dark ? Material.background : Material.surface) : backgroundColor
    
    // Signal personnalisé
    signal closeRequested()
    
    width: buttonSize
    height: buttonSize
    
    // Style du bouton
    background: Rectangle {
        radius: buttonSize / 2
        color: closeButton.hovered ? hoverColor : dynamicBackgroundColor
        border.color: closeButton.hovered ? Qt.darker(hoverColor, 1.2) : Qt.darker(dynamicBackgroundColor, 1.1)
        border.width: 1
        
        // Animation de couleur
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
        
        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }
    }
    
    // Icône croix
    contentItem: Text {
        text: "✕"
        font.pixelSize: buttonSize * 0.4
        font.bold: true
        color: closeButton.hovered ? hoverIconColor : iconColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        
        // Animation de couleur
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }
    
    // Effets visuels
    scale: pressed ? 0.95 : 1.0
    
    Behavior on scale {
        NumberAnimation { duration: 100 }
    }
    
    // Curseur de la souris
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: closeButton.closeRequested()
    }
    
    // Tooltip
    ToolTip {
        visible: closeButton.hovered
        text: "Fermer"
        delay: 1000
    }
}