import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "vscode"

ApplicationWindow {
    id: mainWindow
    visible: true
    width: 1280
    height: 800
    minimumWidth: 900
    minimumHeight: 600
    title: "EXO Assistant"
    color: "#1E1E1E"

    // ── État global ──
    property string appStatus: "Idle"
    property real micLevel: 0.0
    property string partialTranscript: ""
    property string currentResponse: ""
    property bool isStreaming: false
    property bool servicesReady: typeof serviceManager !== 'undefined'
                                 ? serviceManager.allReady : true

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
            transcriptView.addMessage(transcription, true, false)
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
            transcriptView.addMessage(fullText, false, false)
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
                border.color: "#F44747"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: "⚠ Mode vocal indisponible — passage en mode clavier"
                        font.family: "Cascadia Code, Fira Code, Consolas"
                        font.pixelSize: 12
                        color: "#F44747"
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Ouvrir paramètres ›"
                        font.family: "Cascadia Code, Fira Code, Consolas"
                        font.pixelSize: 11
                        color: "#569CD6"

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

            StackLayout {
                id: centralStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: 0

                // Index 0 : Chat (Transcript + Response)
                SplitView {
                    id: chatSplit
                    orientation: Qt.Horizontal

                    TranscriptView {
                        id: transcriptView
                        SplitView.fillWidth: true
                        SplitView.minimumWidth: 300
                        partialTranscript: mainWindow.partialTranscript
                    }

                    ResponseView {
                        id: responseView
                        SplitView.preferredWidth: parent.width * 0.45
                        SplitView.minimumWidth: 250
                        currentResponse: mainWindow.currentResponse
                        isStreaming: mainWindow.isStreaming
                    }

                    handle: Rectangle {
                        implicitWidth: 1
                        color: "#3C3C3C"

                        Rectangle {
                            anchors.centerIn: parent
                            width: 1
                            height: 30
                            radius: 1
                            color: "#5A5A5A"
                        }
                    }
                }

                // Index 1 : Settings
                SettingsPanel {
                    id: settingsPanel
                }

                // Index 2 : History
                HistoryPanel {
                    id: historyPanel
                }

                // Index 3 : Logs
                LogPanel {
                    id: logPanel
                }

                // Index 4 : Pipeline Monitor
                PipelineMonitor {
                    id: pipelineMonitor
                }
            }

            // ── Fallback clavier (quand pas de micro) ──
            Rectangle {
                id: keyboardFallback
                Layout.fillWidth: true
                height: visible ? 44 : 0
                visible: typeof audioDeviceManager !== 'undefined'
                         && !audioDeviceManager.hasValidInputDevice
                color: "#252526"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: 30
                        radius: 3
                        color: "#1E1E1E"
                        border.color: keyboardInput.activeFocus ? "#007ACC" : "#3C3C3C"

                        TextInput {
                            id: keyboardInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 13
                            color: "#D4D4D4"
                            clip: true

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Tapez votre message ici…"
                                font.family: parent.font.family
                                font.pixelSize: parent.font.pixelSize
                                color: "#5A5A5A"
                                visible: !keyboardInput.text && !keyboardInput.activeFocus
                            }

                            Keys.onReturnPressed: {
                                if (text.trim().length > 0) {
                                    if (typeof assistantManager !== 'undefined')
                                        assistantManager.sendMessage(text.trim())
                                    transcriptView.addMessage(text.trim(), true, false)
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
                                transcriptView.addMessage(keyboardInput.text.trim(), true, false)
                                keyboardInput.text = ""
                            }
                        }

                        background: Rectangle {
                            color: parent.hovered ? "#007ACC" : "#0E639C"
                            radius: 3
                        }
                        contentItem: Text {
                            text: parent.text
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 12
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Behavior on height { NumberAnimation { duration: 200 } }
            }

            // ── Bottom bar ──
            BottomBar {
                Layout.fillWidth: true
                audioLevel: mainWindow.micLevel
                isListening: mainWindow.appStatus === "Listening"
                isSpeaking: mainWindow.appStatus === "Speaking"
                temperature: typeof weatherManager !== 'undefined'
                             ? weatherManager.temperature + "°C" : ""
                weatherDesc: typeof weatherManager !== 'undefined'
                             ? weatherManager.description : ""
            }
        }
    }

    // ══════════════════════════════════════════════
    //  Splash Screen — démarrage des services
    // ══════════════════════════════════════════════

    SplashScreen {
        id: splashScreen
        anchors.fill: parent
        z: 100
        visible: !mainWindow.servicesReady
        allReady: mainWindow.servicesReady
        readyCount: typeof serviceManager !== 'undefined' ? serviceManager.readyCount : 0
        totalServices: typeof serviceManager !== 'undefined' ? serviceManager.totalServices : 0
        currentAction: typeof serviceManager !== 'undefined' ? serviceManager.currentAction : "Initialisation…"
        serviceStatuses: typeof serviceManager !== 'undefined' ? serviceManager.serviceStatuses : []
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
    //  Initialisation
    // ══════════════════════════════════════════════

    Component.onCompleted: {
    }
}
