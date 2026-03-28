import QtQuick
import "../theme"

// ═══════════════════════════════════════════════════════
//  ExoSheet — Panneau coulissant latéral (overlay)
// ═══════════════════════════════════════════════════════

Item {
    id: root

    property string title: ""
    property alias contentItem: contentLoader.sourceComponent
    property string side: "right"  // "left" ou "right"

    signal closed()

    anchors.fill: parent
    visible: false
    z: 40

    // Overlay sombre
    Rectangle {
        anchors.fill: parent
        color: "#60000000"
        opacity: root.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // Panneau
    Rectangle {
        id: panel
        width: Theme.sheetWidth
        height: parent.height
        color: Theme.bgSecondary
        border.width: 1
        border.color: Theme.border

        x: root.side === "right"
           ? (root.visible ? parent.width - width : parent.width)
           : (root.visible ? 0 : -width)

        Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }

        // Ombre latérale
        Rectangle {
            width: 6; height: parent.height
            x: root.side === "right" ? -6 : parent.width
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: root.side === "right" ? 0.0 : 1.0; color: "transparent" }
                GradientStop { position: root.side === "right" ? 1.0 : 0.0; color: "#40000000" }
            }
        }

        Column {
            anchors.fill: parent
            spacing: 0

            // Header
            Rectangle {
                width: parent.width
                height: Theme.headerHeight
                color: Theme.bgElevated

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: Theme.marginH }
                    text: root.title
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontH3
                    font.weight: Font.SemiBold
                    color: Theme.textPrimary
                }

                Rectangle {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: Theme.spacing12 }
                    width: 28; height: 28; radius: Theme.radiusSmall
                    color: closeMouse.containsMouse ? Theme.bgHover : "transparent"

                    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 14; color: Theme.textSecondary }
                    MouseArea {
                        id: closeMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor; onClicked: root.close()
                    }
                }

                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
            }

            // Contenu
            Loader {
                id: contentLoader
                width: parent.width
                height: parent.height - Theme.headerHeight
            }
        }
    }

    function open()  { visible = true }
    function close() { visible = false; closed() }
}
