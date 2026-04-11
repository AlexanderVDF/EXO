import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  SecurityExplanationPanel — Explications des alertes sécurité
//  Affiche l'explication détaillée pour chaque alerte sélectionnée
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var engine: null
    property string selectedAlertId: ""
    property var explanation: ({})

    onSelectedAlertIdChanged: {
        if (engine && selectedAlertId.length > 0)
            explanation = engine.getSecurityExplanation(selectedAlertId)
        else
            explanation = {}
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Label {
            text: "📋 Explications Sécurité"
            font.pixelSize: 14; font.bold: true
            color: Theme.textPrimary
        }

        // ── Sélecteur d'alerte ──
        Rectangle {
            Layout.fillWidth: true
            height: 32; radius: 4
            color: Theme.surface

            ComboBox {
                anchors.fill: parent
                anchors.margins: 2
                model: engine ? engine.activeAlerts : []
                textRole: "description"
                valueRole: "id"
                font.pixelSize: 10
                onCurrentValueChanged: {
                    if (currentValue)
                        root.selectedAlertId = currentValue
                }
            }
        }

        // ── Détails de l'explication ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 6
            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.4)
            border.color: Theme.border; border.width: 1
            visible: Object.keys(root.explanation).length > 0

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Type de risque
                RowLayout {
                    spacing: 8
                    Label { text: "Type :"; font.pixelSize: 11; font.bold: true; color: Theme.textSecondary }
                    Label {
                        text: {
                            var types = ["Intrusion", "Incendie", "Fumée", "Électrique",
                                         "Réseau", "Domotique", "Inondation", "Gaz",
                                         "Suspect", "Non autorisé", "Autre"]
                            return types[root.explanation.riskType] || "Inconnu"
                        }
                        font.pixelSize: 11; color: Theme.textPrimary
                    }
                }

                // Pièce
                RowLayout {
                    spacing: 8
                    Label { text: "Pièce :"; font.pixelSize: 11; font.bold: true; color: Theme.textSecondary }
                    Label { text: root.explanation.roomId || "—"; font.pixelSize: 11; color: Theme.textPrimary }
                }

                // Confiance
                RowLayout {
                    spacing: 8
                    Label { text: "Confiance :"; font.pixelSize: 11; font.bold: true; color: Theme.textSecondary }
                    Label {
                        text: Math.round((root.explanation.confidence || 0) * 100) + "%"
                        font.pixelSize: 11; color: Theme.warning
                    }
                }

                // Séparateur
                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                // Explication détaillée
                Label {
                    text: "Analyse :"
                    font.pixelSize: 11; font.bold: true
                    color: Theme.textSecondary
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Label {
                        width: parent.width
                        text: root.explanation.explanation || "Aucune explication disponible."
                        font.pixelSize: 11
                        color: Theme.textPrimary
                        wrapMode: Text.WordWrap
                        lineHeight: 1.4
                    }
                }
            }
        }

        // ── Placeholder quand aucune alerte ──
        Label {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Object.keys(root.explanation).length === 0
            text: "Sélectionnez une alerte pour voir l'explication détaillée"
            font.pixelSize: 11; font.italic: true
            color: Theme.textSecondary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
