import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "pages"
import "panels"
import "components"
import "theme"
import RaspberryAssistant  // FloorPlanModel QML_ELEMENT

ApplicationWindow {
    id: mainWindow
    visible: true
    width: 1280
    height: 800
    minimumWidth: 900
    minimumHeight: 600
    title: "EXO Assistant"
    color: Theme.bgPrimary

    // ── Floor Plan Model (QML_ELEMENT) ──
    FloorPlanModel { id: floorPlanModel }

    // ── État global ──
    property string appStatus: "Idle"
    property real micLevel: 0.0
    property string partialTranscript: ""
    property string currentResponse: ""
    property bool isStreaming: false
    property bool servicesReady: typeof serviceSupervisor !== 'undefined'
                                 ? (serviceSupervisor.allReady
                                    || (typeof safeBootManager !== 'undefined' && safeBootManager.criticalReady))
                                 : true

    // ══════════════════════════════════════════════
    //  Connexions aux context properties C++
    // ══════════════════════════════════════════════

    Connections {
        target: typeof voiceManager !== 'undefined' ? voiceManager : null

        function onListeningChanged() {
            if (voiceManager.isListening) {
                mainWindow.appStatus = "Listening"
            } else if (mainWindow.appStatus === "Listening") {
                mainWindow.appStatus = "Idle"
            }
        }

        function onSpeakingChanged() {
            if (voiceManager.isSpeaking) {
                mainWindow.appStatus = "Speaking"
            } else if (mainWindow.appStatus === "Speaking") {
                mainWindow.appStatus = "Idle"
            }
        }

        function onSpeechTranscribed(transcription) {
            mainWindow.appStatus = "Transcribing"
            mainWindow.partialTranscript = ""
            homePage.transcriptView.addMessage(transcription, true, false)
        }

        function onCommandDetected(command) {
            mainWindow.partialTranscript = command
        }

        function onWakeWordDetected() {
            mainWindow.appStatus = "Listening"
        }

        function onAudioLevel(rms, vadScore) {
            mainWindow.micLevel = rms
        }

        function onMicPcmForVisualization(samples) {
            micWaveform.updateSamples(samples)
        }

        function onTtsPcmForVisualization(samples) {
            ttsWaveform.updateSamples(samples)
        }

        function onPartialTranscript(text) {
            mainWindow.partialTranscript = text
        }

        function onStateChanged(newState) {
            var states = ["Idle", "DetectingSpeech", "Listening", "Transcribing", "Thinking", "Speaking"]
            if (newState >= 0 && newState < states.length)
                mainWindow.appStatus = states[newState]
        }
    }

    Connections {
        target: typeof claudeAPI !== 'undefined' ? claudeAPI : null

        function onRequestStarted() {
            mainWindow.appStatus = "Thinking"
            mainWindow.isStreaming = true
            mainWindow.currentResponse = ""
        }

        function onPartialResponse(text) {
            mainWindow.currentResponse = text
        }

        function onFinalResponse(fullText) {
            mainWindow.currentResponse = fullText
            mainWindow.isStreaming = false
            mainWindow.appStatus = "Idle"
            homePage.transcriptView.addMessage(fullText, false, false)
        }

        function onResponseReceived(response) {
            mainWindow.currentResponse = response
            mainWindow.isStreaming = false
        }

        function onErrorOccurred(error) {
            mainWindow.currentResponse = "Erreur: " + error
            mainWindow.isStreaming = false
            mainWindow.appStatus = "Idle"
        }
    }

    Connections {
        target: typeof assistantManager !== 'undefined' ? assistantManager : null

        function onErrorOccurred(error) {
            mainWindow.currentResponse = "Erreur: " + error
            mainWindow.appStatus = "Idle"
        }

        function onNetworkScanCompleted(result) {
            reseauPage.scanning = false
            if (result.status === "success") {
                var nodes = result.devices || result.nodes || []
                var topo = result.topology || {}
                var links = topo.links || result.links || result.edges || []
                reseauPage.nodes = nodes
                reseauPage.links = links
            }
        }

        function onHomeGraphReceived(result) {
            if (result.status === "success") {
                maisonPage.devices = result.devices || []
                maisonPage.rooms = result.rooms || []
                maisonPage.scenarios = result.scenarios || []
            }
        }

        function onDeviceCommandResult(result) {
            // Refresh home graph after a device command
            if (result.status === "success" && typeof assistantManager !== 'undefined')
                assistantManager.requestHomeGraph()
        }

        function onScenarioResult(result) {
            // Refresh after scenario execution
            if (typeof assistantManager !== 'undefined')
                assistantManager.requestHomeGraph()
        }
    }

    // ══════════════════════════════════════════════
    //  Layout principal
    // ══════════════════════════════════════════════

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Sidebar gauche ──
        Sidebar {
            id: sidebar
            Layout.fillHeight: true
            currentStatus: mainWindow.appStatus
            micLevel: mainWindow.micLevel

            onPanelSelected: function(panelName) {
                switch (panelName) {
                case "chat":
                    centralStack.currentIndex = 0
                    break
                case "settings":
                    centralStack.currentIndex = 1
                    break
                case "history":
                    centralStack.currentIndex = 2
                    break
                case "logs":
                    centralStack.currentIndex = 3
                    break
                case "pipeline":
                    centralStack.currentIndex = 4
                    break
                case "maison":
                    centralStack.currentIndex = 5
                    // Auto-refresh HomeGraph when navigating to Maison
                    if (typeof assistantManager !== 'undefined')
                        assistantManager.requestHomeGraph()
                    break
                case "reseau":
                    centralStack.currentIndex = 6
                    break
                case "cognitive":
                    centralStack.currentIndex = 7
                    break
                case "heatmap":
                    centralStack.currentIndex = 8
                    break
                case "voicepipeline":
                    centralStack.currentIndex = 9
                    break
                case "memory":
                    centralStack.currentIndex = 10
                    break
                case "governance":
                    centralStack.currentIndex = 11
                    break
                case "observability":
                    centralStack.currentIndex = 12
                    break
                case "floorplan":
                    centralStack.currentIndex = 13
                    break
                case "simulation":
                    centralStack.currentIndex = 15
                    break
                case "stability":
                    centralStack.currentIndex = 14
                    break
                }
            }
        }

        // ── Zone centrale ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ── Bannière erreur micro ──
            Rectangle {
                id: micErrorBanner
                Layout.fillWidth: true
                height: visible ? 36 : 0
                visible: typeof audioDeviceManager !== 'undefined'
                         && !audioDeviceManager.hasValidInputDevice
                color: "#4B1E1E"
                border.color: Theme.error
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacing12
                    anchors.rightMargin: Theme.spacing12
                    spacing: Theme.spacing8

                    Text {
                        text: "⚠ Mode vocal indisponible — passage en mode clavier"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontCaption
                        color: Theme.error
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Ouvrir paramètres ›"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontMicro
                        color: Theme.info

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                centralStack.currentIndex = 1 // Settings panel
                            }
                        }
                    }
                }

                Behavior on height { NumberAnimation { duration: 200 } }
            }

            // ── Header Bar ──
            HeaderBar {
                Layout.fillWidth: true
                currentPage: sidebar.activePanel
                pipelineState: mainWindow.appStatus
            }

            StackLayout {
                id: centralStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: 0

                // Index 0 : Chat (Transcript + Response)
                HomePage {
                    id: homePage
                    partialTranscript: mainWindow.partialTranscript
                    currentResponse: mainWindow.currentResponse
                    isStreaming: mainWindow.isStreaming
                }

                // Index 1 : Settings
                SettingsPage {
                    id: settingsPage
                }

                // Index 2 : History
                HistoryPage {
                    id: historyPage
                }

                // Index 3 : Logs
                LogsPage {
                    id: logsPage
                }

                // Index 4 : Pipeline Monitor
                PipelinePage {
                    id: pipelinePage
                }

                // Index 5 : Maison (Domotique v1)
                MaisonPage {
                    id: maisonPage
                    onDeviceCommand: function(deviceId, command, params) {
                        if (typeof assistantManager !== 'undefined')
                            assistantManager.requestDeviceCommand(deviceId, command, params || {})
                    }
                    onRefreshRequested: {
                        if (typeof assistantManager !== 'undefined')
                            assistantManager.requestHomeGraph()
                    }
                    onScenarioRequested: function(name) {
                        if (typeof assistantManager !== 'undefined')
                            assistantManager.requestRunScenario(name)
                    }
                }

                // Index 6 : Réseau (Domotique v1)
                ReseauPage {
                    id: reseauPage
                    onScanRequested: {
                        if (typeof assistantManager !== 'undefined') {
                            reseauPage.scanning = true
                            assistantManager.requestNetworkScan(false)
                        }
                    }
                    onScanFastRequested: {
                        if (typeof assistantManager !== 'undefined') {
                            reseauPage.scanning = true
                            assistantManager.requestNetworkScan(true)
                        }
                    }
                }

                // Index 7 : Cognitive Timeline
                CognitiveTimeline {}

                // Index 8 : Engine Heatmap
                EngineHeatmap {}

                // Index 9 : Voice Pipeline Flow
                VoicePipelineView {}

                // Index 10 : Memory Inspector
                MemoryInspector {}

                // Index 11 : Governance
                GovernancePanel {}

                // Index 12 : Observability Dashboard
                ObservabilityDashboard {}

                // Index 13 : Floor Plan Editor
                FloorPlanPage {
                    id: floorPlanPage
                    floorModel: floorPlanModel
                }

                // Index 14 : Stability Tests
                StabilityPanel {
                    id: stabilityPanel
                }

                // Index 15 : Simulation Spatiale
                SimulationPage {
                    id: simulationPage
                }
            }

            // ── Fallback clavier (quand pas de micro) ──
            Rectangle {
                id: keyboardFallback
                Layout.fillWidth: true
                height: visible ? 44 : 0
                visible: typeof audioDeviceManager !== 'undefined'
                         && !audioDeviceManager.hasValidInputDevice
                color: Theme.bgSecondary

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacing12
                    anchors.rightMargin: Theme.spacing12
                    spacing: Theme.spacing8

                    Rectangle {
                        Layout.fillWidth: true
                        height: 30
                        radius: Theme.radiusSmall
                        color: Theme.bgPrimary
                        border.color: keyboardInput.activeFocus ? Theme.borderFocus : Theme.border

                        TextInput {
                            id: keyboardInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSmall
                            color: "#D4D4D4"
                            clip: true

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Tapez votre message ici…"
                                font.family: parent.font.family
                                font.pixelSize: parent.font.pixelSize
                                color: Theme.textMuted
                                visible: !keyboardInput.text && !keyboardInput.activeFocus
                            }

                            Keys.onReturnPressed: {
                                if (text.trim().length > 0) {
                                    if (typeof assistantManager !== 'undefined')
                                        assistantManager.sendMessage(text.trim())
                                    homePage.transcriptView.addMessage(text.trim(), true, false)
                                    text = ""
                                }
                            }
                        }
                    }

                    Button {
                        text: "Envoyer"
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 30

                        onClicked: {
                            if (keyboardInput.text.trim().length > 0) {
                                if (typeof assistantManager !== 'undefined')
                                    assistantManager.sendMessage(keyboardInput.text.trim())
                                homePage.transcriptView.addMessage(keyboardInput.text.trim(), true, false)
                                keyboardInput.text = ""
                            }
                        }

                        background: Rectangle {
                            color: parent.hovered ? Theme.accentHover : Theme.accent
                            radius: Theme.radiusSmall
                        }
                        contentItem: Text {
                            text: parent.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontCaption
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Behavior on height { NumberAnimation { duration: 200 } }
            }

            // ── Waveform Visualizers ──
            AudioWaveformView {
                id: micWaveform
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                waveColor: "#00FF88"
                amplitude: 0.45
                thickness: 2.0
                glowAmount: 0.018
                active: mainWindow.appStatus === "Listening"
                        || mainWindow.appStatus === "DetectingSpeech"
                visible: mainWindow.appStatus === "Listening"
                         || mainWindow.appStatus === "DetectingSpeech"
                         || micFadeOut.running

                Behavior on opacity { NumberAnimation { id: micFadeOut; duration: 400 } }
            }

            AudioWaveformView {
                id: ttsWaveform
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                waveColor: "#00AEEF"
                amplitude: 0.5
                thickness: 2.2
                glowAmount: 0.02
                active: mainWindow.appStatus === "Speaking"
                visible: mainWindow.appStatus === "Speaking"
                         || ttsFadeOut.running

                Behavior on opacity { NumberAnimation { id: ttsFadeOut; duration: 400 } }
            }

            // ── Bottom bar ──
            BottomBar {
                Layout.fillWidth: true
                audioLevel: mainWindow.micLevel
            }
        }
    }

    // ══════════════════════════════════════════════
    //  Splash Screen — démarrage des services
    // ══════════════════════════════════════════════

    ExoSplashScreen {
        id: splashScreen
        anchors.fill: parent
        z: 100
        visible: !mainWindow.servicesReady
        allReady: mainWindow.servicesReady
        readyCount: typeof serviceSupervisor !== 'undefined' ? serviceSupervisor.readyCount : 0
        totalServices: typeof serviceSupervisor !== 'undefined' ? serviceSupervisor.totalServices : 0
        currentAction: typeof serviceSupervisor !== 'undefined' ? serviceSupervisor.currentAction : "Initialisation…"
        serviceStatuses: typeof serviceSupervisor !== 'undefined' ? serviceSupervisor.serviceStatuses : []
        safeBootActive: typeof safeBootManager !== 'undefined' ? safeBootManager.safeBootActive : false
        criticalReady: typeof safeBootManager !== 'undefined' ? safeBootManager.criticalReady : false
        criticalReadyCount: typeof safeBootManager !== 'undefined' ? safeBootManager.criticalReadyCount : 0
        criticalTotal: typeof safeBootManager !== 'undefined' ? safeBootManager.criticalTotal : 0
        lazyReadyCount: typeof safeBootManager !== 'undefined' ? safeBootManager.lazyReadyCount : 0
        lazyTotal: typeof safeBootManager !== 'undefined' ? safeBootManager.lazyTotal : 0
        failedCount: typeof safeBootManager !== 'undefined' ? safeBootManager.failedCount : 0
        failedServices: typeof safeBootManager !== 'undefined' ? safeBootManager.failedServices : []
        onDismissed: splashScreen.visible = false
    }

    // ══════════════════════════════════════════════
    //  Raccourcis clavier
    // ══════════════════════════════════════════════

    Shortcut {
        sequence: "Space"
        onActivated: {
            if (typeof assistantManager !== 'undefined') {
                if (mainWindow.appStatus === "Listening") {
                    assistantManager.stopListening()
                } else {
                    assistantManager.startListening()
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (typeof assistantManager !== 'undefined') {
                assistantManager.stopListening()
            }
            mainWindow.appStatus = "Idle"
        }
    }

    Shortcut {
        sequence: "Ctrl+,"
        onActivated: {
            sidebar.activePanel = "settings"
            centralStack.currentIndex = 1
        }
    }

    Shortcut {
        sequence: "Ctrl+H"
        onActivated: {
            sidebar.activePanel = "history"
            centralStack.currentIndex = 2
        }
    }

    // ══════════════════════════════════════════════
    //  Persistance géométrie fenêtre
    // ══════════════════════════════════════════════

    function saveGeometry() {
        if (typeof configManager === 'undefined') return
        configManager.setUserValue("Window", "x", mainWindow.x)
        configManager.setUserValue("Window", "y", mainWindow.y)
        configManager.setUserValue("Window", "width", mainWindow.width)
        configManager.setUserValue("Window", "height", mainWindow.height)
    }

    onXChanged: saveGeometryTimer.restart()
    onYChanged: saveGeometryTimer.restart()
    onWidthChanged: saveGeometryTimer.restart()
    onHeightChanged: saveGeometryTimer.restart()

    Timer {
        id: saveGeometryTimer
        interval: 500
        onTriggered: mainWindow.saveGeometry()
    }

    // ══════════════════════════════════════════════
    //  Initialisation
    // ══════════════════════════════════════════════

    Component.onCompleted: {
        if (typeof configManager !== 'undefined') {
            var sx = configManager.getInt("Window", "x", -1)
            var sy = configManager.getInt("Window", "y", -1)
            var sw = configManager.getInt("Window", "width", 0)
            var sh = configManager.getInt("Window", "height", 0)
            if (sw > 0 && sh > 0) {
                mainWindow.width = sw
                mainWindow.height = sh
            }
            if (sx >= 0 && sy >= 0) {
                mainWindow.x = sx
                mainWindow.y = sy
            }
        }
    }
}
