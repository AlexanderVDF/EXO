import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#1E1E1E"

    property string currentResponse: ""
    property bool isStreaming: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: "#252526"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                Text {
                    text: "RÉPONSE"
                    font.family: "Cascadia Code, Fira Code, Consolas"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#4EC9B0"
                    font.letterSpacing: 1.5
                }

                Item { Layout.fillWidth: true }

                // Indicateur streaming
                Row {
                    visible: root.isStreaming
                    spacing: 4

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#007ACC"

                        SequentialAnimation on opacity {
                            running: root.isStreaming
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 400 }
                            NumberAnimation { to: 1.0; duration: 400 }
                        }
                    }

                    Text {
                        text: "streaming..."
                        font.family: "Cascadia Code, Fira Code, Consolas"
                        font.pixelSize: 11
                        color: "#5A5A5A"
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: "#3C3C3C"
            }
        }

        // ── Contenu de la réponse ──
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: responseText.height + 32
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: "#5A5A5A"
                    opacity: 0.5
                }
            }

            Text {
                id: responseText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 16
                y: 16
                text: root.currentResponse.length > 0
                      ? root.currentResponse
                      : "En attente d'une commande vocale..."
                wrapMode: Text.WordWrap
                font.family: "Cascadia Code, Fira Code, Consolas"
                font.pixelSize: 13
                color: root.currentResponse.length > 0 ? "#E0E0E0" : "#5A5A5A"
                lineHeight: 1.5

                // Curseur clignotant pendant le streaming
                Text {
                    visible: root.isStreaming
                    anchors.left: parent.right
                    anchors.bottom: parent.bottom
                    text: "▌"
                    font.family: "Cascadia Code, Fira Code, Consolas"
                    font.pixelSize: 13
                    color: "#007ACC"

                    SequentialAnimation on opacity {
                        running: root.isStreaming
                        loops: Animation.Infinite
                        NumberAnimation { to: 0; duration: 500 }
                        NumberAnimation { to: 1; duration: 500 }
                    }
                }
            }
        }
    }
}
