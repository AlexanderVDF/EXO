import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    height: 72
    color: "#252526"

    property real audioLevel: 0.0
    property bool isListening: false
    property bool isSpeaking: false
    property string sttStatus: "disconnected"
    property string ttsStatus: "ready"
    property string temperature: ""
    property string weatherDesc: ""

    // Bordure supérieure
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: "#3C3C3C"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 0

        // ── Visualizer audio (partie gauche) ──
        Visualizer {
            Layout.preferredWidth: parent.width * 0.4
            Layout.fillHeight: true
            Layout.topMargin: 6
            Layout.bottomMargin: 6
            audioLevel: root.audioLevel
            active: root.isListening || root.isSpeaking
            lineColor: root.isSpeaking ? "#4EC9B0" : "#007ACC"
        }

        Item { Layout.fillWidth: true }

        // ── Indicateurs droite ──
        RowLayout {
            spacing: 16

            // Météo
            Text {
                visible: root.temperature.length > 0
                text: root.temperature + " " + root.weatherDesc
                font.family: "Cascadia Code, Fira Code, Consolas"
                font.pixelSize: 11
                color: "#A0A0A0"
            }

            // Séparateur
            Rectangle {
                visible: root.temperature.length > 0
                width: 1
                height: 14
                color: "#3C3C3C"
            }

            // STT status
            Row {
                spacing: 4
                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.sttStatus === "connected" ? "#4EC9B0"
                         : root.sttStatus === "connecting" ? "#DCDCAA"
                         : "#F44747"
                }
                Text {
                    text: "STT"
                    font.family: "Cascadia Code, Fira Code, Consolas"
                    font.pixelSize: 11
                    color: "#A0A0A0"
                }
            }

            // TTS status
            Row {
                spacing: 4
                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.ttsStatus === "ready" ? "#4EC9B0" : "#DCDCAA"
                }
                Text {
                    text: "TTS"
                    font.family: "Cascadia Code, Fira Code, Consolas"
                    font.pixelSize: 11
                    color: "#A0A0A0"
                }
            }

            // Séparateur
            Rectangle {
                width: 1
                height: 14
                color: "#3C3C3C"
            }

            // Heure
            Text {
                id: clockText
                font.family: "Cascadia Code, Fira Code, Consolas"
                font.pixelSize: 11
                color: "#A0A0A0"
                text: Qt.formatTime(new Date(), "hh:mm")

                Timer {
                    interval: 30000
                    running: true
                    repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), "hh:mm")
                }
            }
        }
    }
}
