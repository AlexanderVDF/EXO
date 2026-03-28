import QtQuick
import "../theme"

// ═══════════════════════════════════════════════════════
//  ExoSwitch — Toggle switch style Fluent
// ═══════════════════════════════════════════════════════

Item {
    id: root

    property bool checked: false
    property bool enabled: true

    signal toggled(bool value)

    implicitWidth: 40
    implicitHeight: 20
    opacity: root.enabled ? 1.0 : 0.4

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.bgInput
        border.width: 1
        border.color: root.checked ? Theme.accent : Theme.borderLight

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Rectangle {
            id: thumb
            width: 14
            height: 14
            radius: 7
            y: (parent.height - height) / 2
            x: root.checked ? parent.width - width - 3 : 3
            color: "#FFFFFF"

            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutCubic } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled
        onClicked: {
            root.checked = !root.checked
            root.toggled(root.checked)
        }
    }
}
