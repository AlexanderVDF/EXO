import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// ═══════════════════════════════════════════════════════
//  ReseauPage — Carte réseau local (Domotique v1)
//  Canvas de visualisation des nœuds et liens réseau
// ═══════════════════════════════════════════════════════

Item {
    id: root

    // ── Données injectées depuis MainWindow ──
    property var nodes: []       // [{mac, ip, vendor, name, type, online}]
    property var links: []       // [{from_id, to_id, type}]
    property bool scanning: false

    signal scanRequested()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing12
        spacing: Theme.spacing12

        // ── En-tête ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing8

            Text {
                text: "📶  Réseau"
                font.pixelSize: Theme.fontXL
                font.weight: Font.Bold
                color: Theme.textPrimary
            }

            Text {
                text: root.nodes.length + " nœuds"
                font.pixelSize: Theme.fontSM
                color: Theme.textMuted
                Layout.alignment: Qt.AlignBottom
            }

            Item { Layout.fillWidth: true }

            // Scan button
            Rectangle {
                width: scanLabel.implicitWidth + 28
                height: 34
                radius: Theme.radius8
                color: root.scanning ? Theme.bgActive : Theme.accent
                border.color: Theme.border

                Text {
                    id: scanLabel
                    anchors.centerIn: parent
                    text: root.scanning ? "Scan…" : "🔍 Scanner"
                    font.pixelSize: Theme.fontSM
                    color: "#FFF"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: root.scanning ? Qt.WaitCursor : Qt.PointingHandCursor
                    enabled: !root.scanning
                    onClicked: root.scanRequested()
                }
            }
        }

        // ── Zone graphe réseau ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radius12
            color: Theme.bgSecondary
            border.color: Theme.border
            clip: true

            Canvas {
                id: networkCanvas
                anchors.fill: parent
                anchors.margins: 20

                property var nodePositions: ({})

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var w = width;
                    var h = height;

                    if (root.nodes.length === 0) {
                        ctx.fillStyle = Theme.textMuted.toString();
                        ctx.font = "14px sans-serif";
                        ctx.textAlign = "center";
                        ctx.fillText("Cliquer « Scanner » pour détecter les appareils", w / 2, h / 2);
                        return;
                    }

                    // Compute positions (circular layout centré sur le routeur)
                    var positions = {};
                    var gatewayIdx = -1;
                    for (var i = 0; i < root.nodes.length; i++) {
                        if (root.nodes[i].type === "router") { gatewayIdx = i; break; }
                    }

                    var cx = w / 2;
                    var cy = h / 2;
                    var radius = Math.min(w, h) * 0.38;

                    // Place gateway at center
                    if (gatewayIdx >= 0) {
                        var gw = root.nodes[gatewayIdx];
                        positions[gw.mac || gw.ip] = { x: cx, y: cy };
                    }

                    // Place others in circle
                    var otherNodes = [];
                    for (var j = 0; j < root.nodes.length; j++) {
                        if (j !== gatewayIdx) otherNodes.push(root.nodes[j]);
                    }
                    for (var k = 0; k < otherNodes.length; k++) {
                        var angle = (2 * Math.PI * k) / otherNodes.length - Math.PI / 2;
                        var nx = cx + radius * Math.cos(angle);
                        var ny = cy + radius * Math.sin(angle);
                        positions[otherNodes[k].mac || otherNodes[k].ip] = { x: nx, y: ny };
                    }

                    nodePositions = positions;

                    // Draw links
                    for (var li = 0; li < root.links.length; li++) {
                        var link = root.links[li];
                        var p1 = positions[link.from_id];
                        var p2 = positions[link.to_id];
                        if (!p1 || !p2) continue;

                        ctx.beginPath();
                        ctx.moveTo(p1.x, p1.y);
                        ctx.lineTo(p2.x, p2.y);
                        ctx.strokeStyle = link.type === "eth"
                            ? Theme.info.toString()
                            : Theme.textMuted.toString();
                        ctx.lineWidth = link.type === "eth" ? 2 : 1;
                        ctx.setLineDash(link.type === "wifi" ? [4, 4] : []);
                        ctx.stroke();
                        ctx.setLineDash([]);
                    }

                    // Draw nodes
                    for (var ni = 0; ni < root.nodes.length; ni++) {
                        var node = root.nodes[ni];
                        var pos = positions[node.mac || node.ip];
                        if (!pos) continue;

                        var nodeIcons = {
                            "router": "📶", "pc": "💻", "phone": "📱",
                            "tv": "📺", "speaker": "🔈", "camera": "📷",
                            "nas": "💾", "unknown": "❓"
                        };
                        var icon = nodeIcons[node.type] || "❓";
                        var isGateway = node.type === "router";

                        // Node circle
                        ctx.beginPath();
                        var nodeRadius = isGateway ? 28 : 20;
                        ctx.arc(pos.x, pos.y, nodeRadius, 0, 2 * Math.PI);
                        ctx.fillStyle = node.online
                            ? (isGateway ? Theme.accent.toString() : Theme.bgElevated.toString())
                            : Theme.errorDim.toString();
                        ctx.fill();
                        ctx.strokeStyle = node.online ? Theme.border.toString() : Theme.error.toString();
                        ctx.lineWidth = 1.5;
                        ctx.stroke();

                        // Icon
                        ctx.fillStyle = "#FFF";
                        ctx.font = (isGateway ? "18px" : "14px") + " sans-serif";
                        ctx.textAlign = "center";
                        ctx.textBaseline = "middle";
                        ctx.fillText(icon, pos.x, pos.y);

                        // Label below
                        var label = node.name || node.ip || node.mac;
                        if (label.length > 18) label = label.substring(0, 16) + "…";
                        ctx.fillStyle = Theme.textSecondary.toString();
                        ctx.font = "11px sans-serif";
                        ctx.fillText(label, pos.x, pos.y + nodeRadius + 14);
                    }
                }
            }

            // Redraw when data changes
            Connections {
                target: root
                function onNodesChanged() { networkCanvas.requestPaint(); }
                function onLinksChanged() { networkCanvas.requestPaint(); }
            }
        }

        // ── Tableau récapitulatif ──
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            clip: true

            ListView {
                model: root.nodes
                spacing: 2

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 32
                    color: index % 2 === 0 ? Theme.bgSecondary : Theme.bgPrimary
                    radius: 2

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacing8
                        anchors.rightMargin: Theme.spacing8
                        spacing: Theme.spacing12

                        // Online dot
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: modelData.online ? Theme.success : Theme.error
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: modelData.name || "—"
                            font.pixelSize: Theme.fontSM
                            color: Theme.textPrimary
                            Layout.preferredWidth: 160
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.ip || "—"
                            font.pixelSize: Theme.fontSM
                            color: Theme.textSecondary
                            Layout.preferredWidth: 120
                        }
                        Text {
                            text: modelData.mac || "—"
                            font.pixelSize: Theme.fontXS
                            color: Theme.textMuted
                            Layout.preferredWidth: 140
                        }
                        Text {
                            text: modelData.vendor || ""
                            font.pixelSize: Theme.fontXS
                            color: Theme.textMuted
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.type
                            font.pixelSize: Theme.fontXS
                            color: Theme.accent
                            Layout.preferredWidth: 60
                        }
                    }
                }
            }
        }
    }
}
