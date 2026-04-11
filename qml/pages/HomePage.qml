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

    // v8: Plan & Context properties
    property var currentPlan: null       // {id, goal, steps, progress, strategy}
    property string contextTopic: ""
    property real contextConfidence: 0.0
    property string contextEnergy: "normal"
    property string contextLocation: ""

    // Expose les vues pour le wiring externe
    property alias transcriptView: transcript
    property alias responseView: response
    property alias planProgress: planWidget
    property alias contextPanel: ctxPanel

    // v9: Mode Expert
    property bool expertMode: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── v9: Mode Switch + PipelineView Expert ──
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.spacing8
            Layout.rightMargin: Theme.spacing8
            Layout.topMargin: Theme.spacing4
            spacing: Theme.spacing8

            ModeSwitch {
                id: modeSwitch
                expertMode: root.expertMode
                onModeChanged: function(isExpert) {
                    root.expertMode = isExpert
                    if (typeof configManager !== 'undefined')
                        configManager.setUserValue("gui/expertMode", isExpert)
                }
            }

            Item { Layout.fillWidth: true }
        }

        // ── v9: Pipeline horizontal (Expert only) ──
        PipelineView {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.spacing8
            Layout.rightMargin: Theme.spacing8
            Layout.topMargin: Theme.spacing4
            Layout.preferredHeight: root.expertMode ? 140 : 0
            visible: root.expertMode
            collapsed: !root.expertMode
            clip: true

            Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.InOutQuad } }
        }

        // ── v8: Context panel ──
        ExoContextPanel {
            id: ctxPanel
            Layout.fillWidth: true
            Layout.leftMargin: Theme.spacing8
            Layout.rightMargin: Theme.spacing8
            Layout.topMargin: Theme.spacing4
            topic: root.contextTopic
            topicConfidence: root.contextConfidence
            energyLevel: root.contextEnergy
            location: root.contextLocation
        }

        // ── v8: Plan progress ──
        ExoPlanProgress {
            id: planWidget
            Layout.fillWidth: true
            Layout.leftMargin: Theme.spacing8
            Layout.rightMargin: Theme.spacing8
            Layout.topMargin: root.currentPlan ? Theme.spacing4 : 0
            plan: root.currentPlan
        }

        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Vertical

            // ── v9: CognitiveTimeline compact (Expert only) ──
            CognitiveTimeline {
                SplitView.fillWidth: true
                SplitView.preferredHeight: root.expertMode ? 200 : 0
                SplitView.minimumHeight: 0
                visible: root.expertMode
                compact: true
                clip: true

                Behavior on SplitView.preferredHeight { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.InOutQuad } }
            }

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

    // Load saved expert mode
    Component.onCompleted: {
        if (typeof configManager !== 'undefined') {
            var saved = configManager.getUserValue("gui/expertMode", false)
            root.expertMode = (saved === true || saved === "true")
            modeSwitch.expertMode = root.expertMode
        }
    }
}
