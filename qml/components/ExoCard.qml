import QtQuick
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  ExoCard — Carte avec ombre Fluent et animation
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root

    property bool hoverable: false
    property bool elevated: true

    color: Theme.bgSecondary
    radius: Theme.radiusLarge
    border.width: 1
    border.color: {
        if (hoverable && cardMouse.containsMouse) return Theme.borderHover
        return Theme.border
    }

    Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }

    // Ombre simulée (rectangle décalé derrière)
    Rectangle {
        visible: root.elevated
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.leftMargin: 1
        anchors.rightMargin: -1
        anchors.bottomMargin: -2
        z: -1
        radius: root.radius
        color: "#000000"
        opacity: 0.15
    }

    // Animation d'apparition
    opacity: 0
    Component.onCompleted: appearAnim.start()
    NumberAnimation {
        id: appearAnim
        target: root
        property: "opacity"
        from: 0; to: 1
        duration: Theme.animSlow
        easing.type: Easing.OutCubic
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: root.hoverable
        propagateComposedEvents: true
        onPressed: function(mouse) { mouse.accepted = false }
    }
}
