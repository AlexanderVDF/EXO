import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  VisionExplanationPanel — Explications et détails
//  Affiche le contexte d'un événement vision sélectionné
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var engine: null
    property string selectedEventId: ""
    property var explanation: selectedEventId && engine ?
        engine.getVisionExplanation(selectedEventId) : ({})

    readonly property var typeNames: [
        "Personne", "Animal", "Véhicule", "Objet",
        "Feu", "Fumée", "Obstruction", "Chute",
        "Intrusion", "Errance", "Agitation",
        "Mvt anormal", "Objet déplacé", "Absence", "Autre"
    ]

    readonly property var severityNames: ["Info", "Basse", "Moyenne", "Haute", "Critique", "Urgence"]
    readonly property var severityColors: [
        Theme.textSecondary, Theme.info, Theme.warning,
        "#FF8C00", Theme.error, "#FF0040"
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Label {
            text: "🔍 Explication"
            font.pixelSize: 13
            font.bold: true
            color: Theme.textPrimary
        }

        // ── Pas de sélection ──
        Label {
            visible: !root.selectedEventId
            text: "Sélectionner un événement pour voir les détails"
            font.pixelSize: 11
            font.italic: true
            color: Theme.textSecondary
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }

        // ── Détails de l'événement ──
        ColumnLayout {
            visible: root.selectedEventId && !root.explanation.error
            Layout.fillWidth: true
            spacing: 6

            // En-tête
            Rectangle {
                Layout.fillWidth: true
                height: 48
                radius: 6
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Label {
                        text: root.typeNames[root.explanation.type || 0] || "?"
                        font.pixelSize: 14
                        font.bold: true
                        color: Theme.textPrimary
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: sevLabel.width + 12
                        height: 20
                        radius: 10
                        color: root.severityColors[root.explanation.severity || 0]
                        Label {
                            id: sevLabel
                            anchors.centerIn: parent
                            text: root.severityNames[root.explanation.severity || 0]
                            font.pixelSize: 10
                            color: "white"
                        }
                    }
                }
            }

            // Propriétés
            Repeater {
                model: [
                    { label: "Description", value: root.explanation.description || "—" },
                    { label: "Caméra", value: root.explanation.camera || "—" },
                    { label: "Pièce", value: root.explanation.room || "—" },
                    { label: "Confiance", value: Math.round((root.explanation.confidence || 0) * 100) + "%" },
                    { label: "Horodatage", value: root.explanation.timestamp || "—" }
                ]
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Label {
                        text: modelData.label + " :"
                        font.pixelSize: 10
                        font.bold: true
                        color: Theme.textSecondary
                        Layout.preferredWidth: 80
                    }
                    Label {
                        text: modelData.value
                        font.pixelSize: 10
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // ── Incidents similaires ──
            Label {
                visible: root.explanation.similarIncidents &&
                         root.explanation.similarIncidents.length > 0
                text: "📎 Incidents similaires (" +
                      (root.explanation.similarIncidents ? root.explanation.similarIncidents.length : 0) + ")"
                font.pixelSize: 11
                font.bold: true
                color: Theme.textSecondary
                Layout.topMargin: 8
            }

            ListView {
                visible: root.explanation.similarIncidents &&
                         root.explanation.similarIncidents.length > 0
                Layout.fillWidth: true
                height: Math.min(120, (root.explanation.similarIncidents ?
                        root.explanation.similarIncidents.length : 0) * 30)
                clip: true
                spacing: 2
                model: root.explanation.similarIncidents || []

                delegate: Label {
                    text: "• " + (modelData.description || "—") +
                          " (" + (modelData.cameraId || "") + ")"
                    font.pixelSize: 9
                    color: Theme.textSecondary
                    elide: Text.ElideRight
                    width: ListView.view.width
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
