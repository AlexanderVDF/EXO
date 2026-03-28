import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "pages"
import "panels"
import "components"
import "theme"

ApplicationWindow {
    id: mainWindow
    visible: true
    width: 1280
    height: 800
    minimumWidth: 900
    minimumHeight: 600
    title: "EXO Assistant"
    color: Theme.bgPrimary

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
