import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  SpatialExplanationPanel — Explications des inférences
//  Affiche le raisonnement derrière chaque détection
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var engine: null
    property var inferences: engine ? engine.inferences : []
    property string selectedInferenceId: ""

    readonly property var severityLabels: ["Info", "Faible", "Moyen", "Élevé", "Critique"]
    readonly property var severityColors: [Theme.info, Theme.success, Theme.warning, "#CE9178", Theme.error]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // ── En-tête ──
        Label {
            text: "💡 Explications"
            font.pixelSize: 14
            font.bold: true
            color: Theme.textPrimary
        }

        Label {
            text: root.inferences.length + " inférence(s) active(s)"
            font.pixelSize: 11
            color: Theme.textSecondary
        }

        // ── Liste des inférences ──
        ListView {
            id: inferenceList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.inferences

            delegate: Rectangle {
                width: inferenceList.width
                height: contentCol.implicitHeight + 16
                radius: 4
                color: root.selectedInferenceId === modelData.id
                       ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                       : Theme.cardBackground
                border.width: root.selectedInferenceId === modelData.id ? 1 : 0
                border.color: Theme.accent

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.selectedInferenceId = modelData.id
                    }
                }

                ColumnLayout {
                    id: contentCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    spacing: 4

                    // Ligne titre + sévérité
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            width: sevLabel.implicitWidth + 10
                            height: 18
                            radius: 3
                            color: Qt.rgba(
                                Qt.color(root.severityColors[modelData.severity] || Theme.info).r,
                                Qt.color(root.severityColors[modelData.severity] || Theme.info).g,
                                Qt.color(root.severityColors[modelData.severity] || Theme.info).b,
                                0.2
                            )

                            Label {
                                id: sevLabel
                                anchors.centerIn: parent
                                text: root.severityLabels[modelData.severity] || "?"
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
                            elide: Text.ElideRight
                        }
                    }

                    // Détails
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Label {
                            text: "📍 " + (modelData.roomId || "—")
                            font.pixelSize: 10
                            color: Theme.textSecondary
                        }

                        Label {
                            text: "🎯 " + Math.round((modelData.confidence || 0) * 100) + "%"
                            font.pixelSize: 10
                            color: Theme.textSecondary
                        }
                    }

                    // Explication (si sélectionné)
                    Loader {
                        Layout.fillWidth: true
                        active: root.selectedInferenceId === modelData.id && modelData.explanation
                        sourceComponent: Rectangle {
                            height: explText.implicitHeight + 12
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.03)

                            Label {
                                id: explText
                                anchors.fill: parent
                                anchors.margins: 6
                                text: modelData.explanation || ""
                                font.pixelSize: 10
                                color: Theme.textSecondary
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }

        // ── Vide ──
        Label {
            visible: root.inferences.length === 0
            text: "Aucune inférence — lancer un cycle cognitif"
            font.pixelSize: 11
            font.italic: true
            color: Theme.textSecondary
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
