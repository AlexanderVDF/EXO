import QtQuick 2.15

Item {
    id: root

    property real audioLevel: 0.0  // 0.0 → 1.0
    property bool active: false
    property color lineColor: "#007ACC"
    property real lineWidth: 1.5
    property int historySize: 200
    property real preferredHeight: 100

    // Time uniform for GPU animation
    property real iTime: 0.0

    // Smoothed audio level (exponential moving average)
    property real smoothLevel: 0.0

    onAudioLevelChanged: {
        smoothLevel = smoothLevel * 0.7 + audioLevel * 0.3
    }

    implicitHeight: preferredHeight

    // ── GPU-accelerated waveform via ShaderEffect ──
    ShaderEffect {
        id: waveShader
        anchors.fill: parent

        // Uniforms passed to GLSL
        property real iTime: root.iTime
        property real audioLevel: root.smoothLevel
        property real isActive: root.active ? 1.0 : 0.0
        property color lineColor: root.lineColor
        property real aspect: width / Math.max(height, 1.0)

        fragmentShader: "
            varying highp vec2 qt_TexCoord0;
            uniform highp float iTime;
            uniform highp float audioLevel;
            uniform highp float isActive;
            uniform highp vec4 lineColor;
            uniform highp float aspect;

            void main() {
                highp vec2 uv = qt_TexCoord0;
                highp float x = uv.x;
                highp float y = uv.y;
                highp float midY = 0.5;

                // Idle: faint center line
                if (isActive < 0.5) {
                    highp float dist = abs(y - midY);
                    highp float alpha = smoothstep(0.01, 0.0, dist) * 0.2;
                    gl_FragColor = vec4(lineColor.rgb, alpha);
                    return;
                }

                // Active: multi-wave oscillation on GPU
                highp float amplitude = audioLevel * 0.38;
                highp float wave = 0.0;

                // Sum 3 sine waves at different frequencies/phases for organic look
                wave += sin(x * 25.0 + iTime * 3.0) * amplitude;
                wave += sin(x * 15.0 - iTime * 2.1 + 1.5) * amplitude * 0.6;
                wave += sin(x * 40.0 + iTime * 4.5 + 0.8) * amplitude * 0.3;

                highp float waveY = midY + wave;
                highp float dist = abs(y - waveY);

                // Anti-aliased line with glow
                highp float lineThickness = 0.006;
                highp float glow = 0.03;

                highp float core = smoothstep(lineThickness, 0.0, dist);
                highp float glowAlpha = smoothstep(glow, 0.0, dist) * 0.3;

                highp float alpha = core + glowAlpha;
                alpha *= (0.5 + audioLevel * 0.5);

                gl_FragColor = vec4(lineColor.rgb * alpha, alpha);
            }
        "
    }

    // ── Fallback Canvas renderer (if ShaderEffect unavailable) ──
    Canvas {
        id: fallbackCanvas
        anchors.fill: parent
        visible: !waveShader.visible
        renderStrategy: Canvas.Cooperative

        onPaint: {
            var ctx = getContext("2d")
            var w = width
            var h = height
            var midY = h / 2

            ctx.clearRect(0, 0, w, h)

            if (!root.active) {
                ctx.strokeStyle = Qt.rgba(0, 0.478, 0.8, 0.2)
                ctx.lineWidth = root.lineWidth
                ctx.beginPath()
                ctx.moveTo(0, midY)
                ctx.lineTo(w, midY)
                ctx.stroke()
                return
            }

            ctx.strokeStyle = root.lineColor
            ctx.lineWidth = root.lineWidth
            ctx.lineJoin = "round"
            ctx.lineCap = "round"
            ctx.beginPath()

            var steps = Math.min(w, 200)
            for (var i = 0; i <= steps; i++) {
                var x = (i / steps) * w
                var nx = i / steps
                var amplitude = root.smoothLevel * (h * 0.38)
                var wave = Math.sin(nx * 25.0 + root.iTime * 3.0) * amplitude
                         + Math.sin(nx * 15.0 - root.iTime * 2.1 + 1.5) * amplitude * 0.6
                         + Math.sin(nx * 40.0 + root.iTime * 4.5 + 0.8) * amplitude * 0.3
                var y = midY + wave
                if (i === 0) ctx.moveTo(x, y)
                else ctx.lineTo(x, y)
            }
            ctx.stroke()
        }
    }

    // Animation timer — 60 FPS for GPU shader, 30 FPS fallback
    Timer {
        interval: waveShader.visible ? 16 : 33
        running: root.active
        repeat: true
        onTriggered: {
            root.iTime += interval / 1000.0
            if (!waveShader.visible)
                fallbackCanvas.requestPaint()
        }
    }
}
