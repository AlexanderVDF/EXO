import QtQuick
import "../theme"

// ═══════════════════════════════════════════════════════
//  ExoBadge — Badge numérique / notification
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root

    property int count: 0
    property string level: "error"   // accent, success, warning, error
    property bool dot: false          // true = pastille sans texte

    visible: root.dot || root.count > 0
    width: root.dot ? Theme.dotSize : Math.max(Theme.badgeSize, badgeText.implicitWidth + Theme.spacing8)
    height: root.dot ? Theme.dotSize : Theme.badgeSize
    radius: height / 2

    color: {
        switch (root.level) {
        case "success": return Theme.success
        case "warning": return Theme.warning
        case "accent":  return Theme.accent
        default:        return Theme.error
        }
    }

    Text {
        id: badgeText
        visible: !root.dot
        anchors.centerIn: parent
        text: root.count > 99 ? "99+" : root.count.toString()
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontTiny
        font.weight: Font.Bold
        color: "#FFFFFF"
    }

    // Animation d'apparition
    scale: 0
    Component.onCompleted: scaleAnim.start()
    NumberAnimation {
        id: scaleAnim
        target: root; property: "scale"
        from: 0; to: 1; duration: Theme.animSlow
        easing.type: Easing.OutBack
    }
}
