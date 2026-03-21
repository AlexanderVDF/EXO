import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#1E1E1E"

    property string partialTranscript: ""
    ListModel {
        id: messageListModel
    }

    // Méthode pour ajouter un message
    function addMessage(text, isUser, isPartial) {
        messageListModel.append({
            "message": text,
            "isUser": isUser,
            "isPartial": isPartial || false,
            "timestamp": Qt.formatTime(new Date(), "hh:mm")
        })
        messageListView.positionViewAtEnd()
    }

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
                    text: "TRANSCRIPT"
                    font.family: "Cascadia Code, Fira Code, Consolas"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#007ACC"
                    font.letterSpacing: 1.5
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: messageListModel.count + " messages"
                    font.family: "Cascadia Code, Fira Code, Consolas"
                    font.pixelSize: 11
                    color: "#5A5A5A"
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: "#3C3C3C"
            }
        }

        // ── Message list ──
        ListView {
            id: messageListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 0
            model: messageListModel

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: "#5A5A5A"
                    opacity: 0.5
                }
            }

            delegate: Rectangle {
                width: messageListView.width
                height: msgColumn.height + 16
                color: index % 2 === 0 ? "#1E1E1E" : "#1F1F1F"

                // Bordure gauche colorée
                Rectangle {
                    anchors.left: parent.left
                    width: 3
                    height: parent.height
                    color: model.isUser ? "#007ACC" : "#4EC9B0"
                    opacity: model.isPartial ? 0.4 : 1.0
                }

                Column {
                    id: msgColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    // Ligne d'en-tête : rôle + heure
                    Row {
                        spacing: 10

                        Text {
                            text: model.isUser ? "user" : "exo"
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 11
                            font.bold: true
                            color: model.isUser ? "#007ACC" : "#4EC9B0"
                        }

                        Text {
                            text: model.timestamp
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 11
                            color: "#5A5A5A"
                        }
                    }

                    // Contenu du message
                    Text {
                        text: model.message
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.family: "Cascadia Code, Fira Code, Consolas"
                        font.pixelSize: 13
                        color: model.isPartial ? "#A0A0A0" : "#E0E0E0"
                        font.italic: model.isPartial
                        lineHeight: 1.4
                    }
                }

                // Séparateur bas
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: "#2A2A2A"
                }
            }
        }

        // ── Partial transcript en cours ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.partialTranscript.length > 0 ? partialText.height + 16 : 0
            color: "#252526"
            visible: root.partialTranscript.length > 0
            clip: true

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
            }

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: "#3C3C3C"
            }

            Text {
                id: partialText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "▸ " + root.partialTranscript
                wrapMode: Text.WordWrap
                font.family: "Cascadia Code, Fira Code, Consolas"
                font.pixelSize: 13
                font.italic: true
                color: "#A0A0A0"
            }
        }

        // ── Champ d'entrée manuelle ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "#252526"

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
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 3
                    color: "#3C3C3C"
                    border.color: manualInput.activeFocus ? "#007ACC" : "transparent"

                    TextInput {
                        id: manualInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: "Cascadia Code, Fira Code, Consolas"
                        font.pixelSize: 13
                        color: "#E0E0E0"
                        clip: true

                        property string placeholderText: "Poser une question à EXO..."
                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            font: manualInput.font
                            color: "#5A5A5A"
                            text: manualInput.placeholderText
                            visible: !manualInput.text && !manualInput.activeFocus
                        }

                        Keys.onReturnPressed: sendManualInput()
                        Keys.onEnterPressed: sendManualInput()

                        function sendManualInput() {
                            var txt = manualInput.text.trim()
                            if (txt.length === 0) return
                            root.addMessage(txt, true, false)
                            if (typeof assistantManager !== 'undefined') {
                                assistantManager.sendManualQuery(txt)
                            }
                            manualInput.text = ""
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.fillHeight: true
                    radius: 3
                    color: sendArea.containsMouse ? "#094771" : "#007ACC"

                    Text {
                        anchors.centerIn: parent
                        text: "▶"
                        font.pixelSize: 14
                        color: "#FFFFFF"
                    }

                    MouseArea {
                        id: sendArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: manualInput.sendManualInput()
                    }
                }
            }
        }
    }
}
