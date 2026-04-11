import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  VisionDetectionsLayer — Couche de bounding boxes
//  Dessine les rectangles de détection sur un flux vidéo
// ═══════════════════════════════════════════════════════

Item {
    id: root

    property var detections: []    // QVariantList de détections
    property string cameraId: ""
    property var engine: null

    readonly property var typeColors: {
        0: "#2196F3",   // Person — bleu
        1: "#4CAF50",   // Animal — vert
        2: "#FF9800",   // Vehicle — orange
        3: "#9C27B0",   // Object — violet
        4: "#FF0040",   // Fire — rouge vif
        5: "#FF6F00",   // Smoke — orange foncé
        6: "#795548",   // Obstruction — brun
        7: "#E91E63",   // Fall — rose
        8: "#F44336",   // Intrusion — rouge
        9: "#FFEB3B",   // Loitering — jaune
        10: "#FF5722",  // Agitation — rouge-orange
        11: "#FF7043"   // AbnormalMovement
    }

    Repeater {
        model: root.detections

        delegate: Item {
            x: (modelData.bbox ? modelData.bbox.x : 0) * root.width
            y: (modelData.bbox ? modelData.bbox.y : 0) * root.height
            width: (modelData.bbox ? modelData.bbox.width : 0) * root.width
            height: (modelData.bbox ? modelData.bbox.height : 0) * root.height

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: root.typeColors[modelData.type] || Theme.primary
                border.width: 2
                radius: 2
            }

            // Label détection
            Rectangle {
                anchors.bottom: parent.top
                anchors.left: parent.left
                width: detLabel.width + 8
                height: 16
                radius: 2
                color: root.typeColors[modelData.type] || Theme.primary

                Label {
                    id: detLabel
                    anchors.centerIn: parent
                    text: (modelData.className || "?") + " " +
                          Math.round((modelData.confidence || 0) * 100) + "%"
                    font.pixelSize: 9
                    color: "white"
                }
            }

            // Indicateur de posture / comportement
            Label {
                visible: (modelData.posture || 0) > 1 || (modelData.behavior || 0) > 0
                anchors.top: parent.bottom
                anchors.left: parent.left
                anchors.topMargin: 2
                text: {
                    var parts = [];
                    var postures = ["", "Debout", "Assis", "Couché", "Accroupi", "Chute!"];
                    var behaviors = ["Normal", "Errance", "Course", "Agité", "Suspect", "Bagarre", "Déambulation"];
                    if ((modelData.posture || 0) >= 2) parts.push(postures[modelData.posture]);
                    if ((modelData.behavior || 0) > 0) parts.push(behaviors[modelData.behavior]);
                    return parts.join(" • ");
                }
                font.pixelSize: 8
                color: (modelData.behavior || 0) >= 3 ? Theme.error : Theme.textSecondary
            }
        }
    }
}
