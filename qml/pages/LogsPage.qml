import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

Rectangle {
    id: root
    color: Theme.bgPrimary

    property bool autoScroll: true
    property string _copyFeedback: ""

    function appendLog(entry) {
        // Fix audit T4: pré-calcul du niveau de log pour éviter indexOf dans le delegate
        var lvl = "info"
        if (entry.indexOf("CRIT") !== -1 || entry.indexOf("FATAL") !== -1) lvl = "error"
        else if (entry.indexOf("WARN") !== -1) lvl = "warning"
        else if (entry.indexOf("[VOICE]") !== -1) lvl = "voice"
        else if (entry.indexOf("[CLAUDE]") !== -1) lvl = "thinking"
        else if (entry.indexOf("[TTS]") !== -1 || entry.indexOf("[STT]") !== -1) lvl = "success"
        else if (entry.indexOf("[WEATHER]") !== -1) lvl = "weather"

        logModel.append({ text: entry, level: lvl })
        // Fix audit T3: while au lieu de if pour gérer les bursts
        while (logModel.count > 500)
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
            var recent = logManager.getRecentLogs()
            for (var i = 0; i < recent.length; i++)
                root.appendLog(recent[i])
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
            Layout.preferredHeight: Theme.headerHeight
            color: Theme.bgSecondary

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacing16
                anchors.rightMargin: Theme.spacing16

                Text {
                    text: "LOGS"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontMicro
                    font.bold: true
                    color: Theme.textAccent
                    font.letterSpacing: 1.5
                }

                Item { Layout.fillWidth: true }

                // Auto-scroll toggle
                Text {
                    text: root.autoScroll ? "Auto ●" : "Auto ○"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontMicro
                    color: root.autoScroll ? Theme.success : Theme.textMuted

                    Behavior on color { ColorAnimation { duration: Theme.animNormal } }

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
                    color: Theme.border
                }

                // Clear button
                Text {
                    text: "Effacer"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontMicro
                    color: clearArea.containsMouse ? Theme.error : Theme.textMuted

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

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
                    color: Theme.border
                }

                // Copy all button
                Text {
                    text: root._copyFeedback !== "" ? root._copyFeedback : "Copier tout"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontMicro
                    color: root._copyFeedback !== "" ? Theme.success
                         : copyAllArea.containsMouse ? Theme.textAccent : Theme.textMuted

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

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
                color: Theme.border
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
                    color: Theme.textMuted
                    opacity: 0.5
                }
            }

            delegate: Rectangle {
                width: logList.width
                height: logText.implicitHeight + 4
                color: index % 2 === 0 ? "transparent" : Qt.darker(Theme.bgPrimary, 1.15)

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
                    anchors.leftMargin: Theme.spacing12
                    anchors.rightMargin: Theme.spacing12
                    anchors.verticalCenter: parent.verticalCenter
                    text: model.text
                    wrapMode: Text.NoWrap
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontMicro
                    color: {
                        // Fix audit T4: lookup par niveau pré-calculé
                        switch (model.level) {
                        case "error":    return Theme.error
                        case "warning":  return Theme.warning
                        case "voice":    return Theme.info
                        case "thinking": return Theme.stateThinking
                        case "success":  return Theme.success
                        case "weather":  return "#CE9178"
                        default:         return Theme.textSecondary
                        }
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
            color: Theme.bgSecondary
            border.color: Theme.border
            radius: Theme.radiusSmall
        }

        MenuItem {
            text: "Copier cette ligne"
            onTriggered: {
                clipHelper.text = lineContextMenu.logLine
            }
            background: Rectangle {
                color: parent.highlighted ? Theme.accentActive : "transparent"
            }
            contentItem: Text {
                text: parent.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontMicro
                color: Theme.textPrimary
            }
        }

        MenuItem {
            text: "Copier tous les logs"
            onTriggered: root.copyAllLogs()
            background: Rectangle {
                color: parent.highlighted ? Theme.accentActive : "transparent"
            }
            contentItem: Text {
                text: parent.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontMicro
                color: Theme.textPrimary
            }
        }
    }
}
