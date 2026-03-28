import QtQuick
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  ExoSearchField — Champ de recherche avec icône loupe
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: "Rechercher…"
    property bool clearable: true

    signal accepted()
    signal textChanged()

    implicitHeight: Theme.inputHeight
    implicitWidth: 240
    radius: Theme.radiusMedium
    color: Theme.bgInput
    border.width: 1
    border.color: input.activeFocus ? Theme.borderFocus
               : fieldMouse.containsMouse ? Theme.borderHover
               : "transparent"

    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacing8
        anchors.rightMargin: Theme.spacing8
        spacing: Theme.spacing6

        // Icône loupe
        Text {
            text: "🔍"
            font.pixelSize: Theme.fontCaption
            opacity: 0.5
        }

        TextInput {
            id: input
            Layout.fillWidth: true
            Layout.fillHeight: true
            verticalAlignment: TextInput.AlignVCenter
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            color: Theme.textPrimary
            clip: true
            selectByMouse: true
            selectionColor: Theme.accentActive
            selectedTextColor: "#FFFFFF"

            onAccepted: root.accepted()
            onTextChanged: root.textChanged()

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

        // Bouton clear
        Rectangle {
            visible: root.clearable && input.text.length > 0
            width: 20; height: 20
            radius: Theme.radiusSmall
            color: clearMouse.containsMouse ? Theme.bgHover : "transparent"

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.pixelSize: 11
                color: Theme.textSecondary
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { input.text = ""; input.forceActiveFocus() }
            }
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
