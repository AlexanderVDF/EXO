import QtQuick
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  ExoPanelHeader — En-tête standard pour panneaux
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root

    property string title: ""
    property color titleColor: Theme.textAccent
    property alias rightContent: rightSlot.children

    Layout.fillWidth: true
    implicitHeight: Theme.headerHeight
    color: Theme.bgSecondary

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.marginH
        anchors.rightMargin: Theme.marginH

        Text {
            text: root.title.toUpperCase()
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontMicro
            font.weight: Font.Bold
            color: root.titleColor
            font.letterSpacing: 1.5
        }

        Item { Layout.fillWidth: true }

        Row {
            id: rightSlot
            spacing: Theme.spacing12
        }
    }

    // Séparateur bas
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.border
    }
}
