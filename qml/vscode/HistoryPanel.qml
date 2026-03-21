import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#1E1E1E"

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
                    text: "HISTORIQUE"
                    font.family: "Cascadia Code, Fira Code, Consolas"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#007ACC"
                    font.letterSpacing: 1.5
                }

                Item { Layout.fillWidth: true }

                // Bouton clear
                Text {
                    text: "Effacer"
                    font.family: "Cascadia Code, Fira Code, Consolas"
                    font.pixelSize: 11
                    color: clearMouseArea.containsMouse ? "#F44747" : "#5A5A5A"

                    MouseArea {
                        id: clearMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof memoryManager !== 'undefined') {
                                memoryManager.clearConversationHistory()
                                historyModel.clear()
                            }
                        }
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

        // ── Liste des conversations récentes ──
        ListView {
            id: historyList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 0
            model: ListModel { id: historyModel }

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
                width: historyList.width
                height: histCol.height + 16
                color: histMouseArea.containsMouse ? "#2A2D2E" : "transparent"

                Rectangle {
                    anchors.left: parent.left
                    width: 3
                    height: parent.height
                    color: "#007ACC"
                    opacity: 0.5
                }

                Column {
                    id: histCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        text: model.userMessage
                        width: parent.width
                        elide: Text.ElideRight
                        font.family: "Cascadia Code, Fira Code, Consolas"
                        font.pixelSize: 12
                        color: "#007ACC"
                    }

                    Text {
                        text: model.assistantResponse
                        width: parent.width
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                        font.family: "Cascadia Code, Fira Code, Consolas"
                        font.pixelSize: 12
                        color: "#A0A0A0"
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: "#2A2A2A"
                }

                MouseArea {
                    id: histMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }

            // Charger l'historique au démarrage
            Component.onCompleted: loadHistory()
        }
    }

    function loadHistory() {
        historyModel.clear()
        if (typeof memoryManager !== 'undefined') {
            var conversations = memoryManager.getRecentConversations(50)
            for (var i = 0; i < conversations.length; i += 2) {
                if (i + 1 < conversations.length) {
                    historyModel.append({
                        "userMessage": conversations[i],
                        "assistantResponse": conversations[i + 1]
                    })
                }
            }
        }
    }
}
