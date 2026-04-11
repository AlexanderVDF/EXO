import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  VisionHeatmap — Carte d'activité par pièce
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var engine: null
    property var heatmap: engine ? engine.getActivityHeatmap() : ({})

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Label {
            text: "🔥 Heatmap d'activité"
            font.pixelSize: 13
            font.bold: true
            color: Theme.textPrimary
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: Object.keys(root.heatmap)

            delegate: Rectangle {
                width: ListView.view.width
                height: 36
                radius: 4
                color: "transparent"

                property double actLevel: root.heatmap[modelData] || 0

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 8

                    Label {
                        text: modelData
                        font.pixelSize: 11
                        color: Theme.textPrimary
                        Layout.preferredWidth: 100
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 16
                        radius: 4
                        color: Qt.rgba(0.5, 0.5, 0.5, 0.1)

                        Rectangle {
                            width: parent.width * Math.min(1, actLevel)
                            height: parent.height
                            radius: 4
                            color: actLevel > 0.7 ? Theme.error
                                 : actLevel > 0.4 ? Theme.warning
                                 : Theme.success
                        }
                    }

                    Label {
                        text: Math.round(actLevel * 100) + "%"
                        font.pixelSize: 10
                        font.bold: true
                        color: actLevel > 0.7 ? Theme.error
                             : actLevel > 0.4 ? Theme.warning
                             : Theme.success
                        Layout.preferredWidth: 40
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}
