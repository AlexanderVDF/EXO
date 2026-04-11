import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  SpatialDecisionPanel — Décisions et actions recommandées
//  Affiche les plans validés par le Supervisor et les actions
// ═══════════════════════════════════════════════════════

Rectangle {
    id: root
    color: "transparent"

    property var engine: null
    property var plans: engine ? engine.plans : []
    property var actions: engine ? engine.getRecommendedActions() : []

    readonly property var actionTypeLabels: [
        "Allumer", "Éteindre", "Ouvrir", "Fermer", "Ajuster",
        "Activer caméra", "Notifier", "Lancer scénario", "Demander humain", "Personnalisé"
    ]

    readonly property var actionTypeIcons: [
        "💡", "🌙", "🚪", "🔒", "⚙", "📷", "📨", "🎬", "👤", "🔧"
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // ── En-tête ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Label {
                text: "📋 Décisions"
                font.pixelSize: 14
                font.bold: true
                color: Theme.textPrimary
            }

            Item { Layout.fillWidth: true }

            Label {
                text: root.plans.length + " plan(s) · " + root.actions.length + " action(s)"
                font.pixelSize: 11
                color: Theme.textSecondary
            }
        }

        // ── Plans ──
        ListView {
            id: planList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 200)
            clip: true
            spacing: 6
            model: root.plans

            delegate: Rectangle {
                width: planList.width
                height: planCol.implicitHeight + 16
                radius: 4
                color: Theme.cardBackground

                ColumnLayout {
                    id: planCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    spacing: 4

                    // Titre du plan
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Label {
                            text: "📋"
                            font.pixelSize: 13
                        }

                        Label {
                            Layout.fillWidth: true
                            text: modelData.goalDescription || "Plan"
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }

                        Label {
                            text: (modelData.actionCount || 0) + " action(s)"
                            font.pixelSize: 10
                            color: Theme.textSecondary
                        }
                    }

                    // Confiance + explication
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Label {
                            text: "🎯 " + Math.round((modelData.overallConfidence || 0) * 100) + "%"
                            font.pixelSize: 10
                            color: Theme.textSecondary
                        }

                        Label {
                            Layout.fillWidth: true
                            text: modelData.explanation || ""
                            font.pixelSize: 10
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // ── Séparateur ──
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // ── Actions recommandées ──
        Label {
            text: "⚡ Actions recommandées"
            font.pixelSize: 12
            font.bold: true
            color: Theme.textPrimary
        }

        ListView {
            id: actionList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 3
            model: root.actions

            delegate: Rectangle {
                width: actionList.width
                height: 36
                radius: 3
                color: Theme.cardBackground

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    Label {
                        text: root.actionTypeIcons[modelData.type] || "🔧"
                        font.pixelSize: 14
                    }

                    Label {
                        Layout.fillWidth: true
                        text: modelData.description || ""
                        font.pixelSize: 11
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                    }

                    // Priorité
                    Rectangle {
                        width: prioLabel.implicitWidth + 8
                        height: 16
                        radius: 3
                        color: (modelData.priority || 0) >= 8 ? Qt.rgba(1, 0.3, 0.3, 0.15) :
                               (modelData.priority || 0) >= 5 ? Qt.rgba(1, 0.7, 0.3, 0.15) :
                                                                  Qt.rgba(0.3, 1, 0.5, 0.15)

                        Label {
                            id: prioLabel
                            anchors.centerIn: parent
                            text: "P" + (modelData.priority || 0)
                            font.pixelSize: 9
                            font.bold: true
                            color: (modelData.priority || 0) >= 8 ? Theme.error :
                                   (modelData.priority || 0) >= 5 ? Theme.warning : Theme.success
                        }
                    }

                    // Cible
                    Label {
                        text: modelData.targetId || ""
                        font.pixelSize: 9
                        color: Theme.textSecondary
                    }
                }
            }
        }

        // ── Vide ──
        Label {
            visible: root.plans.length === 0
            text: "Aucune décision en attente"
            font.pixelSize: 11
            font.italic: true
            color: Theme.textSecondary
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
