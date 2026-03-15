import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#1E1E1E"

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: "#252526"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "PARAMÈTRES"
                font.family: "Cascadia Code, Fira Code, Consolas"
                font.pixelSize: 11
                font.bold: true
                color: "#007ACC"
                font.letterSpacing: 1.5
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: "#3C3C3C"
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: settingsCol.height + 32
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: settingsCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                y: 16
                spacing: 20

                // ── Section : Voice ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Voice"
                        font.family: "Cascadia Code, Fira Code, Consolas"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#E0E0E0"
                    }

                    // Wake word
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "assistant.wakeWord"
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 12
                            color: "#A0A0A0"
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            radius: 2
                            color: "#3C3C3C"
                            border.color: wakeInput.activeFocus ? "#007ACC" : "transparent"

                            TextInput {
                                id: wakeInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: "Cascadia Code, Fira Code, Consolas"
                                font.pixelSize: 13
                                color: "#E0E0E0"
                                text: typeof configManager !== 'undefined'
                                      ? configManager.getWakeWord() : "EXO"
                            }
                        }
                    }

                    // Audio Backend + STT Language (side by side)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: "audio.backend"
                                font.family: "Cascadia Code, Fira Code, Consolas"
                                font.pixelSize: 12
                                color: "#A0A0A0"
                            }

                            ComboBox {
                                id: audioBackendCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                model: ListModel {
                                    ListElement { text: "Qt Multimedia"; value: "qt" }
                                    ListElement { text: "RtAudio (WASAPI)"; value: "rtaudio" }
                                }
                                textRole: "text"
                                valueRole: "value"

                                Component.onCompleted: {
                                    var backend = typeof configManager !== 'undefined'
                                                  ? configManager.getString("Audio", "backend", "qt") : "qt"
                                    for (var i = 0; i < model.count; i++) {
                                        if (model.get(i).value === backend) {
                                            currentIndex = i
                                            break
                                        }
                                    }
                                }

                                onActivated: {
                                    var val = model.get(currentIndex).value
                                    if (typeof configManager !== 'undefined')
                                        configManager.setUserValue("Audio", "backend", val)
                                }

                                background: Rectangle {
                                    color: "#3C3C3C"
                                    border.color: audioBackendCombo.activeFocus ? "#007ACC" : "transparent"
                                    radius: 2
                                }
                                contentItem: Text {
                                    text: audioBackendCombo.displayText
                                    color: "#E0E0E0"
                                    font.family: "Cascadia Code, Fira Code, Consolas"
                                    font.pixelSize: 13
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 8
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: "stt.language"
                                font.family: "Cascadia Code, Fira Code, Consolas"
                                font.pixelSize: 12
                                color: "#A0A0A0"
                            }

                            ComboBox {
                                id: langCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                model: ListModel {
                                    ListElement { text: "Français"; value: "fr" }
                                    ListElement { text: "English"; value: "en" }
                                    ListElement { text: "Español"; value: "es" }
                                    ListElement { text: "Deutsch"; value: "de" }
                                    ListElement { text: "Italiano"; value: "it" }
                                    ListElement { text: "Português"; value: "pt" }
                                    ListElement { text: "日本語"; value: "ja" }
                                    ListElement { text: "中文"; value: "zh" }
                                }
                                textRole: "text"
                                valueRole: "value"

                                Component.onCompleted: {
                                    var lang = typeof configManager !== 'undefined'
                                               ? configManager.getSTTLanguage() : "fr"
                                    for (var i = 0; i < model.count; i++) {
                                        if (model.get(i).value === lang) {
                                            currentIndex = i
                                            break
                                        }
                                    }
                                }

                                onActivated: {
                                    var val = model.get(currentIndex).value
                                    if (typeof configManager !== 'undefined')
                                        configManager.setUserValue("STT", "language", val)
                                    if (typeof voiceManager !== 'undefined')
                                        voiceManager.setSTTLanguage(val)
                                }

                                background: Rectangle {
                                    radius: 2
                                    color: "#3C3C3C"
                                    border.color: langCombo.activeFocus ? "#007ACC" : "transparent"
                                }

                                contentItem: Text {
                                    leftPadding: 8
                                    text: langCombo.displayText
                                    font.family: "Cascadia Code, Fira Code, Consolas"
                                    font.pixelSize: 13
                                    color: "#E0E0E0"
                                    verticalAlignment: Text.AlignVCenter
                                }

                                delegate: ItemDelegate {
                                    width: langCombo.width
                                    contentItem: Text {
                                        text: model.text
                                        font.family: "Cascadia Code, Fira Code, Consolas"
                                        font.pixelSize: 13
                                        color: "#E0E0E0"
                                    }
                                    background: Rectangle {
                                        color: highlighted ? "#094771" : "#252526"
                                    }
                                }

                                popup: Popup {
                                    y: langCombo.height
                                    width: langCombo.width
                                    implicitHeight: contentItem.implicitHeight
                                    padding: 1

                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: langCombo.popup.visible ? langCombo.delegateModel : null
                                        currentIndex: langCombo.highlightedIndex
                                    }

                                    background: Rectangle {
                                        color: "#252526"
                                        border.color: "#3C3C3C"
                                        radius: 2
                                    }
                                }
                            }
                        }
                    }
                }

                // Séparateur
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#3C3C3C"
                }

                // ── Section : Weather ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Weather"
                        font.family: "Cascadia Code, Fira Code, Consolas"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#E0E0E0"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "weather.city"
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 12
                            color: "#A0A0A0"
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                height: 30
                                radius: 2
                                color: "#3C3C3C"
                                border.color: cityInput.activeFocus ? "#007ACC" : "transparent"

                                TextInput {
                                    id: cityInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.family: "Cascadia Code, Fira Code, Consolas"
                                    font.pixelSize: 13
                                    color: "#E0E0E0"
                                    text: typeof configManager !== 'undefined'
                                          ? configManager.getWeatherCity() : "Paris"

                                    Keys.onReturnPressed: {
                                        if (typeof configManager !== 'undefined')
                                            configManager.setWeatherCity(cityInput.text)
                                        if (typeof weatherManager !== 'undefined')
                                            weatherManager.setCity(cityInput.text)
                                    }
                                }
                            }

                            Rectangle {
                                width: 80
                                height: 30
                                radius: 2
                                color: detectArea.containsMouse ? "#094771" : "#007ACC"

                                Text {
                                    anchors.centerIn: parent
                                    text: "Détecter"
                                    font.family: "Cascadia Code, Fira Code, Consolas"
                                    font.pixelSize: 11
                                    color: "#FFFFFF"
                                }

                                MouseArea {
                                    id: detectArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (typeof configManager !== 'undefined')
                                            configManager.detectLocation()
                                    }
                                }
                            }
                        }
                    }
                }

                // Séparateur
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#3C3C3C"
                }

                // ── Section : Claude API ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Claude API"
                        font.family: "Cascadia Code, Fira Code, Consolas"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#E0E0E0"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "claude.model"
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 12
                            color: "#A0A0A0"
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            radius: 2
                            color: "#3C3C3C"

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                verticalAlignment: Text.AlignVCenter
                                font.family: "Cascadia Code, Fira Code, Consolas"
                                font.pixelSize: 13
                                color: "#DCDCAA"
                                text: typeof configManager !== 'undefined'
                                      ? configManager.getClaudeModel() : "claude-3-haiku"
                            }
                        }
                    }
                }

                // Séparateur
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#3C3C3C"
                }

                // ── Section : Microphone ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Microphone"
                        font.family: "Cascadia Code, Fira Code, Consolas"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#E0E0E0"
                    }

                    // VAD Threshold slider
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "vad.threshold"
                                font.family: "Cascadia Code, Fira Code, Consolas"
                                font.pixelSize: 12
                                color: "#A0A0A0"
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: vadSlider.value.toFixed(2)
                                font.family: "Cascadia Code, Fira Code, Consolas"
                                font.pixelSize: 12
                                color: "#DCDCAA"
                            }
                        }

                        Slider {
                            id: vadSlider
                            Layout.fillWidth: true
                            from: 0.1
                            to: 0.9
                            stepSize: 0.05
                            value: typeof configManager !== 'undefined'
                                   ? configManager.getVADThreshold() : 0.45

                            onMoved: {
                                if (typeof voiceManager !== 'undefined')
                                    voiceManager.setVADThreshold(value)
                            }

                            background: Rectangle {
                                x: vadSlider.leftPadding
                                y: vadSlider.topPadding + vadSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200
                                implicitHeight: 4
                                width: vadSlider.availableWidth
                                height: implicitHeight
                                radius: 2
                                color: "#3C3C3C"

                                Rectangle {
                                    width: vadSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: 2
                                    color: "#007ACC"
                                }
                            }

                            handle: Rectangle {
                                x: vadSlider.leftPadding + vadSlider.visualPosition * (vadSlider.availableWidth - width)
                                y: vadSlider.topPadding + vadSlider.availableHeight / 2 - height / 2
                                implicitWidth: 14
                                implicitHeight: 14
                                radius: 7
                                color: vadSlider.pressed ? "#FFFFFF" : "#C0C0C0"
                            }
                        }
                    }

                    // Noise Gate slider
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "noise.gate"
                                font.family: "Cascadia Code, Fira Code, Consolas"
                                font.pixelSize: 12
                                color: "#A0A0A0"
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: noiseSlider.value.toFixed(3)
                                font.family: "Cascadia Code, Fira Code, Consolas"
                                font.pixelSize: 12
                                color: "#DCDCAA"
                            }
                        }

                        Slider {
                            id: noiseSlider
                            Layout.fillWidth: true
                            from: 0.0
                            to: 0.05
                            stepSize: 0.001
                            value: 0.005

                            onMoved: {
                                if (typeof voiceManager !== 'undefined')
                                    voiceManager.setNoiseGate(value)
                            }

                            background: Rectangle {
                                x: noiseSlider.leftPadding
                                y: noiseSlider.topPadding + noiseSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200
                                implicitHeight: 4
                                width: noiseSlider.availableWidth
                                height: implicitHeight
                                radius: 2
                                color: "#3C3C3C"

                                Rectangle {
                                    width: noiseSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: 2
                                    color: "#007ACC"
                                }
                            }

                            handle: Rectangle {
                                x: noiseSlider.leftPadding + noiseSlider.visualPosition * (noiseSlider.availableWidth - width)
                                y: noiseSlider.topPadding + noiseSlider.availableHeight / 2 - height / 2
                                implicitWidth: 14
                                implicitHeight: 14
                                radius: 7
                                color: noiseSlider.pressed ? "#FFFFFF" : "#C0C0C0"
                            }
                        }
                    }

                    // AGC toggle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "agc.enabled"
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 12
                            color: "#A0A0A0"
                        }

                        Item { Layout.fillWidth: true }

                        Switch {
                            id: agcSwitch
                            checked: false

                            onToggled: {
                                if (typeof voiceManager !== 'undefined')
                                    voiceManager.setAGC(checked)
                            }

                            indicator: Rectangle {
                                implicitWidth: 40
                                implicitHeight: 20
                                x: agcSwitch.leftPadding
                                y: parent.height / 2 - height / 2
                                radius: 10
                                color: agcSwitch.checked ? "#007ACC" : "#3C3C3C"

                                Rectangle {
                                    x: agcSwitch.checked ? parent.width - width - 2 : 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: "#FFFFFF"

                                    Behavior on x {
                                        NumberAnimation { duration: 100 }
                                    }
                                }
                            }
                        }
                    }
                }

                // Séparateur
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#3C3C3C"
                }

                // ── Section : TTS Voice (XTTS v2) ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "TTS Voice — XTTS v2"
                        font.family: "Cascadia Code, Fira Code, Consolas"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#E0E0E0"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "tts.voice"
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 12
                            color: "#A0A0A0"
                        }

                        ComboBox {
                            id: voiceCombo
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            model: ListModel {
                                ListElement { text: "Claribel Dervla";   value: "Claribel Dervla" }
                                ListElement { text: "Daisy Studious";    value: "Daisy Studious" }
                                ListElement { text: "Gracie Wise";       value: "Gracie Wise" }
                                ListElement { text: "Brenda Stern";      value: "Brenda Stern" }
                                ListElement { text: "Nova Hogarth";      value: "Nova Hogarth" }
                                ListElement { text: "Sofia Hellen";      value: "Sofia Hellen" }
                                ListElement { text: "Ana Florence";      value: "Ana Florence" }
                                ListElement { text: "Alma María";        value: "Alma María" }
                                ListElement { text: "Andrew Chipper";    value: "Andrew Chipper" }
                                ListElement { text: "Damien Black";      value: "Damien Black" }
                                ListElement { text: "Craig Gutsy";       value: "Craig Gutsy" }
                                ListElement { text: "Viktor Menelaos";   value: "Viktor Menelaos" }
                            }
                            textRole: "text"
                            valueRole: "value"

                            Component.onCompleted: {
                                var voice = typeof configManager !== 'undefined'
                                            ? configManager.getTTSVoice() : "Claribel Dervla"
                                for (var i = 0; i < model.count; i++) {
                                    if (model.get(i).value === voice) {
                                        currentIndex = i
                                        break
                                    }
                                }
                            }

                            onActivated: {
                                var val = model.get(currentIndex).value
                                if (typeof configManager !== 'undefined')
                                    configManager.setUserValue("TTS", "voice", val)
                                if (typeof voiceManager !== 'undefined')
                                    voiceManager.setTTSVoice(val)
                            }

                            background: Rectangle {
                                radius: 2
                                color: "#3C3C3C"
                                border.color: voiceCombo.activeFocus ? "#007ACC" : "transparent"
                            }

                            contentItem: Text {
                                leftPadding: 8
                                text: voiceCombo.displayText
                                font.family: "Cascadia Code, Fira Code, Consolas"
                                font.pixelSize: 13
                                color: "#E0E0E0"
                                verticalAlignment: Text.AlignVCenter
                            }

                            delegate: ItemDelegate {
                                width: voiceCombo.width
                                contentItem: Text {
                                    text: model.text
                                    font.family: "Cascadia Code, Fira Code, Consolas"
                                    font.pixelSize: 13
                                    color: "#E0E0E0"
                                }
                                background: Rectangle {
                                    color: highlighted ? "#094771" : "#252526"
                                }
                            }

                            popup: Popup {
                                y: voiceCombo.height
                                width: voiceCombo.width
                                implicitHeight: contentItem.implicitHeight
                                padding: 1

                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: contentHeight
                                    model: voiceCombo.popup.visible ? voiceCombo.delegateModel : null
                                    currentIndex: voiceCombo.highlightedIndex
                                }

                                background: Rectangle {
                                    color: "#252526"
                                    border.color: "#3C3C3C"
                                    radius: 2
                                }
                            }
                        }
                    }

                    // ── Pitch + Rate sliders (side by side) ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "tts.pitch"
                                    font.family: "Cascadia Code, Fira Code, Consolas"
                                    font.pixelSize: 12
                                    color: "#A0A0A0"
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    id: pitchValueText
                                    text: pitchSlider.value.toFixed(2)
                                    font.family: "Cascadia Code, Fira Code, Consolas"
                                    font.pixelSize: 12
                                    color: "#E0E0E0"
                                }
                            }

                            Slider {
                                id: pitchSlider
                                Layout.fillWidth: true
                                from: 0.8
                                to: 1.2
                                value: 1.0
                                stepSize: 0.05

                                background: Rectangle {
                                    x: pitchSlider.leftPadding
                                    y: pitchSlider.topPadding + pitchSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 200
                                    implicitHeight: 4
                                    width: pitchSlider.availableWidth
                                    height: implicitHeight
                                    radius: 2
                                    color: "#3C3C3C"
                                    Rectangle {
                                        width: pitchSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: "#007ACC"
                                        radius: 2
                                    }
                                }

                                handle: Rectangle {
                                    x: pitchSlider.leftPadding + pitchSlider.visualPosition * (pitchSlider.availableWidth - width)
                                    y: pitchSlider.topPadding + pitchSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 14
                                    implicitHeight: 14
                                    radius: 7
                                    color: pitchSlider.pressed ? "#1A9FFF" : "#007ACC"
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "tts.rate"
                                    font.family: "Cascadia Code, Fira Code, Consolas"
                                    font.pixelSize: 12
                                    color: "#A0A0A0"
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    id: rateValueText
                                    text: rateSlider.value.toFixed(2)
                                    font.family: "Cascadia Code, Fira Code, Consolas"
                                    font.pixelSize: 12
                                    color: "#E0E0E0"
                                }
                            }

                            Slider {
                                id: rateSlider
                                Layout.fillWidth: true
                                from: 0.8
                                to: 1.2
                                value: 1.0
                                stepSize: 0.05

                                background: Rectangle {
                                    x: rateSlider.leftPadding
                                    y: rateSlider.topPadding + rateSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 200
                                    implicitHeight: 4
                                    width: rateSlider.availableWidth
                                    height: implicitHeight
                                    radius: 2
                                    color: "#3C3C3C"
                                    Rectangle {
                                        width: rateSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: "#007ACC"
                                        radius: 2
                                    }
                                }

                                handle: Rectangle {
                                    x: rateSlider.leftPadding + rateSlider.visualPosition * (rateSlider.availableWidth - width)
                                    y: rateSlider.topPadding + rateSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 14
                                    implicitHeight: 14
                                    radius: 7
                                    color: rateSlider.pressed ? "#1A9FFF" : "#007ACC"
                                }
                            }
                        }
                    }

                    // ── Style + Language (side by side) ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: "tts.style"
                                font.family: "Cascadia Code, Fira Code, Consolas"
                                font.pixelSize: 12
                                color: "#A0A0A0"
                            }

                            ComboBox {
                                id: styleCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                model: ["neutral", "conversational"]
                                currentIndex: 0

                                onActivated: {
                                    var val = model[currentIndex]
                                    if (typeof configManager !== 'undefined')
                                        configManager.setUserValue("TTS", "style", val)
                                    if (typeof voiceManager !== 'undefined')
                                        voiceManager.setTTSStyle(val)
                                }

                                background: Rectangle {
                                    radius: 2
                                    color: "#3C3C3C"
                                    border.color: styleCombo.activeFocus ? "#007ACC" : "transparent"
                                }

                                contentItem: Text {
                                    leftPadding: 8
                                    text: styleCombo.displayText
                                    font.family: "Cascadia Code, Fira Code, Consolas"
                                    font.pixelSize: 13
                                    color: "#E0E0E0"
                                    verticalAlignment: Text.AlignVCenter
                                }

                                delegate: ItemDelegate {
                                    width: styleCombo.width
                                    contentItem: Text {
                                        text: modelData
                                        font.family: "Cascadia Code, Fira Code, Consolas"
                                        font.pixelSize: 13
                                        color: "#E0E0E0"
                                    }
                                    background: Rectangle {
                                        color: highlighted ? "#094771" : "#252526"
                                    }
                                }

                                popup: Popup {
                                    y: styleCombo.height
                                    width: styleCombo.width
                                    implicitHeight: contentItem.implicitHeight
                                    padding: 1

                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: styleCombo.popup.visible ? styleCombo.delegateModel : null
                                        currentIndex: styleCombo.highlightedIndex
                                    }

                                    background: Rectangle {
                                        color: "#252526"
                                        border.color: "#3C3C3C"
                                        radius: 2
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: "tts.language"
                                font.family: "Cascadia Code, Fira Code, Consolas"
                                font.pixelSize: 12
                                color: "#A0A0A0"
                            }

                            ComboBox {
                                id: ttsLangCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                model: ListModel {
                                    ListElement { text: "Français";    value: "fr" }
                                    ListElement { text: "English";     value: "en" }
                                    ListElement { text: "Español";     value: "es" }
                                    ListElement { text: "Deutsch";     value: "de" }
                                    ListElement { text: "Italiano";    value: "it" }
                                    ListElement { text: "Português";   value: "pt" }
                                    ListElement { text: "Polski";      value: "pl" }
                                    ListElement { text: "Türkçe";      value: "tr" }
                                    ListElement { text: "Русский";     value: "ru" }
                                    ListElement { text: "Nederlands";  value: "nl" }
                                    ListElement { text: "Čeština";     value: "cs" }
                                    ListElement { text: "العربية";     value: "ar" }
                                    ListElement { text: "中文";         value: "zh-cn" }
                                    ListElement { text: "日本語";       value: "ja" }
                                    ListElement { text: "한국어";       value: "ko" }
                                    ListElement { text: "Magyar";      value: "hu" }
                                    ListElement { text: "हिन्दी";       value: "hi" }
                                }
                                textRole: "text"
                                valueRole: "value"

                                Component.onCompleted: {
                                    var lang = typeof configManager !== 'undefined'
                                               ? configManager.getTTSLanguage() : "fr"
                                    for (var i = 0; i < model.count; i++) {
                                        if (model.get(i).value === lang) {
                                            currentIndex = i
                                            break
                                        }
                                    }
                                }

                                onActivated: {
                                    var val = model.get(currentIndex).value
                                    if (typeof configManager !== 'undefined')
                                        configManager.setUserValue("TTS", "language", val)
                                    if (typeof voiceManager !== 'undefined')
                                        voiceManager.setTTSLanguage(val)
                                }

                                background: Rectangle {
                                    radius: 2
                                    color: "#3C3C3C"
                                    border.color: ttsLangCombo.activeFocus ? "#007ACC" : "transparent"
                                }

                                contentItem: Text {
                                    leftPadding: 8
                                    text: ttsLangCombo.displayText
                                    font.family: "Cascadia Code, Fira Code, Consolas"
                                    font.pixelSize: 13
                                    color: "#E0E0E0"
                                    verticalAlignment: Text.AlignVCenter
                                }

                                delegate: ItemDelegate {
                                    width: ttsLangCombo.width
                                    contentItem: Text {
                                        text: model.text
                                        font.family: "Cascadia Code, Fira Code, Consolas"
                                        font.pixelSize: 13
                                        color: "#E0E0E0"
                                    }
                                    background: Rectangle {
                                        color: highlighted ? "#094771" : "#252526"
                                    }
                                }

                                popup: Popup {
                                    y: ttsLangCombo.height
                                    width: ttsLangCombo.width
                                    implicitHeight: contentItem.implicitHeight
                                    padding: 1

                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: ttsLangCombo.popup.visible ? ttsLangCombo.delegateModel : null
                                        currentIndex: ttsLangCombo.highlightedIndex
                                    }

                                    background: Rectangle {
                                        color: "#252526"
                                        border.color: "#3C3C3C"
                                        radius: 2
                                    }
                                }
                            }
                        }
                    }

                    // ── Test phrase + Parler button (side by side) ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "tts.testPhrase"
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 12
                            color: "#A0A0A0"
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            TextField {
                                id: testPhraseField
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                text: "Bonjour, je suis EXO, votre assistant vocal."
                                font.family: "Cascadia Code, Fira Code, Consolas"
                                font.pixelSize: 13
                                color: "#E0E0E0"
                                placeholderText: "Entrez une phrase à tester…"
                                placeholderTextColor: "#6A6A6A"
                                background: Rectangle {
                                    radius: 2
                                    color: "#3C3C3C"
                                    border.color: testPhraseField.activeFocus ? "#007ACC" : "transparent"
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 90
                                Layout.preferredHeight: 30
                                radius: 4
                                color: testAudioMouse.pressed ? "#005A9E" : testAudioMouse.containsMouse ? "#1A9FFF" : "#007ACC"

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: "🔊"
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: "Parler"
                                        font.family: "Cascadia Code, Fira Code, Consolas"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: testAudioMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var phrase = testPhraseField.text.trim()
                                        if (phrase.length === 0) phrase = "Bonjour, je suis EXO."
                                        if (typeof voiceManager !== 'undefined') {
                                            voiceManager.speak(phrase)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Section : Memory ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#3C3C3C"
                    }

                    Text {
                        text: "Memory"
                        font.family: "Cascadia Code, Fira Code, Consolas"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#E0E0E0"
                    }

                    Row {
                        spacing: 16

                        Text {
                            text: typeof memoryManager !== 'undefined'
                                  ? "Conversations: " + memoryManager.conversationCount
                                  : "Conversations: 0"
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 12
                            color: "#A0A0A0"
                        }

                        Text {
                            text: typeof memoryManager !== 'undefined'
                                  ? "Souvenirs: " + memoryManager.memoryCount
                                  : "Souvenirs: 0"
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 12
                            color: "#A0A0A0"
                        }
                    }

                    // Semantic memory toggle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Mémoire sémantique (FAISS)"
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 12
                            color: "#A0A0A0"
                        }

                        Switch {
                            id: semanticToggle
                            checked: typeof configManager !== 'undefined'
                                     ? configManager.getBool("Memory", "semantic_enabled", true) : true
                            onToggled: {
                                if (typeof configManager !== 'undefined')
                                    configManager.setUserValue("Memory", "semantic_enabled",
                                                               checked ? "true" : "false")
                            }
                        }
                    }
                }

                // Séparateur
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#3C3C3C"
                }

                // ── Section : VAD & DSP ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "VAD & DSP"
                        font.family: "Cascadia Code, Fira Code, Consolas"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#E0E0E0"
                    }

                    // VAD Backend selector
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "vad.backend"
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 12
                            color: "#A0A0A0"
                        }

                        ComboBox {
                            id: vadBackendCombo
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            model: ["builtin", "silero", "hybrid"]

                            Component.onCompleted: {
                                var val = typeof configManager !== 'undefined'
                                          ? configManager.getVADBackend() : "builtin"
                                currentIndex = model.indexOf(val)
                                if (currentIndex < 0) currentIndex = 0
                            }

                            onActivated: {
                                if (typeof configManager !== 'undefined')
                                    configManager.setUserValue("VAD", "backend", currentText)
                            }

                            background: Rectangle {
                                radius: 2
                                color: "#3C3C3C"
                                border.color: vadBackendCombo.activeFocus ? "#007ACC" : "transparent"
                            }
                            contentItem: Text {
                                leftPadding: 8
                                text: vadBackendCombo.displayText
                                font.family: "Cascadia Code, Fira Code, Consolas"
                                font.pixelSize: 13
                                color: "#E0E0E0"
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    // Noise reduction toggle + slider
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Réduction de bruit DSP"
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 12
                            color: "#A0A0A0"
                        }

                        Switch {
                            id: noiseReductionToggle
                            checked: true
                            onToggled: {
                                if (typeof configManager !== 'undefined')
                                    configManager.setUserValue("DSP", "noise_reduction_enabled",
                                                               checked ? "true" : "false")
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        visible: noiseReductionToggle.checked

                        Text {
                            text: "dsp.noiseReductionStrength: " + dspNoiseSlider.value.toFixed(2)
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 12
                            color: "#A0A0A0"
                        }

                        Slider {
                            id: dspNoiseSlider
                            Layout.fillWidth: true
                            from: 0.0
                            to: 1.0
                            value: 0.7
                            stepSize: 0.05
                            onMoved: {
                                if (typeof configManager !== 'undefined')
                                    configManager.setUserValue("DSP", "noise_reduction_strength",
                                                               value.toFixed(2))
                            }
                        }
                    }
                }

                // Séparateur
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#3C3C3C"
                }

                // ── Section : WakeWord ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Wake Word"
                        font.family: "Cascadia Code, Fira Code, Consolas"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#E0E0E0"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Détection neuronale (OpenWakeWord)"
                            font.family: "Cascadia Code, Fira Code, Consolas"
                            font.pixelSize: 12
                            color: "#A0A0A0"
                        }

                        Switch {
                            id: neuralWakewordToggle
                            checked: typeof configManager !== 'undefined'
                                     ? configManager.getBool("WakeWord", "neural_enabled", false) : false
                            onToggled: {
                                if (typeof configManager !== 'undefined')
                                    configManager.setUserValue("WakeWord", "neural_enabled",
                                                               checked ? "true" : "false")
                            }
                        }
                    }
                }

                // Séparateur
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#3C3C3C"
                }

                // ── Section : Chat ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Chat"
                        font.family: "Cascadia Code, Fira Code, Consolas"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#E0E0E0"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 32
                            radius: 2
                            color: "#3C3C3C"
                            border.color: chatInput.activeFocus ? "#007ACC" : "transparent"

                            TextInput {
                                id: chatInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: "Cascadia Code, Fira Code, Consolas"
                                font.pixelSize: 13
                                color: "#E0E0E0"
                                clip: true

                                property string placeholderText: "Tapez un message..."
                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    font: chatInput.font
                                    color: "#606060"
                                    text: chatInput.placeholderText
                                    visible: !chatInput.text && !chatInput.activeFocus
                                }

                                Keys.onReturnPressed: sendChatBtn.clicked()
                                Keys.onEnterPressed: sendChatBtn.clicked()
                            }
                        }

                        Rectangle {
                            id: sendChatBtn
                            width: 32
                            height: 32
                            radius: 2
                            color: sendChatMa.containsPress ? "#005A9E" : "#007ACC"

                            signal clicked()

                            Text {
                                anchors.centerIn: parent
                                text: "▶"
                                font.pixelSize: 14
                                color: "white"
                            }

                            MouseArea {
                                id: sendChatMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    parent.clicked()
                                    var msg = chatInput.text.trim()
                                    if (msg.length > 0 && typeof assistantManager !== 'undefined') {
                                        assistantManager.processTextCommand(msg)
                                        chatInput.text = ""
                                    }
                                }
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: 20 }
            }
        }
    }
}

