import QtQuick
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  ExoTab — Barre à onglets style VS Code
// ═══════════════════════════════════════════════════════

Item {
    id: root

    property var model: []             // ["Tab1", "Tab2", ...]
    property int currentIndex: 0

    signal tabClicked(int index)

    implicitHeight: Theme.tabHeight
    implicitWidth: tabRow.implicitWidth

    RowLayout {
        id: tabRow
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: root.model

            Rectangle {
                required property int index
                required property string modelData

                Layout.fillHeight: true
                Layout.preferredWidth: tabLabel.implicitWidth + Theme.spacing24
                color: index === root.currentIndex
                    ? Theme.bgPrimary
                    : tabMouse.containsMouse ? Theme.bgHover : Theme.bgSecondary

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                // Indicateur actif (ligne en haut)
                Rectangle {
                    width: parent.width; height: 2
                    anchors.top: parent.top
                    color: Theme.accent
                    visible: index === root.currentIndex
                }

                Text {
                    id: tabLabel
                    anchors.centerIn: parent
                    text: modelData
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    font.weight: index === root.currentIndex ? Font.Medium : Font.Normal
                    color: index === root.currentIndex ? Theme.textPrimary : Theme.textSecondary
                }

                // Séparateur droit
                Rectangle {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 1; color: Theme.border
                    visible: index < root.model.length - 1
                }

                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.currentIndex = index; root.tabClicked(index) }
                }
            }
        }

        // Remplissage reste
        Item { Layout.fillWidth: true; Layout.fillHeight: true }
    }

    // Ligne basse
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width; height: 1
        color: Theme.border
    }
}
