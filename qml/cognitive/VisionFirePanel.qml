import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  VisionFirePanel — Détection feu et fumée
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var engine: null
    property var events: engine ? engine.recentEvents : []

    property var fireEvents: {
        var result = [];
        for (var i = 0; i < events.length; ++i) {
            var t = events[i].type || 0;
            if (t === 4 || t === 5) result.push(events[i]);  // Fire, Smoke
        }
        return result;
    }

    property int fireCount: {
        var c = 0;
        for (var i = 0; i < fireEvents.length; ++i)
            if (fireEvents[i].type === 4) c++;
        return c;
    }

    property int smokeCount: {
        var c = 0;
        for (var i = 0; i < fireEvents.length; ++i)
            if (fireEvents[i].type === 5) c++;
        return c;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Label {
            text: "🔥 Feu & Fumée"
            font.pixelSize: 13
            font.bold: true
            color: root.fireEvents.length > 0 ? Theme.error : Theme.textPrimary
        }

        // ── Indicateurs ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                height: 64
                radius: 6
                color: root.fireCount > 0 ? Qt.rgba(1, 0, 0, 0.12) : Qt.rgba(0.5, 0.5, 0.5, 0.05)
                border.color: root.fireCount > 0 ? "#FF0040" : "transparent"
                border.width: root.fireCount > 0 ? 2 : 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    Label {
                        text: "🔥 " + root.fireCount
                        font.pixelSize: 20
                        font.bold: true
                        color: root.fireCount > 0 ? "#FF0040" : Theme.textSecondary
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: "Détections feu"
                        font.pixelSize: 10
                        color: Theme.textSecondary
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                SequentialAnimation on opacity {
                    running: root.fireCount > 0
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.5; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 64
                radius: 6
                color: root.smokeCount > 0 ? Qt.rgba(1, 0.5, 0, 0.12) : Qt.rgba(0.5, 0.5, 0.5, 0.05)
                border.color: root.smokeCount > 0 ? "#FF8C00" : "transparent"
                border.width: root.smokeCount > 0 ? 2 : 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    Label {
                        text: "💨 " + root.smokeCount
                        font.pixelSize: 20
                        font.bold: true
                        color: root.smokeCount > 0 ? "#FF8C00" : Theme.textSecondary
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: "Détections fumée"
                        font.pixelSize: 10
                        color: Theme.textSecondary
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }

        // ── Historique ──
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.fireEvents

            delegate: Rectangle {
                width: ListView.view.width
                height: 40
                radius: 4
                color: modelData.type === 4 ? Qt.rgba(1, 0, 0, 0.08)
                                            : Qt.rgba(1, 0.5, 0, 0.08)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    Label {
                        text: modelData.type === 4 ? "🔥" : "💨"
                        font.pixelSize: 14
                    }
                    Label {
                        text: modelData.description || "Détection"
                        font.pixelSize: 11
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        text: modelData.cameraId || ""
                        font.pixelSize: 9
                        color: Theme.textSecondary
                    }
                }
            }
        }
    }
}
