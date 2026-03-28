import QtQuick
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  ExoStatusPill — Indicateur d'état (pill / chip)
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root

    property string text: ""
    property string level: "info"   // success, warning, error, info, idle

    implicitWidth: pillRow.implicitWidth + Theme.spacing16
    implicitHeight: 24
    radius: height / 2

    color: {
        switch (root.level) {
        case "success": return Theme.successDim
        case "warning": return Theme.warningDim
        case "error":   return Theme.errorDim
        case "idle":    return Theme.bgInput
        default:        return Theme.infoDim
        }
    }

    border.width: 1
    border.color: {
        switch (root.level) {
        case "success": return Theme.success
        case "warning": return Theme.warning
        case "error":   return Theme.error
        case "idle":    return Theme.border
        default:        return Theme.info
        }
    }
    opacity: 0.9

    RowLayout {
        id: pillRow
        anchors.centerIn: parent
        spacing: Theme.spacing4

        // Dot indicateur
        Rectangle {
            width: 6; height: 6; radius: 3
            color: root.border.color
        }

        Text {
            text: root.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTiny
            font.weight: Font.Medium
            color: root.border.color
        }
    }
}
