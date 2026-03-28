import QtQuick
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  ExoServiceStatus — Indicateur de santé d'un service EXO
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root

    property string name: ""
    property string status: "down"     // healthy, degraded, down
    property int port: 0

    implicitWidth: row.implicitWidth + Theme.spacing16
    implicitHeight: 28
    radius: Theme.radiusSmall
    color: serviceMouse.containsMouse ? Theme.bgHover : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spacing6

        // Dot santé
        Rectangle {
            width: 8; height: 8; radius: 4
            color: Theme.healthColor(root.status)

            Behavior on color { ColorAnimation { duration: Theme.animNormal } }

            // Pulse si dégradé
            SequentialAnimation on opacity {
                running: root.status === "degraded"
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.4; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
            }
        }

        // Nom du service
        Text {
            text: root.name
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTiny
            font.weight: Font.Medium
            color: Theme.textPrimary
        }

        // Port
        Text {
            visible: root.port > 0
            text: ":" + root.port
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontTiny
            color: Theme.textMuted
        }
    }

    MouseArea {
        id: serviceMouse
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        onPressed: function(mouse) { mouse.accepted = false }
    }
}
