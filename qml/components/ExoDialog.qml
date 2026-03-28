import QtQuick
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  ExoDialog — Dialogue modal Fluent avec fond flouté
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root

    property string title: ""
    property alias contentItem: contentLoader.sourceComponent
    property bool showClose: true

    signal accepted()
    signal rejected()
    signal closed()

    anchors.fill: parent
    color: "#80000000"   // overlay sombre
    visible: false
    z: 50

    // Clic sur le fond = fermer
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    // Panneau central
    Rectangle {
        id: dialogPanel
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.8, 480)
        implicitHeight: dialogCol.height + Theme.paddingSection * 2
        radius: Theme.radiusLarge
        color: Theme.bgElevated
        border.width: 1
        border.color: Theme.border

        // Ombre profonde
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            z: -1
            radius: parent.radius + 2
            color: "#000000"
            opacity: 0.3
        }

        // Stop les clics sur le fond
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: dialogCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.paddingSection
            spacing: Theme.spacing16

            // Header
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.title
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontH3
                    font.weight: Font.SemiBold
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                // Bouton fermer
                Rectangle {
                    visible: root.showClose
                    width: 28; height: 28
                    radius: Theme.radiusSmall
                    color: closeMouse.containsMouse ? Theme.bgHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 14
                        color: Theme.textSecondary
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }

            // Contenu dynamique
            Loader {
                id: contentLoader
                Layout.fillWidth: true
            }
        }

        // Animation d'ouverture
        scale: 0.95
        opacity: 0

        states: State {
            name: "visible"
            when: root.visible
            PropertyChanges { target: dialogPanel; scale: 1.0; opacity: 1.0 }
        }

        transitions: Transition {
            NumberAnimation { properties: "scale,opacity"; duration: Theme.animNormal; easing.type: Easing.OutCubic }
        }
    }

    function open()  { visible = true }
    function close() { visible = false; closed() }
}
