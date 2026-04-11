import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  SpatialPredictionPanel — Prédictions spatiales
//  Affiche les prédictions issues du moteur cognitif
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var engine: null
    property var predictions: engine ? engine.getPredictions() : []

    readonly property var severityLabels: ["Info", "Faible", "Moyen", "Élevé", "Critique"]
    readonly property var severityColors: [Theme.info, Theme.success, Theme.warning, "#CE9178", Theme.error]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // ── En-tête ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Label {
                text: "🔮 Prédictions"
                font.pixelSize: 14
                font.bold: true
                color: Theme.textPrimary
            }

            Item { Layout.fillWidth: true }

            Label {
                text: root.predictions.length + " prédiction(s)"
                font.pixelSize: 11
                color: Theme.textSecondary
            }
        }

        // ── Liste des prédictions ──
        ListView {
            id: predList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.predictions

            delegate: Rectangle {
                width: predList.width
                height: predCol.implicitHeight + 16
                radius: 4
                color: Theme.cardBackground

                ColumnLayout {
                    id: predCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    spacing: 4

                    // Ligne titre
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            width: sevTag.implicitWidth + 10
                            height: 18
                            radius: 3
                            color: Qt.rgba(
                                Qt.color(root.severityColors[modelData.severity] || Theme.info).r,
                                Qt.color(root.severityColors[modelData.severity] || Theme.info).g,
                                Qt.color(root.severityColors[modelData.severity] || Theme.info).b,
                                0.2
                            )

                            Label {
                                id: sevTag
                                anchors.centerIn: parent
                                text: root.severityLabels[modelData.severity] || "Info"
                                font.pixelSize: 9
                                font.bold: true
                                color: root.severityColors[modelData.severity] || Theme.info
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: modelData.description || ""
                            font.pixelSize: 11
                            color: Theme.textPrimary
                            wrapMode: Text.WordWrap
                        }
                    }

                    // Métriques
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Label {
                            text: "📍 " + (modelData.roomId || "Global")
                            font.pixelSize: 10
                            color: Theme.textSecondary
                        }

                        // Barre de confiance
                        RowLayout {
                            spacing: 4

                            Label {
                                text: "Confiance"
                                font.pixelSize: 10
                                color: Theme.textSecondary
                            }

                            Rectangle {
                                width: 60
                                height: 5
                                radius: 2
                                color: Qt.rgba(1, 1, 1, 0.05)

                                Rectangle {
                                    width: parent.width * (modelData.confidence || 0)
                                    height: parent.height
                                    radius: 2
                                    color: (modelData.confidence || 0) >= 0.8 ? Theme.success :
                                           (modelData.confidence || 0) >= 0.5 ? Theme.warning : Theme.error
                                }
                            }

                            Label {
                                text: Math.round((modelData.confidence || 0) * 100) + "%"
                                font.pixelSize: 10
                                font.bold: true
                                color: Theme.textPrimary
                            }
                        }
                    }
                }
            }
        }

        // ── Vide ──
        Label {
            visible: root.predictions.length === 0
            text: "Aucune prédiction active"
            font.pixelSize: 11
            font.italic: true
            color: Theme.textSecondary
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
