import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  ScenariosPage — Gestion des scénarios (Domotique v2)
//  Liste, exécute et affiche les scénarios domotiques
// ═══════════════════════════════════════════════════════

Item {
    id: root

    // ── Données injectées depuis MainWindow ──
    property var scenarios: []     // [{name, description, builtin, run_count, last_run}]
    property string activeScenario: ""
    property bool running: false

    signal runScenario(string name)
    signal refreshRequested()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing12
        spacing: Theme.spacing12

        // ── En-tête ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing8

            Text {
                text: "🎬  Scénarios"
                font.pixelSize: Theme.fontXL
                font.weight: Font.Bold
                color: Theme.textPrimary
            }

            Text {
                text: root.scenarios.length + " disponibles"
                font.pixelSize: Theme.fontSM
                color: Theme.textMuted
                Layout.alignment: Qt.AlignBottom
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 36; height: 36
                radius: Theme.radius8
                color: refreshMa.containsMouse ? Theme.bgHover : "transparent"
                border.color: Theme.border
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "⟳"
                    font.pixelSize: 18
                    color: Theme.textSecondary
                }
                MouseArea {
                    id: refreshMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.refreshRequested()
                }
            }
        }

        // ── Scénarios prédéfinis ──
        Text {
            text: "Scénarios prédéfinis"
            font.pixelSize: Theme.fontMD
            font.weight: Font.DemiBold
            color: Theme.textSecondary
        }

        GridLayout {
            Layout.fillWidth: true
            columns: Math.max(1, Math.floor(parent.width / 280))
            columnSpacing: Theme.spacing12
            rowSpacing: Theme.spacing12

            Repeater {
                model: root.scenarios.filter(function(s) { return s.builtin; })

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 100
                    radius: Theme.radius12
                    color: Theme.bgElevated
                    border.color: root.activeScenario === modelData.name
                                  ? Theme.accent : Theme.border
                    border.width: root.activeScenario === modelData.name ? 2 : 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacing12
                        spacing: Theme.spacing4

                        RowLayout {
                            spacing: Theme.spacing8
                            Text {
                                text: {
                                    var icons = {
                                        "cinema": "🎬", "nuit": "🌙",
                                        "absence": "🔒", "reveil": "☀️",
                                        "securite": "🛡️", "eco": "🌿"
                                    };
                                    return icons[modelData.name] || "▶";
                                }
                                font.pixelSize: 24
                            }
                            ColumnLayout {
                                spacing: 0
                                Text {
                                    text: modelData.name.charAt(0).toUpperCase()
                                          + modelData.name.slice(1)
                                    font.pixelSize: Theme.fontMD
                                    font.weight: Font.DemiBold
                                    color: Theme.textPrimary
                                }
                                Text {
                                    text: modelData.description || ""
                                    font.pixelSize: Theme.fontXS
                                    color: Theme.textMuted
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            spacing: Theme.spacing8
                            Layout.fillWidth: true

                            Text {
                                text: modelData.run_count
                                      ? modelData.run_count + " exécution(s)"
                                      : "Jamais exécuté"
                                font.pixelSize: Theme.fontXS
                                color: Theme.textMuted
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: runLabel.implicitWidth + 20
                                height: 28
                                radius: Theme.radius8
                                color: runMa.containsMouse ? Theme.accent : Theme.bgActive
                                border.color: Theme.border

                                Text {
                                    id: runLabel
                                    anchors.centerIn: parent
                                    text: root.running && root.activeScenario === modelData.name
                                          ? "…" : "▶ Lancer"
                                    font.pixelSize: Theme.fontXS
                                    color: runMa.containsMouse ? "#FFF" : Theme.textSecondary
                                }
                                MouseArea {
                                    id: runMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !root.running
                                    onClicked: root.runScenario(modelData.name)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Scénarios personnalisés ──
        Text {
            text: "Scénarios personnalisés"
            font.pixelSize: Theme.fontMD
            font.weight: Font.DemiBold
            color: Theme.textSecondary
            visible: root.scenarios.some(function(s) { return !s.builtin; })
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.scenarios.filter(function(s) { return !s.builtin; })

            delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 48
                radius: Theme.radius8
                color: index % 2 === 0 ? Theme.bgSecondary : Theme.bgPrimary
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacing8
                    spacing: Theme.spacing12

                    Text {
                        text: "▶"
                        font.pixelSize: 16
                        color: Theme.accent
                    }
                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true
                        Text {
                            text: modelData.name
                            font.pixelSize: Theme.fontSM
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                        }
                        Text {
                            text: modelData.description || ""
                            font.pixelSize: Theme.fontXS
                            color: Theme.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    Rectangle {
                        width: customRunLabel.implicitWidth + 16
                        height: 26
                        radius: Theme.radius8
                        color: customRunMa.containsMouse ? Theme.accent : Theme.bgActive

                        Text {
                            id: customRunLabel
                            anchors.centerIn: parent
                            text: "Lancer"
                            font.pixelSize: Theme.fontXS
                            color: customRunMa.containsMouse ? "#FFF" : Theme.textSecondary
                        }
                        MouseArea {
                            id: customRunMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.running
                            onClicked: root.runScenario(modelData.name)
                        }
                    }
                }
            }
        }

        // ── Pied de page ──
        Text {
            text: root.running ? "⏳ Exécution en cours : " + root.activeScenario : ""
            font.pixelSize: Theme.fontSM
            color: Theme.warning
            visible: root.running
        }
    }
}
