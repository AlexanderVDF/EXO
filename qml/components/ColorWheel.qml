import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

// Composant ColorWheel - Roue des couleurs interactive avec génération de palettes
Item {
    id: colorWheel
    
    property real hue: 0        // 0-360
    property real saturation: 1  // 0-1
    property real lightness: 0.5 // 0-1
    property color selectedColor: Qt.hsla(hue/360, saturation, lightness, 1)
    property string paletteMode: "analogous" // analogous, complementary, triadic, tetradic, monochromatic, split-complementary
    property var generatedPalette: []
    
    signal colorChanged(color newColor)
    signal paletteGenerated(var colors)
    
    width: 280
    height: 350
    
    // Fond de la roue des couleurs
    Canvas {
        id: wheelCanvas
        anchors.fill: parent
        
        property real centerX: width / 2
        property real centerY: height / 2
        property real radius: Math.min(width, height) / 2 - 10
        
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            
            // Dessiner la roue des couleurs avec optimisation
            for (var angle = 0; angle < 360; angle += 3) { // Réduire la précision pour les performances
                for (var r = 0; r < radius; r += 3) {
                    var sat = r / radius;
                    var hueVal = angle;
                    var color = Qt.hsla(hueVal/360, sat, colorWheel.lightness, 1);
                    
                    ctx.fillStyle = color;
                    ctx.fillRect(
                        centerX + r * Math.cos(angle * Math.PI / 180) - 1.5,
                        centerY + r * Math.sin(angle * Math.PI / 180) - 1.5,
                        3, 3
                    );
                }
            }
        }
        
        // Redessiner automatiquement quand la luminosité change
        Connections {
            target: colorWheel
            function onLightnessChanged() {
                wheelCanvas.requestPaint();
            }
        }
        
        MouseArea {
            anchors.fill: parent
            
            property bool isUpdating: false
            
            function updateColor(mouseX, mouseY) {
                if (isUpdating) return;
                isUpdating = true;
                
                var centerX = parent.centerX;
                var centerY = parent.centerY;
                var dx = mouseX - centerX;
                var dy = mouseY - centerY;
                var distance = Math.sqrt(dx * dx + dy * dy);
                var angle = Math.atan2(dy, dx) * 180 / Math.PI;
                
                if (angle < 0) angle += 360;
                if (distance > parent.radius) distance = parent.radius;
                
                colorWheel.hue = angle;
                colorWheel.saturation = Math.min(distance / parent.radius, 1);
                
                // Émettre le signal SANS redessiner (sera fait par la propriété binding)
                colorWheel.colorChanged(colorWheel.selectedColor);
                
                isUpdating = false;
            }
            
            onPressed: updateColor(mouseX, mouseY)
            onPositionChanged: {
                if (pressed) {
                    updateColor(mouseX, mouseY);
                }
            }
        }
    }
    
    // Curseur de sélection
    Rectangle {
        id: cursor
        width: 12
        height: 12
        radius: 6
        color: "white"
        border.color: "black"
        border.width: 2
        
        function updatePosition() {
            var cursorX = wheelCanvas.centerX + (colorWheel.saturation * wheelCanvas.radius) * Math.cos(colorWheel.hue * Math.PI / 180);
            var cursorY = wheelCanvas.centerY + (colorWheel.saturation * wheelCanvas.radius) * Math.sin(colorWheel.hue * Math.PI / 180);
            x = cursorX - width/2;
            y = cursorY - height/2;
        }
        
        Component.onCompleted: updatePosition()
    }
    
    // Slider pour la luminosité
    Rectangle {
        id: lightnessSlider
        anchors.top: parent.bottom
        anchors.topMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.8
        height: 20
        radius: 10
        
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "black" }
            GradientStop { position: 0.5; color: Qt.hsla(colorWheel.hue/360, colorWheel.saturation, 0.5, 1) }
            GradientStop { position: 1.0; color: "white" }
        }
        
        Rectangle {
            id: lightnessHandle
            width: 16
            height: 16
            radius: 8
            color: "white"
            border.color: "black"
            border.width: 2
            y: (parent.height - height) / 2
            x: colorWheel.lightness * (parent.width - width)
            
            MouseArea {
                anchors.fill: parent
                drag.target: parent
                drag.axis: Drag.XAxis
                drag.minimumX: 0
                drag.maximumX: lightnessSlider.width - parent.width
                
                property bool isUpdating: false
                
                onPositionChanged: {
                    if (drag.active && !isUpdating) {
                        isUpdating = true;
                        colorWheel.lightness = parent.x / (lightnessSlider.width - parent.width);
                        // Le Canvas se redessine automatiquement via la Connections
                        colorWheel.colorChanged(colorWheel.selectedColor);
                        isUpdating = false;
                    }
                }
                
                onPressed: {
                    if (!isUpdating) {
                        isUpdating = true;
                        // Permettre aussi de cliquer directement sur le slider
                        parent.x = Math.max(0, Math.min(mouseX - parent.width/2, lightnessSlider.width - parent.width));
                        colorWheel.lightness = parent.x / (lightnessSlider.width - parent.width);
                        colorWheel.colorChanged(colorWheel.selectedColor);
                        isUpdating = false;
                    }
                }
            }
        }
    }
    
    // Aperçu de la couleur sélectionnée
    Rectangle {
        id: colorPreview
        anchors.top: lightnessSlider.bottom
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        width: 80
        height: 30
        radius: 6
        color: colorWheel.selectedColor
        border.color: "#333"
        border.width: 1
    }
    
    // Valeur hexadécimale
    Text {
        anchors.top: colorPreview.bottom
        anchors.topMargin: 5
        anchors.horizontalCenter: parent.horizontalCenter
        text: colorWheel.selectedColor.toString().toUpperCase()
        color: "white"
        font.pixelSize: 12
        font.family: "Consolas, monospace"
    }
    
    // Le sélecteur de mode et la palette sont maintenant dans ThemeEditor (troisième colonne)
    
    // Fonction de génération de palette
    function generatePalette() {
        var baseHue = colorWheel.hue;
        var baseSat = colorWheel.saturation;
        var baseLightness = colorWheel.lightness;
        var colors = [];
        
        switch(paletteMode) {
            case "analogous":
                // Couleurs adjacentes (+/- 30°)
                colors = [
                    Qt.hsla((baseHue - 30) / 360, baseSat, baseLightness, 1),
                    Qt.hsla(baseHue / 360, baseSat, baseLightness, 1),
                    Qt.hsla((baseHue + 30) / 360, baseSat, baseLightness, 1),
                    Qt.hsla((baseHue + 60) / 360, baseSat, baseLightness, 1)
                ];
                break;
                
            case "complementary":
                // Couleur opposée (180°)
                colors = [
                    Qt.hsla(baseHue / 360, baseSat, baseLightness, 1),
                    Qt.hsla((baseHue + 180) % 360 / 360, baseSat, baseLightness, 1)
                ];
                break;
                
            case "triadic":
                // Trois couleurs équidistantes (120°)
                colors = [
                    Qt.hsla(baseHue / 360, baseSat, baseLightness, 1),
                    Qt.hsla((baseHue + 120) % 360 / 360, baseSat, baseLightness, 1),
                    Qt.hsla((baseHue + 240) % 360 / 360, baseSat, baseLightness, 1)
                ];
                break;
                
            case "tetradic":
                // Quatre couleurs (90°)
                colors = [
                    Qt.hsla(baseHue / 360, baseSat, baseLightness, 1),
                    Qt.hsla((baseHue + 90) % 360 / 360, baseSat, baseLightness, 1),
                    Qt.hsla((baseHue + 180) % 360 / 360, baseSat, baseLightness, 1),
                    Qt.hsla((baseHue + 270) % 360 / 360, baseSat, baseLightness, 1)
                ];
                break;
                
            case "monochromatic":
                // Variations de luminosité
                colors = [
                    Qt.hsla(baseHue / 360, baseSat, 0.2, 1),
                    Qt.hsla(baseHue / 360, baseSat, 0.4, 1),
                    Qt.hsla(baseHue / 360, baseSat, 0.6, 1),
                    Qt.hsla(baseHue / 360, baseSat, 0.8, 1)
                ];
                break;
                
            case "split-complementary":
                // Complémentaire divisée (150° et 210°)
                colors = [
                    Qt.hsla(baseHue / 360, baseSat, baseLightness, 1),
                    Qt.hsla((baseHue + 150) % 360 / 360, baseSat, baseLightness, 1),
                    Qt.hsla((baseHue + 210) % 360 / 360, baseSat, baseLightness, 1)
                ];
                break;
        }
        
        generatedPalette = colors;
        paletteGenerated(colors);
    }
    
    function refreshDisplay() {
        // Utilisez un timer pour éviter trop de repaints
        refreshTimer.restart();
    }
    
    Timer {
        id: refreshTimer
        interval: 50
        onTriggered: {
            wheelCanvas.requestPaint();
            generatePalette();
        }
    }
    
    // Mise à jour automatique du curseur ET de la palette
    onHueChanged: {
        cursor.updatePosition();
        generatePalette();
    }
    onSaturationChanged: {
        cursor.updatePosition();
        generatePalette();
    }
    onLightnessChanged: {
        generatePalette();
    }
    onPaletteModeChanged: {
        generatePalette();
    }
    
    Component.onCompleted: {
        generatePalette();
    }
}