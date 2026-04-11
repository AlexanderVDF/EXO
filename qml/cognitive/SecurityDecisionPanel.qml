import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  SecurityDecisionPanel — Actions recommandées & urgences
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var engine: null
    property var actions: engine ? engine.getRecommendedActions() : []

    Connections {
        target: engine
        function onSecurityActionRecommended(action) { root.actions = engine.getRecommendedActions() }
        function onCycleCompleted() { root.actions = engine.getRecommendedActions() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Label {
            text: "🎯 Décisions & Actions"
            font.pixelSize: 14; font.bold: true
            color: Theme.textPrimary
        }

        // ── Urgences ──
        Repeater {
            model: {
                if (!engine) return []
                var alerts = engine.activeAlerts || []
                return alerts.filter(function(a) { return a.severity >= 5 }) // Emergency
            }

            Rectangle {
                Layout.fillWidth: true
                height: 48; radius: 6
                color: Qt.rgba(1, 0, 0.25, 0.15)
                border.color: "#FF0040"; border.width: 2

                RowLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 8

                    Label {
                        text: "🚨 URGENCE"
                        font.pixelSize: 12; font.bold: true; color: "#FF0040"
                    }
                    Label {
                        Layout.fillWidth: true
                        text: modelData.description || ""
                        font.pixelSize: 10; color: Theme.textPrimary
                        elide: Text.ElideRight
                    }
                    Button {
                        text: "Appel secours"
                        font.pixelSize: 9
                        onClicked: console.log("Emergency call for", modelData.roomId)
                    }
                }
            }
        }

        // ── Actions recommandées ──
        Label {
            text: "Actions recommandées (" + root.actions.length + ")"
            font.pixelSize: 12; font.bold: true
            color: Theme.textSecondary
            visible: root.actions.length > 0
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true; spacing: 4
            model: root.actions

            delegate: Rectangle {
                width: ListView.view.width
                height: 44; radius: 4
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.06)
                border.color: Theme.accent; border.width: 1

                RowLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Label {
                            text: modelData.label || ""
                            font.pixelSize: 11; font.bold: true
                            color: Theme.textPrimary
                        }
                        Label {
                            text: modelData.detail || ""
                            font.pixelSize: 9; color: Theme.textSecondary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Label {
                        text: "📍 " + (modelData.roomId || "—")
                        font.pixelSize: 9; color: Theme.textSecondary
                    }

                    Button {
                        text: "Exécuter"
                        font.pixelSize: 9
                        onClicked: console.log("Execute action:", modelData.label, "in", modelData.roomId)
                    }
                }
            }
        }

        // ── Historique incidents ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: "📜 Incidents : " + (engine ? (engine.securityState.incidentCount || 0) : 0)
                font.pixelSize: 10
                color: Theme.textSecondary
            }

            Item { Layout.fillWidth: true }

            Label {
                text: "Non résolus : " + (engine ? engine.recentIncidents.length : 0)
                font.pixelSize: 10
                color: Theme.warning
            }
        }
    }
}
