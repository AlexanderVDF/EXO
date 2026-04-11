import QtQuick
import "../theme"

// ═══════════════════════════════════════════════════════
//  CameraCone — cône de vision caméra avec ShaderEffect
//
//  Affiche un cône semi-transparent représentant le
//  champ de vue d'une caméra sur le plan.
//  Paramètres : angle d'ouverture, portée, couleur, rotation.
// ═══════════════════════════════════════════════════════

Item {
    id: cone
    width: range * 2
    height: range * 2

    // ── Propriétés configurables ──
    property real coneAngle: 90.0       // angle d'ouverture en degrés
    property real range: 100.0          // portée en px
    property color coneColor: "#4EC9B0" // couleur du cône
    property real coneOpacity: 0.25     // opacité de remplissage
    property real borderOpacity: 0.6    // opacité du contour
    property real coneRotation: 0.0     // orientation en degrés (0 = droite)

    // Le cône est dessiné dans un Canvas pour compatibilité maximale
    // (ShaderEffect nécessite OpenGL, Canvas fonctionne partout)
    Canvas {
        id: coneCanvas
        anchors.fill: parent
        antialiasing: true
        renderStrategy: Canvas.Threaded

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var cx = width / 2
            var cy = height / 2
            var r  = cone.range
            var halfAngle = (cone.coneAngle / 2) * (Math.PI / 180)
            var baseAngle = cone.coneRotation * (Math.PI / 180)
            var startAngle = baseAngle - halfAngle
            var endAngle   = baseAngle + halfAngle

            // ── Remplissage du cône ──
            ctx.beginPath()
            ctx.moveTo(cx, cy)
            ctx.arc(cx, cy, r, startAngle, endAngle, false)
            ctx.closePath()

            var col = cone.coneColor
            ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, cone.coneOpacity)
            ctx.fill()

            // ── Contour du cône ──
            ctx.beginPath()
            ctx.moveTo(cx, cy)
            ctx.lineTo(cx + r * Math.cos(startAngle),
                       cy + r * Math.sin(startAngle))
            ctx.arc(cx, cy, r, startAngle, endAngle, false)
            ctx.lineTo(cx, cy)
            ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, cone.borderOpacity)
            ctx.lineWidth = 1.5
            ctx.stroke()

            // ── Lignes radiales graduées (optionnel, pour le style) ──
            var steps = 3
            ctx.setLineDash([2, 4])
            ctx.lineWidth = 0.5
            ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, cone.borderOpacity * 0.4)
            for (var i = 1; i <= steps; ++i) {
                var stepR = r * (i / (steps + 1))
                ctx.beginPath()
                ctx.arc(cx, cy, stepR, startAngle, endAngle, false)
                ctx.stroke()
            }
            ctx.setLineDash([])
        }

        // Repaint on parameter change
        Connections {
            target: cone
            function onConeAngleChanged()    { coneCanvas.requestPaint() }
            function onRangeChanged()        { coneCanvas.requestPaint() }
            function onConeColorChanged()    { coneCanvas.requestPaint() }
            function onConeOpacityChanged()  { coneCanvas.requestPaint() }
            function onBorderOpacityChanged(){ coneCanvas.requestPaint() }
            function onConeRotationChanged() { coneCanvas.requestPaint() }
        }
    }

    // ── Point central (camera dot) ──
    Rectangle {
        width: 6; height: 6
        radius: 3
        color: cone.coneColor
        anchors.centerIn: parent
    }

    // ── Petit label d'angle (debug/info) ──
    // Décommenter si voulu :
    // Text {
    //     anchors.top: parent.bottom
    //     anchors.horizontalCenter: parent.horizontalCenter
    //     text: Math.round(cone.coneAngle) + "° / " + Math.round(cone.range) + "px"
    //     font.pixelSize: 9
    //     color: cone.coneColor
    // }

    Component.onCompleted: coneCanvas.requestPaint()
}
