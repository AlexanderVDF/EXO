import QtQuick
import "../theme"

// ═══════════════════════════════════════════════════════
//  ExoSlider — Slider moderne avec glow
// ═══════════════════════════════════════════════════════

Item {
    id: root

    property real value: 0.0       // 0.0–1.0
    property real minimumValue: 0.0
    property real maximumValue: 1.0
    property bool enabled: true

    signal moved(real value)

    implicitWidth: 200
    implicitHeight: 24
    opacity: root.enabled ? 1.0 : 0.4

    readonly property real ratio: (root.value - root.minimumValue) / (root.maximumValue - root.minimumValue)

    // Track
    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: Theme.bgInput

        // Filled portion
        Rectangle {
            width: root.ratio * parent.width
            height: parent.height
            radius: 2
            color: Theme.accent
        }
    }

    // Thumb
    Rectangle {
        id: thumbKnob
        width: 16
        height: 16
        radius: 8
        x: root.ratio * (root.width - width)
        anchors.verticalCenter: parent.verticalCenter
        color: thumbMouse.containsMouse || thumbMouse.pressed ? "#FFFFFF" : Theme.accentLight
        border.width: 2
        border.color: Theme.accent

        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        // Glow on hover
        Rectangle {
            visible: thumbMouse.containsMouse
            anchors.centerIn: parent
            width: 24
            height: 24
            radius: 12
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
            opacity: 0.3
        }
    }

    MouseArea {
        id: thumbMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onPositionChanged: function(mouse) {
            if (pressed) updateValue(mouse.x)
        }
        onPressed: function(mouse) { updateValue(mouse.x) }

        function updateValue(mx) {
            var ratio = Math.max(0, Math.min(1, mx / root.width))
            root.value = root.minimumValue + ratio * (root.maximumValue - root.minimumValue)
            root.moved(root.value)
        }
    }
}
