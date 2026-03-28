import QtQuick
import "../theme"

// ═══════════════════════════════════════════════════════
//  ExoWaveform — Visualiseur d'onde audio style EXO
//  Barres animées réactives au niveau audio
// ═══════════════════════════════════════════════════════

Item {
    id: root

    property real level: 0.0          // 0.0–1.0 (niveau audio)
    property string state: "Idle"     // Idle, Listening, Speaking
    property int barCount: 5
    property color barColor: Theme.stateColor(root.state)

    implicitWidth: barCount * 6 + (barCount - 1) * 3
    implicitHeight: 32

    Behavior on barColor { ColorAnimation { duration: Theme.animNormal } }

    Row {
        anchors.centerIn: parent
        spacing: 3

        Repeater {
            model: root.barCount

            Rectangle {
                required property int index

                width: 4
                radius: 2
                anchors.verticalCenter: parent.verticalCenter
                color: root.barColor

                // Hauteur dynamique basée sur le level + variation par barre
                readonly property real barFactor: {
                    // Pattern : barres centrales plus hautes
                    var center = (root.barCount - 1) / 2
                    var dist = Math.abs(index - center) / center
                    return 1.0 - dist * 0.4
                }

                height: {
                    if (root.state === "Idle") return 4
                    var base = root.implicitHeight * 0.2
                    var dynamic = root.implicitHeight * 0.8 * root.level * barFactor
                    return Math.max(4, base + dynamic)
                }

                Behavior on height {
                    NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                }
                Behavior on color {
                    ColorAnimation { duration: Theme.animNormal }
                }

                // Animation idle subtile
                SequentialAnimation on height {
                    running: root.state !== "Idle" && root.level < 0.05
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 4 + 8 * barFactor
                        duration: 400 + index * 80
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 4
                        duration: 400 + index * 80
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }
}
