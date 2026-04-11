import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  VisionBehaviorPanel — Analyse comportementale
//  Postures, mouvements, comportements détectés
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var engine: null
    property var events: engine ? engine.recentEvents : []

    readonly property var behaviorNames: [
        "Normal", "Errance", "Course", "Agité", "Suspect", "Bagarre", "Déambulation"
    ]
    readonly property var postureNames: [
        "Inconnu", "Debout", "Assis", "Couché", "Accroupi", "Chute"
    ]

    // Filtrer les événements comportementaux
    property var behaviorEvents: {
        var result = [];
        for (var i = 0; i < events.length; ++i) {
            var t = events[i].type || 0;
            if (t >= 9 && t <= 13) result.push(events[i]);  // Loitering..ProlongedAbsence
        }
        return result;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Label {
            text: "🧠 Analyse Comportementale (" + root.behaviorEvents.length + ")"
            font.pixelSize: 13
            font.bold: true
            color: Theme.textPrimary
        }

        // ── Résumé comportements ──
        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    { label: "Errance", type: 9, color: Theme.warning },
                    { label: "Agitation", type: 10, color: Theme.error },
                    { label: "Mvt anormal", type: 11, color: "#FF8C00" },
                    { label: "Objet déplacé", type: 12, color: Theme.info },
                    { label: "Absence", type: 13, color: "#9C27B0" }
                ]
                delegate: Rectangle {
                    width: behaviorLabel.width + 12
                    height: 24
                    radius: 12
                    color: Qt.rgba(modelData.color.r || 0, modelData.color.g || 0,
                                   modelData.color.b || 0, 0.15)

                    property int typeCount: {
                        var c = 0;
                        for (var i = 0; i < root.behaviorEvents.length; ++i)
                            if (root.behaviorEvents[i].type === modelData.type) c++;
                        return c;
                    }

                    visible: typeCount > 0

                    Label {
                        id: behaviorLabel
                        anchors.centerIn: parent
                        text: modelData.label + " (" + typeCount + ")"
                        font.pixelSize: 10
                        color: modelData.color
                    }
                }
            }
        }

        // ── Liste détaillée ──
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.behaviorEvents

            delegate: Rectangle {
                width: ListView.view.width
                height: 44
                radius: 4
                color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.06)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Label {
                            text: modelData.description || "Événement comportemental"
                            font.pixelSize: 11
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: (modelData.cameraId || "") + " • " +
                                  (modelData.roomId || "—") + " • " +
                                  Math.round((modelData.confidence || 0) * 100) + "%"
                            font.pixelSize: 9
                            color: Theme.textSecondary
                        }
                    }
                }
            }
        }
    }
}
