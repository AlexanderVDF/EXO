import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  SimulationRiskPanel — Panneau des risques détectés
//  par le moteur de simulation spatiale.
//
//  Affiche probabilité, impact, score, zone concernée,
//  recommandation et sévérité pour chaque risque.
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    // ── SimulationController (C++) ──
    property var simController: typeof simulationController !== 'undefined' ? simulationController : null

    // ── Données ──
    property var risks: simController ? simController.risks : []

    // ── Score global ──
    property double globalRiskScore: {
        if (!risks || risks.length === 0) return 0.0
        var maxScore = 0
        for (var i = 0; i < risks.length; i++) {
            var s = (risks[i].probability || 0) * (risks[i].impact || 0)
            if (s > maxScore) maxScore = s
        }
        return maxScore
    }

    function _severityColor(severity) {
        switch (String(severity)) {
            case "4": case "Critical": return Theme.error
            case "3": case "High":     return "#CE9178"
            case "2": case "Medium":   return Theme.warning
            case "1": case "Low":      return Theme.info
            default:                   return Theme.textMuted
        }
    }

    function _severityLabel(severity) {
        switch (String(severity)) {
            case "4": case "Critical": return "CRITIQUE"
            case "3": case "High":     return "ÉLEVÉ"
            case "2": case "Medium":   return "MOYEN"
            case "1": case "Low":      return "FAIBLE"
            default:                   return "—"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing8
        spacing: Theme.spacing8

        // ══════════════
        //  Header + Score global
        // ══════════════
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "RISQUES SIMULATION"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontLabel
                font.weight: Font.Bold
                color: Theme.textSecondary
                font.letterSpacing: 1.2
            }
            Item { Layout.fillWidth: true }

            // Score badge
            Rectangle {
                width: 50; height: 22; radius: 11
                color: {
                    if (root.globalRiskScore > 0.7) return Qt.rgba(Qt.color(Theme.error).r, Qt.color(Theme.error).g, Qt.color(Theme.error).b, 0.2)
                    if (root.globalRiskScore > 0.4) return Qt.rgba(Qt.color(Theme.warning).r, Qt.color(Theme.warning).g, Qt.color(Theme.warning).b, 0.2)
                    return Qt.rgba(Qt.color(Theme.success).r, Qt.color(Theme.success).g, Qt.color(Theme.success).b, 0.2)
                }
                border.width: 1
                border.color: {
                    if (root.globalRiskScore > 0.7) return Theme.error
                    if (root.globalRiskScore > 0.4) return Theme.warning
                    return Theme.success
                }

                Text {
                    anchors.centerIn: parent
                    text: (root.globalRiskScore * 100).toFixed(0) + "%"
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: {
                        if (root.globalRiskScore > 0.7) return Theme.error
                        if (root.globalRiskScore > 0.4) return Theme.warning
                        return Theme.success
                    }
                }
            }
        }

        // ══════════════
        //  Jauge globale
        // ══════════════
        Rectangle {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: Theme.bgPrimary

            Rectangle {
                width: parent.width * Math.min(root.globalRiskScore, 1.0)
                height: parent.height
                radius: 3
                color: {
                    if (root.globalRiskScore > 0.7) return Theme.error
                    if (root.globalRiskScore > 0.4) return Theme.warning
                    return Theme.success
                }

                Behavior on width {
                    NumberAnimation { duration: Theme.animNormal }
                }
            }
        }

        // ══════════════
        //  Placeholder (aucun risque)
        // ══════════════
        Text {
            text: "Aucun risque détecté. Lancez une simulation."
            font.family: Theme.fontMono
            font.pixelSize: 10
            color: Theme.textMuted
            visible: !root.risks || root.risks.length === 0
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 20
        }

        // ══════════════
        //  Liste des risques
        // ══════════════
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.risks
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                width: parent ? parent.width : 0
                height: riskContent.implicitHeight + 12
                radius: Theme.radiusMedium
                color: riskHover.containsMouse ? Theme.bgActive : Theme.bgElevated
                border.width: 1
                border.color: Qt.rgba(Qt.color(_severityColor(modelData.severity)).r,
                                      Qt.color(_severityColor(modelData.severity)).g,
                                      Qt.color(_severityColor(modelData.severity)).b, 0.3)

                MouseArea {
                    id: riskHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }

                ColumnLayout {
                    id: riskContent
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 3

                    // Ligne 1: sévérité + label
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            width: sevText.implicitWidth + 8; height: 14; radius: 3
                            color: Qt.rgba(Qt.color(_severityColor(modelData.severity)).r,
                                           Qt.color(_severityColor(modelData.severity)).g,
                                           Qt.color(_severityColor(modelData.severity)).b, 0.2)
                            Text {
                                id: sevText
                                anchors.centerIn: parent
                                text: _severityLabel(modelData.severity)
                                font.family: Theme.fontMono
                                font.pixelSize: 7
                                font.weight: Font.Bold
                                color: _severityColor(modelData.severity)
                            }
                        }

                        Text {
                            text: modelData.label || "Risque"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Ligne 2: barres probabilité + impact
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Probabilité
                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true
                            Text { text: "Probabilité"; font.family: Theme.fontMono; font.pixelSize: 7; color: Theme.textMuted }
                            Rectangle {
                                Layout.fillWidth: true; height: 3; radius: 1.5; color: Theme.bgPrimary
                                Rectangle {
                                    width: parent.width * Math.min(modelData.probability || 0, 1.0)
                                    height: parent.height; radius: 1.5
                                    color: Theme.warning
                                }
                            }
                            Text {
                                text: ((modelData.probability || 0) * 100).toFixed(0) + "%"
                                font.family: Theme.fontMono; font.pixelSize: 7; color: Theme.textSecondary
                            }
                        }

                        // Impact
                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true
                            Text { text: "Impact"; font.family: Theme.fontMono; font.pixelSize: 7; color: Theme.textMuted }
                            Rectangle {
                                Layout.fillWidth: true; height: 3; radius: 1.5; color: Theme.bgPrimary
                                Rectangle {
                                    width: parent.width * Math.min(modelData.impact || 0, 1.0)
                                    height: parent.height; radius: 1.5
                                    color: Theme.error
                                }
                            }
                            Text {
                                text: ((modelData.impact || 0) * 100).toFixed(0) + "%"
                                font.family: Theme.fontMono; font.pixelSize: 7; color: Theme.textSecondary
                            }
                        }
                    }

                    // Ligne 3: zone + tick
                    RowLayout {
                        Layout.fillWidth: true
                        visible: (modelData.zone || "") !== "" || (modelData.detectedAtTick || 0) > 0

                        Text {
                            text: "📍 " + (modelData.zone || "—")
                            font.family: Theme.fontMono; font.pixelSize: 8; color: Theme.textMuted
                            visible: (modelData.zone || "") !== ""
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "T" + (modelData.detectedAtTick || 0)
                            font.family: Theme.fontMono; font.pixelSize: 7; color: Theme.textMuted
                            visible: (modelData.detectedAtTick || 0) > 0
                        }
                    }

                    // Ligne 4: recommandation
                    Text {
                        text: "💡 " + (modelData.recommendation || "")
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        color: Theme.info
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        visible: (modelData.recommendation || "") !== ""
                    }
                }
            }
        }
    }
}
