import QtQuick
import QtQuick.Layouts
import "../theme"
import "../components"

// ═══════════════════════════════════════════════════════
//  BottomBar — Barre inférieure EXO Design System
// ═══════════════════════════════════════════════════════

Rectangle {
    id: bottomBar
    color: Theme.bgSecondary
    implicitHeight: Theme.bottomBarHeight

    property real audioLevel: 0.0

    // Bordure supérieure
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Theme.border
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacing12
        anchors.rightMargin: Theme.spacing12
        spacing: Theme.spacing12

        // ── Visualiseur audio ──
        ExoVisualizer {
            Layout.preferredWidth: 120
            Layout.fillHeight: true
            audioLevel: bottomBar.audioLevel
            active: bottomBar.audioLevel > 0.01
            lineColor: Theme.accent
            lineWidth: 1.0
        }

        // Séparateur
        Rectangle {
            Layout.fillHeight: true
            Layout.topMargin: Theme.spacing6
            Layout.bottomMargin: Theme.spacing6
            width: 1
            color: Theme.border
        }

        // ── Météo ──
        Text {
            id: weatherText
            text: typeof weatherManager !== 'undefined' && weatherManager.summary
                  ? weatherManager.summary : ""
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontMicro
            color: Theme.textSecondary
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // Séparateur
        Rectangle {
            Layout.fillHeight: true
            Layout.topMargin: Theme.spacing6
            Layout.bottomMargin: Theme.spacing6
            width: 1
            color: Theme.border
        }

        // ── Health dots ──
        Row {
            spacing: Theme.spacing6

            Repeater {
                model: [
                    { label: "STT", key: "stt" },
                    { label: "TTS", key: "tts" },
                    { label: "VAD", key: "vad" },
                    { label: "WW",  key: "wakeword" },
                    { label: "MEM", key: "memory" },
                    { label: "NLU", key: "nlu" }
                ]

                Row {
                    spacing: 3

                    Rectangle {
                        width: Theme.dotSize
                        height: Theme.dotSize
                        radius: Theme.dotSize / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: {
                            if (typeof healthCheck === 'undefined') return Theme.textMuted
                            var s = healthCheck.serviceStatus(modelData.key)
                            return Theme.healthColor(s)
                        }

                        Behavior on color { ColorAnimation { duration: Theme.animNormal } }
                    }

                    Text {
                        text: modelData.label
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        color: Theme.textMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Séparateur
        Rectangle {
            Layout.fillHeight: true
            Layout.topMargin: Theme.spacing6
            Layout.bottomMargin: Theme.spacing6
            width: 1
            color: Theme.border
        }

        // ── Horloge ──
        Text {
            id: clockText
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontMicro
            color: Theme.textSecondary

            Timer {
                interval: 30000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: clockText.text = Qt.formatTime(new Date(), "HH:mm")
            }
        }
    }
}
