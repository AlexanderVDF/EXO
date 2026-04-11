import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  FirePanel — Détails des alertes incendie / fumée
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var engine: null

    property var alerts: {
        if (!engine) return []
        var all = engine.activeAlerts || []
        // RiskType::Fire=1, Smoke=2
        return all.filter(function(a) { return a.riskType === 1 || a.riskType === 2 })
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "🔥 Incendie / Fumée"
                font.pixelSize: 14; font.bold: true
                color: Theme.textPrimary
            }
            Item { Layout.fillWidth: true }
            Label {
                text: root.alerts.length + " alerte(s)"
                font.pixelSize: 11
                color: root.alerts.length > 0 ? "#FF4500" : Theme.textSecondary
            }
        }

        // ── Indicateurs température ──
        Rectangle {
            Layout.fillWidth: true
            height: 36; radius: 4
            color: Qt.rgba(1, 0.27, 0, 0.08)
            visible: root.alerts.length > 0

            RowLayout {
                anchors.fill: parent; anchors.margins: 8; spacing: 12

                Label {
                    text: "Seuil incendie : " + 50 + "°C"
                    font.pixelSize: 10; color: "#FF4500"
                }
                Label {
                    text: "Seuil fumée : " + 30 + "%"
                    font.pixelSize: 10; color: Theme.warning
                }
                Label {
                    text: "Seuil CO₂ : 1500 ppm"
                    font.pixelSize: 10; color: Theme.info
                }
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true; spacing: 6
            model: root.alerts

            delegate: Rectangle {
                width: ListView.view.width
                height: col.implicitHeight + 16
                radius: 6
                color: Qt.rgba(1, 0.27, 0, 0.08)
                border.color: "#FF4500"; border.width: 1

                ColumnLayout {
                    id: col
                    anchors { left: parent.left; right: parent.right; margins: 8; verticalCenter: parent.verticalCenter }
                    spacing: 4

                    Label {
                        Layout.fillWidth: true
                        text: modelData.description || ""
                        font.pixelSize: 11; font.bold: true
                        color: Theme.textPrimary; wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        spacing: 12
                        Label { text: "📍 " + (modelData.roomId || "—"); font.pixelSize: 10; color: Theme.textSecondary }
                        Label { text: "🎯 " + Math.round((modelData.confidence || 0) * 100) + "%"; font.pixelSize: 10; color: Theme.warning }

                        Rectangle {
                            width: 60; height: 14; radius: 2
                            color: modelData.severity >= 4 ? "#FF0040" : "#FF4500"
                            Label {
                                anchors.centerIn: parent
                                text: modelData.severity >= 4 ? "URGENCE" : "CRITIQUE"
                                font.pixelSize: 8; font.bold: true; color: "white"
                            }
                        }
                    }

                    Label {
                        visible: !!modelData.explanation
                        text: modelData.explanation || ""
                        font.pixelSize: 10; font.italic: true
                        color: Theme.info; wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
