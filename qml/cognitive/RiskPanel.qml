import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  RiskPanel — Analyse de risques (RiskAnalysisAgent)
//  Probabilité, impact, zone, recommandations
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var risks: []  // [{ id, label, probability, impact, zone, category, recommendations: [], timestamp }]

    // ── Connexion temps réel ──
    Connections {
        target: typeof pipelineEventBus !== 'undefined' ? pipelineEventBus : null

        function onEventEmitted(event) {
            if (event.event_type !== "risk_assessment" && !event.risk) return
            var risk = event.risk || event
            var copy = root.risks.slice()

            // Mettre à jour si existant
            var found = false
            for (var i = 0; i < copy.length; i++) {
                if (copy[i].id === risk.risk_id) {
                    copy[i] = Object.assign({}, copy[i], {
                        probability: risk.probability || copy[i].probability,
                        impact: risk.impact || copy[i].impact,
                        recommendations: risk.recommendations || copy[i].recommendations,
                        timestamp: risk.timestamp || new Date().toISOString()
                    })
                    found = true
                    break
                }
            }
            if (!found) {
                copy.push({
                    id: risk.risk_id || ("risk_" + Date.now()),
                    label: risk.label || risk.description || "Risque inconnu",
                    probability: risk.probability || 0,
                    impact: risk.impact || 0,
                    zone: risk.zone || "",
                    category: risk.category || "general",
                    recommendations: risk.recommendations || [],
                    timestamp: risk.timestamp || new Date().toISOString()
                })
            }
            root.risks = copy
        }
    }

    // ── Score de risque = probabilité × impact ──
    function _riskScore(risk) {
        return (risk.probability || 0) * (risk.impact || 0)
    }

    function _riskLevel(score) {
        if (score >= 0.7) return "critical"
        if (score >= 0.4) return "high"
        if (score >= 0.2) return "medium"
        return "low"
    }

    function _riskColor(score) {
        if (score >= 0.7) return Theme.error
        if (score >= 0.4) return "#CE9178"
        if (score >= 0.2) return Theme.warning
        return Theme.success
    }

    function _riskLevelLabel(score) {
        if (score >= 0.7) return "Critique"
        if (score >= 0.4) return "Élevé"
        if (score >= 0.2) return "Moyen"
        return "Faible"
    }

    function _categoryIcon(cat) {
        switch (cat) {
            case "security":    return "🔒"
            case "safety":      return "🛡"
            case "performance": return "⚡"
            case "hardware":    return "🔧"
            case "network":     return "📡"
            case "privacy":     return "👁"
            default:            return "⚠"
        }
    }

    // ── Tri par score décroissant ──
    property var sortedRisks: {
        var copy = root.risks.slice()
        copy.sort(function(a, b) { return _riskScore(b) - _riskScore(a) })
        return copy
    }

    // ── Score global ──
    property real globalRiskScore: {
        if (root.risks.length === 0) return 0
        var maxScore = 0
        for (var i = 0; i < root.risks.length; i++) {
            var s = _riskScore(root.risks[i])
            if (s > maxScore) maxScore = s
        }
        return maxScore
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing8
        spacing: Theme.spacing8

        // ── Header ──
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "RISQUES"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontLabel
                font.weight: Font.Bold
                color: Theme.textSecondary
                font.letterSpacing: 1.2
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: globalScoreText.implicitWidth + 12
                height: 20
                radius: 10
                color: Qt.rgba(
                    Qt.color(root._riskColor(root.globalRiskScore)).r,
                    Qt.color(root._riskColor(root.globalRiskScore)).g,
                    Qt.color(root._riskColor(root.globalRiskScore)).b, 0.15)

                Text {
                    id: globalScoreText
                    anchors.centerIn: parent
                    text: root._riskLevelLabel(root.globalRiskScore)
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: root._riskColor(root.globalRiskScore)
                }
            }
        }

        // ── Risk matrix mini (3×3) ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            radius: Theme.radiusMedium
            color: Theme.bgElevated

            GridLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacing4
                columns: 4
                rowSpacing: 2
                columnSpacing: 2

                // Header row
                Text { text: ""; Layout.preferredWidth: 30 }
                Text { text: "Faible"; font.family: Theme.fontMono; font.pixelSize: 8; color: Theme.textMuted; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                Text { text: "Moyen"; font.family: Theme.fontMono; font.pixelSize: 8; color: Theme.textMuted; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                Text { text: "Fort"; font.family: Theme.fontMono; font.pixelSize: 8; color: Theme.textMuted; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }

                // High probability
                Text { text: "Haut"; font.family: Theme.fontMono; font.pixelSize: 8; color: Theme.textMuted; Layout.preferredWidth: 30 }
                Rectangle { Layout.fillWidth: true; height: 16; radius: 2; color: Theme.warning; opacity: _cellCount(0.33,0.66,0.66,1.0) > 0 ? 0.8 : 0.1;
                    Text { anchors.centerIn: parent; text: _cellCount(0.33,0.66,0.66,1.0).toString(); font.pixelSize: 8; color: Theme.textPrimary; visible: _cellCount(0.33,0.66,0.66,1.0) > 0 } }
                Rectangle { Layout.fillWidth: true; height: 16; radius: 2; color: "#CE9178"; opacity: _cellCount(0.33,0.66,0.33,0.66) > 0 ? 0.8 : 0.1;
                    Text { anchors.centerIn: parent; text: _cellCount(0.33,0.66,0.33,0.66).toString(); font.pixelSize: 8; color: Theme.textPrimary; visible: _cellCount(0.33,0.66,0.33,0.66) > 0 } }
                Rectangle { Layout.fillWidth: true; height: 16; radius: 2; color: Theme.error; opacity: _cellCount(0.66,1.0,0.66,1.0) > 0 ? 0.8 : 0.1;
                    Text { anchors.centerIn: parent; text: _cellCount(0.66,1.0,0.66,1.0).toString(); font.pixelSize: 8; color: Theme.textPrimary; visible: _cellCount(0.66,1.0,0.66,1.0) > 0 } }

                // Medium probability
                Text { text: "Moy"; font.family: Theme.fontMono; font.pixelSize: 8; color: Theme.textMuted; Layout.preferredWidth: 30 }
                Rectangle { Layout.fillWidth: true; height: 16; radius: 2; color: Theme.success; opacity: _cellCount(0,0.33,0.33,0.66) > 0 ? 0.8 : 0.1;
                    Text { anchors.centerIn: parent; text: _cellCount(0,0.33,0.33,0.66).toString(); font.pixelSize: 8; color: Theme.textPrimary; visible: _cellCount(0,0.33,0.33,0.66) > 0 } }
                Rectangle { Layout.fillWidth: true; height: 16; radius: 2; color: Theme.warning; opacity: _cellCount(0.33,0.66,0,0.33) > 0 ? 0.8 : 0.1;
                    Text { anchors.centerIn: parent; text: _cellCount(0.33,0.66,0,0.33).toString(); font.pixelSize: 8; color: Theme.textPrimary; visible: _cellCount(0.33,0.66,0,0.33) > 0 } }
                Rectangle { Layout.fillWidth: true; height: 16; radius: 2; color: "#CE9178"; opacity: _cellCount(0.66,1.0,0.33,0.66) > 0 ? 0.8 : 0.1;
                    Text { anchors.centerIn: parent; text: _cellCount(0.66,1.0,0.33,0.66).toString(); font.pixelSize: 8; color: Theme.textPrimary; visible: _cellCount(0.66,1.0,0.33,0.66) > 0 } }

                // Low probability
                Text { text: "Bas"; font.family: Theme.fontMono; font.pixelSize: 8; color: Theme.textMuted; Layout.preferredWidth: 30 }
                Rectangle { Layout.fillWidth: true; height: 16; radius: 2; color: Theme.success; opacity: _cellCount(0,0.33,0,0.33) > 0 ? 0.8 : 0.1;
                    Text { anchors.centerIn: parent; text: _cellCount(0,0.33,0,0.33).toString(); font.pixelSize: 8; color: Theme.textPrimary; visible: _cellCount(0,0.33,0,0.33) > 0 } }
                Rectangle { Layout.fillWidth: true; height: 16; radius: 2; color: Theme.success; opacity: _cellCount(0,0.33,0.33,0.66) > 0 ? 0.8 : 0.1;
                    Text { anchors.centerIn: parent; text: _cellCount(0,0.33,0.33,0.66).toString(); font.pixelSize: 8; color: Theme.textPrimary; visible: _cellCount(0,0.33,0.33,0.66) > 0 } }
                Rectangle { Layout.fillWidth: true; height: 16; radius: 2; color: Theme.warning; opacity: _cellCount(0.66,1.0,0,0.33) > 0 ? 0.8 : 0.1;
                    Text { anchors.centerIn: parent; text: _cellCount(0.66,1.0,0,0.33).toString(); font.pixelSize: 8; color: Theme.textPrimary; visible: _cellCount(0.66,1.0,0,0.33) > 0 } }
            }
        }

        function _cellCount(impLo, impHi, probLo, probHi) {
            var c = 0
            for (var i = 0; i < root.risks.length; i++) {
                var r = root.risks[i]
                if (r.impact >= impLo && r.impact < impHi && r.probability >= probLo && r.probability < probHi) c++
            }
            return c
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

        // ── Liste de risques ──
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.sortedRisks
            spacing: Theme.spacing4
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                width: parent ? parent.width : 0
                height: riskCol.implicitHeight + Theme.spacing8
                radius: Theme.radiusSmall
                color: Theme.bgElevated

                property real score: root._riskScore(modelData)
                property bool expanded: false

                ColumnLayout {
                    id: riskCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacing4
                    spacing: 3

                    // Header
                    RowLayout {
                        spacing: Theme.spacing4

                        Text {
                            text: root._categoryIcon(modelData.category)
                            font.pixelSize: 14
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                font.weight: Font.DemiBold
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                spacing: Theme.spacing8

                                Text {
                                    text: "P:" + (modelData.probability * 100).toFixed(0) + "%"
                                    font.family: Theme.fontMono
                                    font.pixelSize: 9
                                    color: Theme.textMuted
                                }
                                Text {
                                    text: "I:" + (modelData.impact * 100).toFixed(0) + "%"
                                    font.family: Theme.fontMono
                                    font.pixelSize: 9
                                    color: Theme.textMuted
                                }
                                Text {
                                    text: modelData.zone || ""
                                    font.family: Theme.fontMono
                                    font.pixelSize: 9
                                    color: Theme.accent
                                    visible: text !== ""
                                }
                            }
                        }

                        // Score badge
                        Rectangle {
                            width: 40; height: 20; radius: 10
                            color: Qt.rgba(
                                Qt.color(root._riskColor(score)).r,
                                Qt.color(root._riskColor(score)).g,
                                Qt.color(root._riskColor(score)).b, 0.15)

                            Text {
                                anchors.centerIn: parent
                                text: (score * 100).toFixed(0)
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: root._riskColor(score)
                            }
                        }
                    }

                    // Risk bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 3
                        radius: 1.5
                        color: Theme.bgPrimary

                        Rectangle {
                            width: parent.width * Math.min(score, 1)
                            height: parent.height
                            radius: 1.5
                            color: root._riskColor(score)

                            Behavior on width {
                                NumberAnimation { duration: Theme.animNormal }
                            }
                        }
                    }

                    // Recommendations (toggle)
                    Repeater {
                        model: expanded ? (modelData.recommendations || []) : []
                        delegate: RowLayout {
                            Layout.leftMargin: 8
                            spacing: 4

                            Rectangle { width: 4; height: 4; radius: 2; color: Theme.accent; Layout.alignment: Qt.AlignTop; Layout.topMargin: 5 }

                            Text {
                                text: modelData
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontMicro
                                color: Theme.textSecondary
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.expanded = !parent.expanded
                }
            }
        }

        // ── Empty state ──
        Text {
            Layout.fillWidth: true
            visible: root.risks.length === 0
            text: "Aucun risque identifié"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            color: Theme.textMuted
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
