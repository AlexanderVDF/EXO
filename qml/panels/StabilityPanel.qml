import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

// ═══════════════════════════════════════════════════════
//  StabilityPanel — Panneau de tests de stabilité EXO
//
//  Affiche l'état de chaque microservice, la latence,
//  les erreurs, et un indicateur global stable/instable.
//  Pilote TestController.startAutoTestLoop().
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: Theme.bgPrimary

    // TestController doit être exposé comme context property
    // depuis main.cpp : testController

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ──
        ExoPanelHeader {
            title: "STABILITY TESTS"
        }

        // ── Global status bar ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: Theme.bgSecondary

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.marginH
                anchors.rightMargin: Theme.marginH
                spacing: Theme.spacing16

                // Overall indicator
                Rectangle {
                    width: 12; height: 12
                    radius: 6
                    color: {
                        if (typeof testController === 'undefined') return Theme.textMuted
                        var s = testController.overallStatus
                        if (s === "stable") return Theme.success
                        if (s === "unstable") return Theme.error
                        return Theme.textMuted
                    }

                    SequentialAnimation on opacity {
                        running: typeof testController !== 'undefined' && testController.running
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }
                }

                Text {
                    text: {
                        if (typeof testController === 'undefined') return "Non initialisé"
                        var s = testController.overallStatus
                        if (s === "stable") return "EXO STABLE ✔"
                        if (s === "unstable") return "INSTABLE ✘"
                        return "EN ATTENTE"
                    }
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontBody
                    font.weight: Font.Bold
                    color: {
                        if (typeof testController === 'undefined') return Theme.textMuted
                        var s = testController.overallStatus
                        if (s === "stable") return Theme.success
                        if (s === "unstable") return Theme.error
                        return Theme.textSecondary
                    }
                }

                Text {
                    text: typeof testController !== 'undefined'
                          ? "Loop #" + testController.loopCount
                          : ""
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSmall
                    color: Theme.textSecondary
                }

                Item { Layout.fillWidth: true }

                // Start button
                Rectangle {
                    width: startLabel.implicitWidth + Theme.spacing16 * 2
                    height: Theme.buttonHeight
                    radius: Theme.radiusSmall
                    color: {
                        if (typeof testController !== 'undefined' && testController.running)
                            return Theme.bgActive
                        return startMa.containsPress ? Theme.accentDark : Theme.accent
                    }

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        id: startLabel
                        anchors.centerIn: parent
                        text: typeof testController !== 'undefined' && testController.running
                              ? "Arrêter" : "Lancer tests"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSmall
                        font.weight: Font.Medium
                        color: "#FFFFFF"
                    }

                    MouseArea {
                        id: startMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof testController === 'undefined') return
                            if (testController.running)
                                testController.stopAutoTestLoop()
                            else
                                testController.startAutoTestLoop()
                        }
                    }
                }
            }
        }

        // ── Separator ──
        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

        // ── Service list ──
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: servicesCol.height + Theme.spacing32
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: servicesCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.marginH
                anchors.rightMargin: Theme.marginH
                y: Theme.spacing16
                spacing: Theme.spacing8

                // ── Section: Services ──
                Text {
                    text: "SERVICES"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontCaption
                    font.weight: Font.Bold
                    color: Theme.textSecondary
                    font.letterSpacing: 1.5
                }

                Repeater {
                    model: typeof testController !== 'undefined'
                           ? testController.serviceResults : []

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 44
                        radius: Theme.radiusSmall
                        color: delegateMa.containsMouse ? Theme.bgHover : Theme.bgSecondary

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        MouseArea {
                            id: delegateMa
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacing12
                            anchors.rightMargin: Theme.spacing12
                            spacing: Theme.spacing12

                            // Status dot
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: {
                                    var s = modelData.status
                                    if (s === "ok")       return Theme.success
                                    if (s === "timeout")  return Theme.warning
                                    if (s === "down")     return Theme.error
                                    if (s === "flapping") return Theme.warning
                                    return Theme.textMuted
                                }
                            }

                            // Name
                            Text {
                                Layout.preferredWidth: 100
                                text: modelData.name
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSmall
                                color: Theme.textPrimary
                            }

                            // Status badge
                            Rectangle {
                                width: statusText.implicitWidth + Theme.spacing8 * 2
                                height: 22
                                radius: Theme.radiusSmall
                                color: {
                                    var s = modelData.status
                                    if (s === "ok")       return Theme.successDim
                                    if (s === "timeout")  return Theme.warningDim
                                    if (s === "down")     return Theme.errorDim
                                    if (s === "flapping") return Theme.warningDim
                                    return Theme.bgActive
                                }

                                Text {
                                    id: statusText
                                    anchors.centerIn: parent
                                    text: {
                                        var s = modelData.status
                                        if (s === "ok")       return "OK"
                                        if (s === "timeout")  return "TIMEOUT"
                                        if (s === "down")     return "DOWN"
                                        if (s === "flapping") return "FLAPPING"
                                        return "…"
                                    }
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontMicro
                                    font.weight: Font.Bold
                                    color: {
                                        var s = modelData.status
                                        if (s === "ok")       return Theme.success
                                        if (s === "timeout")  return Theme.warning
                                        if (s === "down")     return Theme.error
                                        if (s === "flapping") return Theme.warning
                                        return Theme.textMuted
                                    }
                                }
                            }

                            // Latency
                            Text {
                                Layout.preferredWidth: 80
                                text: modelData.latency >= 0
                                      ? modelData.latency.toFixed(0) + " ms"
                                      : "—"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSmall
                                color: {
                                    if (modelData.latency < 0) return Theme.textMuted
                                    if (modelData.latency > 2000) return Theme.warning
                                    return Theme.textSecondary
                                }
                                horizontalAlignment: Text.AlignRight
                            }

                            // Error text
                            Text {
                                Layout.fillWidth: true
                                text: modelData.error || ""
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontMicro
                                color: Theme.error
                                elide: Text.ElideRight
                                visible: !!modelData.error
                            }

                            Item { Layout.fillWidth: true; visible: !modelData.error }
                        }
                    }
                }

                // ── Separator ──
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.border
                    Layout.topMargin: Theme.spacing12
                    Layout.bottomMargin: Theme.spacing8
                }

                // ── Section: Error log ──
                Text {
                    text: "ERREURS"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontCaption
                    font.weight: Font.Bold
                    color: Theme.textSecondary
                    font.letterSpacing: 1.5
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(80, errorList.contentHeight + Theme.spacing16)
                    radius: Theme.radiusSmall
                    color: Theme.bgSecondary
                    clip: true

                    ListView {
                        id: errorList
                        anchors.fill: parent
                        anchors.margins: Theme.spacing8
                        model: typeof testController !== 'undefined'
                               ? testController.errorLog : []
                        spacing: 2

                        delegate: Text {
                            width: errorList.width
                            text: modelData
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontMicro
                            color: Theme.error
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: errorList.count === 0
                            text: "Aucune erreur"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSmall
                            color: Theme.textMuted
                        }
                    }
                }

                Item { Layout.preferredHeight: Theme.spacing20 }
            }
        }
    }
}
