import QtQuick 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property string currentStatus: "Idle"

    // Couleur selon l'état
    readonly property color statusColor: {
        switch (currentStatus) {
        case "Listening":    return "#007ACC"
        case "Transcribing": return "#DCDCAA"
        case "Thinking":     return "#C586C0"
        case "Speaking":     return "#4EC9B0"
        default:             return "#5A5A5A"
        }
    }

    readonly property string statusIcon: {
        switch (currentStatus) {
        case "Listening":    return "●"
        case "Transcribing": return "⟳"
        case "Thinking":     return "◌"
        case "Speaking":     return "◉"
        default:             return "○"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        spacing: 6

        Text {
            text: "ÉTAT"
            font.family: "Cascadia Code, Fira Code, Consolas"
            font.pixelSize: 10
            font.bold: true
            color: "#5A5A5A"
            font.letterSpacing: 2
        }

        RowLayout {
            spacing: 10

            // Indicateur rond avec animation
            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: root.statusColor

                SequentialAnimation on opacity {
                    running: root.currentStatus === "Listening" ||
                             root.currentStatus === "Thinking"
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                }
            }

            Text {
                text: root.currentStatus
                font.family: "Cascadia Code, Fira Code, Consolas"
                font.pixelSize: 14
                color: root.statusColor
            }
        }
    }
}
