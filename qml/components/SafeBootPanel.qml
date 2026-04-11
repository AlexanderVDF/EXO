import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  SafeBootPanel — Indicateur Safe Boot EXO v30.1
//
//  Affiché dans le splash screen quand le mode Safe Boot
//  est activé (services non critiques en échec/lents).
// ═══════════════════════════════════════════════════════

Rectangle {
    id: panel

    property bool safeBootActive: false
    property bool criticalReady: false
    property int criticalReadyCount: 0
    property int criticalTotal: 0
    property int lazyReadyCount: 0
    property int lazyTotal: 0
    property int failedCount: 0
    property var failedServices: []
    property var lazyServices: []

    visible: safeBootActive
    color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.08)
    border.color: Theme.warningDim
    border.width: 1
    radius: 8
    implicitHeight: contentCol.implicitHeight + Theme.spacing16 * 2

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.margins: Theme.spacing16
        spacing: Theme.spacing8

        // En-tête Safe Boot
        RowLayout {
            spacing: Theme.spacing8

            Text {
                text: "⚠"
                font.pixelSize: 18
                color: Theme.warning
            }

            Text {
                text: "Mode Safe Boot"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontBody
                font.weight: Font.Bold
                color: Theme.warning
            }

            Item { Layout.fillWidth: true }

            Text {
                text: criticalReady ? "✓ Critiques OK" : "⏳ Attente critiques…"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSmall
                color: criticalReady ? Theme.success : Theme.textSecondary
            }
        }

        // Barre critique
        RowLayout {
            spacing: Theme.spacing8
            Layout.fillWidth: true

            Text {
                text: "Critiques"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSmall
                color: Theme.textSecondary
                Layout.preferredWidth: 70
            }

            ProgressBar {
                id: critBar
                Layout.fillWidth: true
                from: 0
                to: panel.criticalTotal > 0 ? panel.criticalTotal : 1
                value: panel.criticalReadyCount

                background: Rectangle {
                    implicitHeight: 4
                    radius: 2
                    color: Theme.splashPanel
                }
                contentItem: Rectangle {
                    width: critBar.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: Theme.success
                    Behavior on width { NumberAnimation { duration: 200 } }
                }
            }

            Text {
                text: panel.criticalReadyCount + "/" + panel.criticalTotal
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSmall
                color: Theme.textSecondary
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
            }
        }

        // Barre lazy
        RowLayout {
            spacing: Theme.spacing8
            Layout.fillWidth: true

            Text {
                text: "Lazy"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSmall
                color: Theme.textSecondary
                Layout.preferredWidth: 70
            }

            ProgressBar {
                id: lazyBar
                Layout.fillWidth: true
                from: 0
                to: panel.lazyTotal > 0 ? panel.lazyTotal : 1
                value: panel.lazyReadyCount

                background: Rectangle {
                    implicitHeight: 4
                    radius: 2
                    color: Theme.splashPanel
                }
                contentItem: Rectangle {
                    width: lazyBar.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 200 } }
                }
            }

            Text {
                text: panel.lazyReadyCount + "/" + panel.lazyTotal
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSmall
                color: Theme.textSecondary
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
            }
        }

        // Services en échec
        Column {
            visible: panel.failedCount > 0
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: panel.failedCount + " service(s) en échec :"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSmall
                color: Theme.error
            }

            Repeater {
                model: panel.failedServices
                delegate: Text {
                    text: "  ✗ " + modelData.name + " — " + modelData.state
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSmall - 1
                    color: modelData.critical ? Theme.error : Theme.warningDim
                }
            }
        }
    }
}
