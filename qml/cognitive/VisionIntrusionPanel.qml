import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  VisionIntrusionPanel — Détection d'intrusions
//  Lignes virtuelles et zones interdites
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var engine: null
    property var events: engine ? engine.recentEvents : []

    property var intrusionEvents: {
        var result = [];
        for (var i = 0; i < events.length; ++i) {
            if ((events[i].type || 0) === 8) result.push(events[i]);  // Intrusion
        }
        return result;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "🚨 Intrusions (" + root.intrusionEvents.length + ")"
                font.pixelSize: 13
                font.bold: true
                color: root.intrusionEvents.length > 0 ? Theme.error : Theme.textPrimary
            }
            Item { Layout.fillWidth: true }
            Label {
                text: "Zones: " + (engine ? engine.intrusionZoneIds().length : 0)
                font.pixelSize: 10
                color: Theme.textSecondary
            }
        }

        // ── Alerte active ──
        Rectangle {
            Layout.fillWidth: true
            height: 48
            radius: 6
            visible: root.intrusionEvents.length > 0
            color: Qt.rgba(1, 0, 0, 0.12)
            border.color: Theme.error
            border.width: 2

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Label {
                    text: "🚨"
                    font.pixelSize: 20
                }
                Label {
                    text: root.intrusionEvents.length + " intrusion(s) détectée(s)"
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.error
                    Layout.fillWidth: true
                }
            }

            SequentialAnimation on opacity {
                running: root.intrusionEvents.length > 0
                loops: Animation.Infinite
                NumberAnimation { to: 0.5; duration: 600 }
                NumberAnimation { to: 1.0; duration: 600 }
            }
        }

        // ── Historique intrusions ──
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.intrusionEvents

            delegate: Rectangle {
                width: ListView.view.width
                height: 48
                radius: 4
                color: Qt.rgba(1, 0, 0, 0.06)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: Theme.error
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Label {
                            text: modelData.description || "Intrusion détectée"
                            font.pixelSize: 11
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: (modelData.cameraId || "") + " • " +
                                  (modelData.roomId || "—") + " • " +
                                  Math.round((modelData.confidence || 0) * 100) + "%"
                            font.pixelSize: 9
                            color: Theme.textSecondary
                        }
                    }
                }
            }
        }
    }
}
