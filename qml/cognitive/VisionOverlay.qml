import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  VisionOverlay — Superposition caméra sur FloorPlan
//  Affiche les bounding boxes et états de détection
// ═══════════════════════════════════════════════════════

Item {
    id: root

    property var engine: null
    property var overlayData: ({})

    // Connexion signal overlayUpdate du router
    Connections {
        target: engine ? engine : null
        function onVisionEventDetected(event) {
            // Rafraîchir l'overlay
        }
    }

    // ── Indicateurs caméra par pièce ──
    Repeater {
        model: root.engine ? (root.engine.visionState.context ?
               root.engine.visionState.context.cameras || [] : []) : []

        delegate: Rectangle {
            x: (modelData.details && modelData.details.overlayX) ?
               modelData.details.overlayX * root.width : 0
            y: (modelData.details && modelData.details.overlayY) ?
               modelData.details.overlayY * root.height : 0
            width: 32; height: 32
            radius: 16
            color: modelData.anomalyCount > 0 ? Qt.rgba(1, 0, 0, 0.6)
                 : modelData.personCount > 0 ? Qt.rgba(0, 0.7, 1, 0.6)
                 : Qt.rgba(0.5, 0.5, 0.5, 0.3)
            border.color: modelData.state === 2 ? Theme.success : Theme.textSecondary
            border.width: 2

            Label {
                anchors.centerIn: parent
                text: modelData.personCount > 0 ? "👤" + modelData.personCount : "📹"
                font.pixelSize: modelData.personCount > 0 ? 10 : 14
                color: "white"
            }

            ToolTip.visible: hoverArea.containsMouse
            ToolTip.text: (modelData.cameraId || "") + "\n" +
                          (modelData.roomId || "—") + "\n" +
                          "Détections: " + (modelData.detectionCount || 0)

            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
            }
        }
    }

    // ── Indicateur anomalies globales ──
    Rectangle {
        visible: overlayData.fire === true || overlayData.smoke === true
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        width: warningLabel.width + 16
        height: 24
        radius: 12
        color: overlayData.fire ? "#FF0040" : "#FF8C00"

        Label {
            id: warningLabel
            anchors.centerIn: parent
            text: overlayData.fire ? "🔥 FEU DÉTECTÉ" : "💨 FUMÉE"
            font.pixelSize: 10
            font.bold: true
            color: "white"
        }

        SequentialAnimation on opacity {
            running: parent.visible
            loops: Animation.Infinite
            NumberAnimation { to: 0.4; duration: 400 }
            NumberAnimation { to: 1.0; duration: 400 }
        }
    }
}
