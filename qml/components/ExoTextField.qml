import QtQuick
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  ExoTextField — Champ de texte moderne
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property bool readOnly: false
    property alias inputItem: input

    signal accepted()

    implicitHeight: Theme.inputHeight
    radius: Theme.radiusSmall
    color: Theme.bgInput
    border.width: 1
    border.color: input.activeFocus ? Theme.borderFocus
               : fieldMouse.containsMouse ? Theme.borderHover
               : "transparent"

    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: Theme.spacing8
        anchors.rightMargin: Theme.spacing8
        verticalAlignment: TextInput.AlignVCenter
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSmall
        color: Theme.textPrimary
        readOnly: root.readOnly
        clip: true
        selectByMouse: true
        selectionColor: Theme.accentActive
        selectedTextColor: "#FFFFFF"

        onAccepted: root.accepted()

        // Placeholder
        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            font: input.font
            color: Theme.textMuted
            text: root.placeholder
            visible: !input.text && !input.activeFocus
        }
    }

    MouseArea {
        id: fieldMouse
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        onPressed: function(mouse) { mouse.accepted = false }
    }
}
