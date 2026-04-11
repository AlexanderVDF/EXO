import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  VisionCameraPanel — État et contrôle des caméras
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var engine: null

    property int activeCameras: engine ? engine.activeCameras : 0
    property var state:         engine ? engine.visionState : ({})

    readonly property var cameraStateNames: [
        "Déconnectée", "Connexion…", "Streaming", "Pause", "Erreur", "Obstruée"
    ]
    readonly property var cameraStateColors: [
        Theme.textSecondary, Theme.warning, Theme.success,
        Theme.info, Theme.error, "#FF8C00"
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "📹 Caméras (" + root.activeCameras + " actives)"
                font.pixelSize: 13
                font.bold: true
                color: Theme.textPrimary
            }
            Item { Layout.fillWidth: true }
        }

        // ── Liste des caméras ──
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.state.context ? root.state.context.cameras || [] : []

            delegate: Rectangle {
                width: ListView.view.width
                height: 56
                radius: 4
                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.4)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: root.cameraStateColors[modelData.state || 0]
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Label {
                            text: modelData.cameraId || "—"
                            font.pixelSize: 12
                            font.bold: true
                            color: Theme.textPrimary
                        }
                        Label {
                            text: (modelData.roomId || "Pas de pièce") + " — " +
                                  root.cameraStateNames[modelData.state || 0]
                            font.pixelSize: 10
                            color: Theme.textSecondary
                        }
                    }

                    Label {
                        text: "👤 " + (modelData.personCount || 0)
                        font.pixelSize: 11
                        color: Theme.textPrimary
                    }

                    Label {
                        text: "🎯 " + (modelData.detectionCount || 0)
                        font.pixelSize: 11
                        color: Theme.textPrimary
                    }
                }
            }
        }
    }
}
