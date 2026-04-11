import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  SpatialRiskPanel — Risques cognitifs spatiaux
//  Distinct de SimulationRiskPanel : basé sur l'inférence,
//  pas sur la simulation. Affiche les risques du SpatialReasoner.
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var engine: null
    property var risks: engine ? engine.risks : []
    property double globalRisk: engine ? engine.globalRisk : 0.0

    readonly property var severityLabels: ["Info", "Faible", "Moyen", "Élevé", "Critique"]
    readonly property var severityColors: [Theme.info, Theme.success, Theme.warning, "#CE9178", Theme.error]

    function _severityIndex(risk) {
        return risk.severity || 0
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // ── En-tête + risque global ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: "🛡 Risques Cognitifs"
                font.pixelSize: 14
                font.bold: true
                color: Theme.textPrimary
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: riskBadge.implicitWidth + 14
                height: 22
                radius: 4
                color: root.globalRisk >= 0.7 ? Qt.rgba(1, 0.3, 0.3, 0.2) :
                       root.globalRisk >= 0.4 ? Qt.rgba(1, 0.7, 0.3, 0.2) :
                                                 Qt.rgba(0.3, 1, 0.5, 0.2)

                Label {
                    id: riskBadge
                    anchors.centerIn: parent
                    text: Math.round(root.globalRisk * 100) + "% global"
                    font.pixelSize: 10
                    font.bold: true
                    color: root.globalRisk >= 0.7 ? Theme.error :
                           root.globalRisk >= 0.4 ? Theme.warning : Theme.success
                }
            }
        }

        // ── Barre de risque global ──
        Rectangle {
            Layout.fillWidth: true
            height: 8
            radius: 4
            color: Qt.rgba(1, 1, 1, 0.05)

            Rectangle {
                width: parent.width * root.globalRisk
                height: parent.height
                radius: 4
                color: root.globalRisk >= 0.7 ? Theme.error :
                       root.globalRisk >= 0.4 ? Theme.warning : Theme.success

                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }

        // ── Liste des risques ──
        ListView {
            id: riskList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.risks

            delegate: Rectangle {
                width: riskList.width
                height: riskCol.implicitHeight + 16
                radius: 4
                color: Theme.cardBackground
                border.width: _severityIndex(modelData) >= 3 ? 1 : 0
                border.color: root.severityColors[_severityIndex(modelData)] || "transparent"

                ColumnLayout {
                    id: riskCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            width: sevText.implicitWidth + 10
                            height: 18
                            radius: 3
                            color: Qt.rgba(
                                Qt.color(root.severityColors[_severityIndex(modelData)] || Theme.info).r,
                                Qt.color(root.severityColors[_severityIndex(modelData)] || Theme.info).g,
                                Qt.color(root.severityColors[_severityIndex(modelData)] || Theme.info).b,
                                0.2
                            )

                            Label {
                                id: sevText
                                anchors.centerIn: parent
                                text: root.severityLabels[_severityIndex(modelData)] || "Info"
                                font.pixelSize: 9
                                font.bold: true
                                color: root.severityColors[_severityIndex(modelData)] || Theme.info
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: modelData.description || "Risque inconnu"
                            font.pixelSize: 11
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Label {
                            text: "📍 " + (modelData.roomId || "Global")
                            font.pixelSize: 10
                            color: Theme.textSecondary
                        }

                        Label {
                            text: "🎯 " + Math.round((modelData.confidence || 0) * 100) + "%"
                            font.pixelSize: 10
                            color: Theme.textSecondary
                        }
                    }
                }
            }
        }

        // ── Vide ──
        Label {
            visible: root.risks.length === 0
            text: "Aucun risque cognitif détecté ✓"
            font.pixelSize: 11
            font.italic: true
            color: Theme.success
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
