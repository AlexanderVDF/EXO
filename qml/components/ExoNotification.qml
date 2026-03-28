import QtQuick
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  ExoNotification — Toast notification slide-in
// ═══════════════════════════════════════════════════════

Item {
    id: root

    property string message: ""
    property string level: "info"   // info, success, warning, error
    property int duration: 3000

    signal dismissed()

    width: parent ? parent.width : 400
    height: 44

    Rectangle {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - Theme.spacing32, toastRow.implicitWidth + Theme.spacing24 * 2)
        height: parent.height
        radius: Theme.radiusMedium
        color: Theme.bgElevated
        border.width: 1
        border.color: {
            switch (root.level) {
            case "success": return Theme.success
            case "warning": return Theme.warning
            case "error":   return Theme.error
            default:        return Theme.accent
            }
        }

        y: -height
        opacity: 0

        RowLayout {
            id: toastRow
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing16
            anchors.rightMargin: Theme.spacing16
            spacing: Theme.spacing8

            Rectangle {
                width: 6; height: 6; radius: 3
                color: toast.border.color
            }

            Text {
                text: root.message
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                color: Theme.textPrimary
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        SequentialAnimation {
            id: showAnim
            running: false

            ParallelAnimation {
                NumberAnimation { target: toast; property: "y"; to: 0; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { target: toast; property: "opacity"; to: 1; duration: 200 }
            }

            PauseAnimation { duration: root.duration }

            ParallelAnimation {
                NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 300; easing.type: Easing.InQuad }
            }

            ScriptAction { script: root.dismissed() }
        }
    }

    function show() { showAnim.start() }
    Component.onCompleted: show()
}
