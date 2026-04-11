import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  MemoryInspector — Vue mémoire sémantique EXO
//  Vecteurs FAISS proches, mémoire court/long terme,
//  score de pertinence
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: Theme.bgPrimary

    // ── Données mémoire ──
    property var shortTermMemory: []      // Dernières interactions
    property var longTermMemory: []       // Faits stockés FAISS
    property var nearestVectors: []       // Résultats FAISS proches
    property string lastQuery: ""
    property int totalVectors: 0

    // ── Tab active ──
    property int activeTab: 0  // 0=Court terme, 1=Long terme, 2=Vecteurs FAISS

    // ── Connexions ──
    Connections {
        target: typeof pipelineEventBus !== 'undefined' ? pipelineEventBus : null

        function onEventEmitted(event) {
            if ((event.module || "") !== "memory") return

            if (event.event_type === "memory_store") {
                var stm = root.shortTermMemory.slice()
                stm.unshift({
                    text: event.text || "",
                    timestamp: event.timestamp || Qt.formatTime(new Date(), "HH:mm:ss"),
                    type: "user",
                    score: 1.0
                })
                if (stm.length > 50) stm.length = 50
                root.shortTermMemory = stm
            }

            if (event.event_type === "memory_recall") {
                var results = event.results || []
                root.nearestVectors = results
                root.lastQuery = event.query || ""
            }

            if (event.event_type === "memory_stats") {
                root.totalVectors = event.total_vectors || 0
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing8
        spacing: Theme.spacing8

        // ── Header ──
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "MEMORY INSPECTOR"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontMicro
                font.weight: Font.Bold
                color: Theme.textAccent
                font.letterSpacing: 1.5
            }

            Item { Layout.fillWidth: true }

            // Stats
            Rectangle {
                width: vecCountLabel.implicitWidth + Theme.spacing12
                height: 22
                radius: Theme.radiusSmall
                color: Theme.bgElevated

                Text {
                    id: vecCountLabel
                    anchors.centerIn: parent
                    text: root.totalVectors + " vecteurs"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontTiny
                    color: Theme.textMuted
                }
            }
        }

        // ── Tab Bar ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: [
                    { label: "Court terme", idx: 0 },
                    { label: "Long terme",  idx: 1 },
                    { label: "FAISS",       idx: 2 }
                ]

                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    color: root.activeTab === modelData.idx ? Theme.bgElevated : "transparent"

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 2
                        color: root.activeTab === modelData.idx ? Theme.accent : Theme.border
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        color: root.activeTab === modelData.idx ? Theme.textPrimary : Theme.textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = modelData.idx
                    }
                }
            }
        }

        // ── Contenu ──
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.activeTab

            // ── Tab 0: Court terme ──
            ListView {
                id: stmList
                clip: true
                spacing: Theme.spacing4
                boundsBehavior: Flickable.StopAtBounds
                model: root.shortTermMemory.length

                delegate: Rectangle {
                    width: stmList.width
                    height: stmCol.implicitHeight + Theme.spacing12
                    radius: Theme.radiusSmall
                    color: Theme.bgElevated

                    readonly property var item: root.shortTermMemory[index] || {}

                    ColumnLayout {
                        id: stmCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacing8
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true

                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: item.type === "user" ? Theme.accent : Theme.success
                            }

                            Text {
                                text: item.timestamp || ""
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontTiny
                                color: Theme.textMuted
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: ((item.score || 0) * 100).toFixed(0) + "%"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontTiny
                                color: (item.score || 0) > 0.8 ? Theme.success : Theme.textMuted
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: item.text || ""
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            color: Theme.textPrimary
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }

                // Empty state
                Text {
                    anchors.centerIn: parent
                    text: "Aucune interaction récente"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    color: Theme.textMuted
                    visible: root.shortTermMemory.length === 0
                }
            }

            // ── Tab 1: Long terme ──
            ListView {
                id: ltmList
                clip: true
                spacing: Theme.spacing4
                boundsBehavior: Flickable.StopAtBounds
                model: root.longTermMemory.length

                delegate: Rectangle {
                    width: ltmList.width
                    height: ltmCol.implicitHeight + Theme.spacing12
                    radius: Theme.radiusSmall
                    color: Theme.bgElevated

                    readonly property var item: root.longTermMemory[index] || {}

                    ColumnLayout {
                        id: ltmCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacing8
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "📌"
                                font.pixelSize: 12
                            }

                            Text {
                                text: item.category || "fact"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontTiny
                                color: Theme.info
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: item.created || ""
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontTiny
                                color: Theme.textMuted
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: item.text || ""
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            color: Theme.textPrimary
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Aucun fait mémorisé"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    color: Theme.textMuted
                    visible: root.longTermMemory.length === 0
                }
            }

            // ── Tab 2: Vecteurs FAISS ──
            ColumnLayout {
                spacing: Theme.spacing8

                // Query display
                Rectangle {
                    Layout.fillWidth: true
                    height: queryText.implicitHeight + Theme.spacing12
                    radius: Theme.radiusSmall
                    color: Theme.bgElevated
                    visible: root.lastQuery.length > 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacing6
                        spacing: Theme.spacing8

                        Text {
                            text: "🔍"
                            font.pixelSize: 14
                        }
                        Text {
                            id: queryText
                            Layout.fillWidth: true
                            text: root.lastQuery
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            color: Theme.textPrimary
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                ListView {
                    id: faissResults
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: Theme.spacing4
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.nearestVectors.length

                    delegate: Rectangle {
                        width: faissResults.width
                        height: faissCol.implicitHeight + Theme.spacing12
                        radius: Theme.radiusSmall
                        color: Theme.bgElevated

                        readonly property var item: root.nearestVectors[index] || {}

                        ColumnLayout {
                            id: faissCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.spacing8
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacing8

                                Text {
                                    text: "#" + (index + 1)
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontTiny
                                    font.weight: Font.Bold
                                    color: Theme.textMuted
                                }

                                // Score bar
                                Rectangle {
                                    width: 60; height: 6; radius: 3
                                    color: Theme.bgInput

                                    Rectangle {
                                        width: parent.width * Math.min(1, (item.score || 0))
                                        height: parent.height
                                        radius: 3
                                        color: (item.score || 0) > 0.8 ? Theme.success
                                             : (item.score || 0) > 0.5 ? Theme.warning
                                             : Theme.error
                                    }
                                }

                                Text {
                                    text: ((item.score || 0) * 100).toFixed(1) + "%"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontTiny
                                    font.weight: Font.Bold
                                    color: (item.score || 0) > 0.8 ? Theme.success
                                         : (item.score || 0) > 0.5 ? Theme.warning
                                         : Theme.error
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "d=" + (item.distance || 0).toFixed(3)
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontTiny
                                    color: Theme.textMuted
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: item.text || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                                color: Theme.textPrimary
                                wrapMode: Text.WordWrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Aucune recherche vectorielle récente"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    color: Theme.textMuted
                    visible: root.nearestVectors.length === 0 && root.lastQuery.length === 0
                }
            }
        }
    }
}
