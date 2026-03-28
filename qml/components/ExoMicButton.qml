import QtQuick
import "../theme"

// ═══════════════════════════════════════════════════════
//  ExoMicButton — Bouton microphone principal EXO
//  Animation pulsante en écoute, halo coloré par état
// ═══════════════════════════════════════════════════════

Item {
    id: root

    property string pipelineState: "Idle"   // Idle, Listening, Transcribing, Thinking, Speaking, Error
    property bool enabled: true

    signal clicked()

    implicitWidth: 64
    implicitHeight: 64

    readonly property color stateCol: Theme.stateColor(root.pipelineState)
    readonly property bool isActive: root.pipelineState !== "Idle"

    // Halo pulsant (derrière le bouton)
    Rectangle {
        id: halo
        anchors.centerIn: parent
        width: parent.width + 16; height: width; radius: width / 2
        color: "transparent"
        border.width: 3
        border.color: root.stateCol
        opacity: 0

        Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }

        SequentialAnimation on opacity {
            running: root.pipelineState === "Listening"
            loops: Animation.Infinite
            NumberAnimation { from: 0; to: 0.5; duration: 700; easing.type: Easing.OutSine }
            NumberAnimation { from: 0.5; to: 0; duration: 700; easing.type: Easing.InSine }
        }

        SequentialAnimation on scale {
            running: root.pipelineState === "Listening"
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 1.15; duration: 700; easing.type: Easing.OutSine }
            NumberAnimation { from: 1.15; to: 1.0; duration: 700; easing.type: Easing.InSine }
        }
    }

    // Bouton principal
    Rectangle {
        id: btn
        anchors.centerIn: parent
        width: parent.width; height: width; radius: width / 2

        color: {
            if (!root.enabled) return Theme.bgInput
            if (root.pipelineState === "Error") return Theme.errorDim
            if (root.isActive) return root.stateCol
            return micMouse.pressed ? Theme.accentDark
                 : micMouse.containsMouse ? Theme.accentHover : Theme.accent
        }

        border.width: 2
        border.color: {
            if (root.isActive) return root.stateCol
            return micMouse.containsMouse ? Theme.accentLight : Theme.accent
        }

        Behavior on color { ColorAnimation { duration: Theme.animNormal } }
        Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }

        scale: micMouse.pressed ? 0.93 : 1.0
        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }

        // Icône micro (unicode)
        Text {
            anchors.centerIn: parent
            text: root.pipelineState === "Error" ? "⚠" : "🎤"
            font.pixelSize: parent.width * 0.38
            opacity: root.enabled ? 1.0 : 0.4
        }
    }

    // Ring de progression (Transcribing / Thinking)
    Canvas {
        id: ring
        anchors.centerIn: parent
        width: parent.width + 8; height: width
        visible: root.pipelineState === "Transcribing" || root.pipelineState === "Thinking"

        property real sweepAngle: 0
        SequentialAnimation on sweepAngle {
            running: ring.visible
            loops: Animation.Infinite
            NumberAnimation { from: 0; to: 360; duration: 1500; easing.type: Easing.Linear }
        }

        onSweepAngleChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = Qt.rgba(root.stateCol.r, root.stateCol.g, root.stateCol.b, 0.6)
            ctx.lineWidth = 2
            ctx.lineCap = "round"
            var cx = width / 2, cy = height / 2, r = cx - 4
            var startRad = (sweepAngle - 90) * Math.PI / 180
            var endRad = startRad + Math.PI * 0.6
            ctx.beginPath()
            ctx.arc(cx, cy, r, startRad, endRad)
            ctx.stroke()
        }
    }

    MouseArea {
        id: micMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
