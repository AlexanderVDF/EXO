import QtQuick 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property real level: 0.0  // 0.0 → 1.0

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 6

        Text {
            text: "MICRO"
            font.family: "Cascadia Code, Fira Code, Consolas"
            font.pixelSize: 10
            font.bold: true
            color: "#5A5A5A"
            font.letterSpacing: 2
        }

        // Barre de niveau horizontale
        Rectangle {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: "#1E1E1E"

            Rectangle {
                width: Math.max(4, parent.width * root.level)
                height: parent.height
                radius: 3
                color: root.level > 0.8 ? "#F44747"
                     : root.level > 0.5 ? "#DCDCAA"
                     : "#007ACC"

                Behavior on width {
                    NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                }
            }
        }
    }
}
