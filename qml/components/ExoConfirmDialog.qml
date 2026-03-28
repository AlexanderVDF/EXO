import QtQuick
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  ExoConfirmDialog — Dialogue de confirmation Fluent
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root

    property string title: "Confirmation"
    property string message: ""
    property string confirmText: "Confirmer"
    property string cancelText: "Annuler"
    property bool destructive: false

    signal accepted()
    signal rejected()

    anchors.fill: parent
    color: "#80000000"
    visible: false
    z: 50

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.8, 420)
        implicitHeight: col.height + Theme.paddingSection * 2
        radius: Theme.radiusLarge
        color: Theme.bgElevated
        border.width: 1
        border.color: Theme.border

        // Ombre
        Rectangle {
            anchors.fill: parent; anchors.margins: -2; z: -1
            radius: parent.radius + 2; color: "#000000"; opacity: 0.3
        }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.paddingSection }
            spacing: Theme.spacing16

            Text {
                text: root.title
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontH3
                font.weight: Font.SemiBold
                color: Theme.textPrimary
                Layout.fillWidth: true
            }

            Text {
                text: root.message
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                color: Theme.textSecondary
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacing8
                spacing: Theme.spacing12

                Item { Layout.fillWidth: true }

                // Cancel
                Rectangle {
                    implicitWidth: cancelLabel.implicitWidth + Theme.paddingBtn * 2
                    implicitHeight: Theme.buttonHeight
                    radius: Theme.radiusMedium
                    color: cancelMouse.pressed ? Theme.bgActive
                         : cancelMouse.containsMouse ? Theme.bgHover : Theme.bgElevated
                    border.width: 1; border.color: Theme.border

                    Text {
                        id: cancelLabel; anchors.centerIn: parent
                        text: root.cancelText
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSmall
                        color: Theme.textPrimary
                    }
                    MouseArea {
                        id: cancelMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.rejected(); root.close() }
                    }
                }

                // Confirm
                Rectangle {
                    implicitWidth: confirmLabel.implicitWidth + Theme.paddingBtn * 2
                    implicitHeight: Theme.buttonHeight
                    radius: Theme.radiusMedium
                    color: {
                        if (root.destructive)
                            return confirmMouse.pressed ? "#8B1A1A"
                                 : confirmMouse.containsMouse ? "#A02020" : Theme.error
                        return confirmMouse.pressed ? Theme.accentDark
                             : confirmMouse.containsMouse ? Theme.accentHover : Theme.accent
                    }

                    Text {
                        id: confirmLabel; anchors.centerIn: parent
                        text: root.confirmText
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSmall
                        font.weight: Font.Medium; color: "#FFFFFF"
                    }
                    MouseArea {
                        id: confirmMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.accepted(); root.close() }
                    }
                }
            }
        }

        scale: 0.95; opacity: 0
        states: State { name: "visible"; when: root.visible
            PropertyChanges { target: panel; scale: 1.0; opacity: 1.0 }
        }
        transitions: Transition {
            NumberAnimation { properties: "scale,opacity"; duration: Theme.animNormal; easing.type: Easing.OutCubic }
        }
    }

    function open()  { visible = true }
    function close() { visible = false }
}
