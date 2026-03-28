import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

// ═══════════════════════════════════════════════════════
//  HomePage — Page principale chat (Transcript + Réponse)
// ═══════════════════════════════════════════════════════

Item {
    id: root

    property string partialTranscript: ""
    property string currentResponse: ""
    property bool isStreaming: false

    // Expose les vues pour le wiring externe
    property alias transcriptView: transcript
    property alias responseView: response

    SplitView {
        anchors.fill: parent
        orientation: Qt.Vertical

        ExoTranscriptView {
            id: transcript
            SplitView.fillWidth: true
            SplitView.preferredHeight: parent.height * 0.55
            SplitView.minimumHeight: 100
            partialTranscript: root.partialTranscript
        }

        ExoResponseView {
            id: response
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            SplitView.minimumHeight: 80
            responseText: root.currentResponse
            isStreaming: root.isStreaming
        }

        handle: Rectangle {
            implicitHeight: 4
            color: SplitHandle.hovered || SplitHandle.pressed
                   ? Theme.borderFocus : Theme.border
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }
}
