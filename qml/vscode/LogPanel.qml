import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#1E1E1E"

    property bool autoScroll: true
    property string _copyFeedback: ""

    function appendLog(entry) {
        logModel.append({ text: entry })
        if (logModel.count > 500)
            logModel.remove(0)
        if (autoScroll)
            logList.positionViewAtEnd()
    }

    function copyAllLogs() {
        var lines = []
        for (var i = 0; i < logModel.count; i++)
            lines.push(logModel.get(i).text)
        if (typeof logManager !== 'undefined' && logManager.copyToClipboard)
            logManager.copyToClipboard(lines.join("\n"))
        else
            clipHelper.text = lines.join("\n")
        _copyFeedback = "Copié !"
        feedbackTimer.restart()
    }

    // Hidden TextEdit used as clipboard fallback
    TextEdit {
        id: clipHelper
        visible: false
        onTextChanged: {
            if (text.length > 0) {
                selectAll()
                copy()
                text = ""
            }
        }
    }

    Timer {
        id: feedbackTimer
        interval: 1500
        onTriggered: root._copyFeedback = ""
    }

    Component.onCompleted: {
        if (typeof logManager !== 'undefined') {
            // Load existing logs
            var recent = logManager.getRecentLogs()
            for (var i = 0; i < recent.length; i++)
                logModel.append({ text: recent[i] })
            if (autoScroll)
                logList.positionViewAtEnd()
        }
    }

    Connections {
        target: typeof logManager !== 'undefined' ? logManager : null
        function onNewLogEntry(entry) {
            root.appendLog(entry)
        }
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
                    text: "LOGS"
                    font.family: "Cascadia Code, Fira Code, Consolas"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#007ACC"
                    font.letterSpacing: 1.5
                }

                Item { Layout.fillWidth: true }

                // Auto-scroll toggle
                Text {
                    text: root.autoScroll ? "Auto ●" : "Auto ○"
                    font.family: "Cascadia Code, Fira Code, Consolas"
                    font.pixelSize: 11
                    color: root.autoScroll ? "#4EC9B0" : "#5A5A5A"

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.autoScroll = !root.autoScroll
                    }
                }

                // Séparateur
                Rectangle {
                    width: 1
                    height: 14
                    color: "#3C3C3C"
                }

                // Clear button
                Text {
                    text: "Effacer"
                    font.family: "Cascadia Code, Fira Code, Consolas"
                    font.pixelSize: 11
                    color: clearArea.containsMouse ? "#F44747" : "#5A5A5A"

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            logModel.clear()
                            if (typeof logManager !== 'undefined')
                                logManager.clearLogs()
                        }
                    }
                }

                // Séparateur
                Rectangle {
                    width: 1
                    height: 14
                    color: "#3C3C3C"
                }

                // Copy all button
                Text {
                    text: root._copyFeedback !== "" ? root._copyFeedback : "Copier tout"
                    font.family: "Cascadia Code, Fira Code, Consolas"
                    font.pixelSize: 11
                    color: root._copyFeedback !== "" ? "#4EC9B0"
                         : copyAllArea.containsMouse ? "#007ACC" : "#5A5A5A"

                    MouseArea {
                        id: copyAllArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyAllLogs()
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

        // ── Log list ──
        ListView {
            id: logList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 0
            model: ListModel { id: logModel }

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
                width: logList.width
                height: logText.implicitHeight + 4
                color: index % 2 === 0 ? "transparent" : "#1A1A1A"

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            lineContextMenu.logLine = model.text
                            lineContextMenu.popup()
                        }
                    }
                }

                Text {
                    id: logText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: model.text
                    wrapMode: Text.NoWrap
                    font.family: "Cascadia Code, Fira Code, Consolas"
                    font.pixelSize: 11
                    color: {
                        if (model.text.indexOf("WARN") !== -1) return "#DCDCAA"
                        if (model.text.indexOf("CRIT") !== -1 || model.text.indexOf("FATAL") !== -1) return "#F44747"
                        if (model.text.indexOf("[VOICE]") !== -1) return "#9CDCFE"
                        if (model.text.indexOf("[CLAUDE]") !== -1) return "#C586C0"
                        if (model.text.indexOf("[TTS]") !== -1) return "#4EC9B0"
                        if (model.text.indexOf("[STT]") !== -1) return "#4EC9B0"
                        if (model.text.indexOf("[WEATHER]") !== -1) return "#CE9178"
                        return "#A0A0A0"
                    }
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ── Context menu for individual log lines ──
    Menu {
        id: lineContextMenu
        property string logLine: ""

        background: Rectangle {
            implicitWidth: 180
            color: "#252526"
            border.color: "#3C3C3C"
            radius: 4
        }

        MenuItem {
            text: "Copier cette ligne"
            onTriggered: {
                clipHelper.text = lineContextMenu.logLine
            }
            background: Rectangle {
                color: parent.highlighted ? "#094771" : "transparent"
            }
            contentItem: Text {
                text: parent.text
                font.family: "Cascadia Code, Fira Code, Consolas"
                font.pixelSize: 11
                color: "#CCCCCC"
            }
        }

        MenuItem {
            text: "Copier tous les logs"
            onTriggered: root.copyAllLogs()
            background: Rectangle {
                color: parent.highlighted ? "#094771" : "transparent"
            }
            contentItem: Text {
                text: parent.text
                font.family: "Cascadia Code, Fira Code, Consolas"
                font.pixelSize: 11
                color: "#CCCCCC"
            }
        }
    }
}
