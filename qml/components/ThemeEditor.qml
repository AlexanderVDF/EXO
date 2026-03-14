import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

// Composant ThemeEditor - Éditeur de thème plein écran sans décoration
Rectangle {
    id: themeEditor
    
    // Visibilité basée sur isOpen au lieu de visible pour éviter les conflits
    visible: isOpen
    
    property var configManager: null
    property string editingTheme: ""
    property bool isNewTheme: false
    property bool isOpen: false
    
    signal themeCreated(string themeName, var colors)
    signal themeUpdated(string themeName, var colors)
    
    function open() {
        isOpen = true;
    }
    
    function close() {
        isOpen = false;
    }
    
    anchors.fill: parent
    z: 1000  // Au-dessus de tout
    
    // Background avec gradient
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#0F0F0F" }
        GradientStop { position: 1.0; color: "#1E1E1E" }
    }
    
    // Intercepter tous les clics pour éviter qu'ils passent en dessous
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }
    
    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth
        
        ColumnLayout {
            width: parent.parent.width - 40  // Largeur moins les marges
            spacing: 20
        
        // Barre de titre avec fermeture
        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            
            Text {
                text: isNewTheme ? "🎨 Créer un Nouveau Thème" : "🎨 Modifier le Thème"
                color: "#00BCD4"
                font.pixelSize: 24
                font.bold: true
            }
            
            Item { Layout.fillWidth: true }
            
            TextField {
                id: themeNameField
                Layout.preferredWidth: 250
                placeholderText: "Nom du thème..."
                Material.accent: "#00BCD4"
                text: editingTheme
                enabled: isNewTheme
                font.pixelSize: 14
            }
            
            CloseButton {
                buttonSize: 40
                useThemeColors: true
                onCloseRequested: themeEditor.close()
            }
        }
        
        // Sélection de couleur
        TabBar {
            id: colorTabs
            Layout.fillWidth: true
            Material.accent: "#00BCD4"
            
            TabButton { text: "Primaire"; property string colorKey: "primary" }
            TabButton { text: "Secondaire"; property string colorKey: "secondary" }
            TabButton { text: "Accent"; property string colorKey: "accent" }
            TabButton { text: "Arrière-plan"; property string colorKey: "background" }
            TabButton { text: "Surface"; property string colorKey: "surface" }
            TabButton { text: "Texte"; property string colorKey: "text" }
        }
        
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                id: currentColorLabel
                text: getCurrentColorName()
                color: "#00BCD4"
                font.pixelSize: 16
                font.bold: true
                Layout.fillWidth: true
            }
            
            Button {
                text: "📥"
                implicitWidth: 35
                implicitHeight: 25
                Material.background: "#333"
                font.pixelSize: 12
                ToolTip.text: "Charger la couleur de cet onglet dans la roue"
                ToolTip.visible: hovered
                
                onClicked: {
                    keepColorWheelPosition = false;
                    updateColorWheel();
                    keepColorWheelPosition = true;
                }
            }
            
            Button {
                text: "📤"
                implicitWidth: 35
                implicitHeight: 25
                Material.background: "#333"
                font.pixelSize: 12
                ToolTip.text: "Appliquer la couleur actuelle de la roue à cet onglet"
                ToolTip.visible: hovered
                
                onClicked: {
                    syncColorFromWheel();
                }
            }
        }
        
        // Contenu principal en 3 colonnes
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 400
            Layout.minimumHeight: 350
            spacing: 30
            
            // Colonne 1: Roue des couleurs (30%)
            ColumnLayout {
                Layout.preferredWidth: 300
                Layout.minimumWidth: 280
                Layout.maximumWidth: 320
                spacing: 15
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: "🎨 Sélecteur de Couleurs"
                        color: "#00BCD4"
                        font.pixelSize: 16
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    
                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        color: themeColors[getCurrentColorKey()]
                        border.color: "#666"
                        border.width: 1
                        
                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                        
                        ToolTip {
                            visible: mouseArea.containsMouse
                            text: "Couleur actuelle de l'onglet " + getCurrentColorName()
                        }
                    }
                }
                
                ColorWheel {
                    id: colorWheel
                    Layout.alignment: Qt.AlignHCenter
                    
                    onColorChanged: function(newColor) {
                        // La roue émet une nouvelle couleur, on met à jour l'onglet actuel
                        syncColorFromWheel();
                    }
                    
                    onPaletteGenerated: function(colors) {
                        // Forcer la mise à jour du modèle
                        generatedPaletteRepeater.model = [];
                        generatedPaletteRepeater.model = colors;
                    }
                    
                    Component.onCompleted: {
                        // Initialiser avec la première couleur
                        updateColorWheel();
                    }
                }
            }
            
            // Colonne 2: Aperçu du thème (40%)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 350
                spacing: 15
                
                Text {
                    text: "👁️ Aperçu du Thème"
                    color: "white"
                    font.pixelSize: 16
                    font.bold: true
                }
                
                Rectangle {
                    id: themePreview
                    Layout.fillWidth: true
                    Layout.preferredHeight: 280
                    Layout.minimumHeight: 250
                    radius: 8
                    color: themeColors["background"] || "#121212"
                    border.color: "#333"
                    border.width: 1
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 10
                        
                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            color: themeColors["surface"] || "#1E1E1E"
                            radius: 6
                            
                            Text {
                                anchors.centerIn: parent
                                text: "🎯 EXO Assistant"
                                color: themeColors["text"] || "#FFFFFF"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }
                        
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            Rectangle {
                                width: 70
                                height: 30
                                color: themeColors["primary"] || "#00BCD4"
                                radius: 4
                                Text {
                                    anchors.centerIn: parent
                                    text: "Primaire"
                                    color: "white"
                                    font.pixelSize: 10
                                }
                            }
                            
                            Rectangle {
                                width: 80
                                height: 30
                                color: themeColors["secondary"] || "#0097A7"
                                radius: 4
                                Text {
                                    anchors.centerIn: parent
                                    text: "Secondaire"
                                    color: "white"
                                    font.pixelSize: 10
                                }
                            }
                            
                            Rectangle {
                                width: 60
                                height: 30
                                color: themeColors["accent"] || "#FF9800"
                                radius: 4
                                Text {
                                    anchors.centerIn: parent
                                    text: "Accent"
                                    color: "white"
                                    font.pixelSize: 10
                                }
                            }
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: themeColors["surface"] || "#1E1E1E"
                            radius: 6
                            
                            Text {
                                anchors.centerIn: parent
                                text: "Zone de contenu\nCouleur de surface"
                                color: themeColors["text"] || "#FFFFFF"
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }
            
            // Colonne 3: Palettes (30%)
            ColumnLayout {
                Layout.preferredWidth: 300
                Layout.minimumWidth: 280
                Layout.maximumWidth: 320
                spacing: 15
                
                Text {
                    text: "🎨 Palette Générée"
                    color: "#00BCD4"
                    font.pixelSize: 16
                    font.bold: true
                }
                
                // Sélecteur de mode de génération
                ComboBox {
                    id: paletteModeCombo
                    Layout.fillWidth: true
                    Layout.preferredHeight: 35
                    
                    Material.theme: Material.Dark
                    Material.accent: "#00BCD4"
                    
                    property var modesList: [
                        { text: "🎨 Analogues", value: "analogous" },
                        { text: "🔄 Complémentaires", value: "complementary" },
                        { text: "△ Triadiques", value: "triadic" },
                        { text: "◾ Tétradiques", value: "tetradic" },
                        { text: "🌗 Monochromes", value: "monochromatic" },
                        { text: "⚡ Comp. divisées", value: "split-complementary" }
                    ]
                    
                    model: modesList.map(function(item) { return item.text; })
                    
                    onActivated: function(index) {
                        if (colorWheel) {
                            colorWheel.paletteMode = modesList[index].value;
                            // Force immediate palette generation
                            colorWheel.generatePalette();
                        }
                    }
                    
                    Component.onCompleted: {
                        currentIndex = 0; // Sélectionner "Analogues" par défaut
                    }
                }
                
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    
                    Repeater {
                        id: generatedPaletteRepeater
                        model: []  // Initialisé vide
                        
                        Rectangle {
                            width: 35
                            height: 35
                            color: modelData
                            radius: 4
                            border.color: "#333"
                            border.width: 1
                            
                            MouseArea {
                                id: paletteMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                
                                onClicked: {
                                    // Appliquer directement la couleur à l'onglet actuel
                                    // SANS modifier la position de la roue
                                    var color = Qt.color(modelData);
                                    updateCurrentColor(color);
                                    updatePreview();
                                }
                            }
                            
                            ToolTip {
                                visible: paletteMouseArea.containsMouse
                                text: modelData ? modelData.toString().substring(0, 7).toUpperCase() : ""
                            }
                        }
                    }
                }
                
                Text {
                    text: "⚡ Couleurs Rapides"
                    color: "white"
                    font.pixelSize: 16
                    font.bold: true
                }
                
                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    columnSpacing: 4
                    rowSpacing: 4
                    
                    Repeater {
                        model: [
                            "#F44336", "#E91E63", "#9C27B0", "#673AB7",
                            "#3F51B5", "#2196F3", "#03A9F4", "#00BCD4",
                            "#009688", "#4CAF50", "#8BC34A", "#CDDC39",
                            "#FFEB3B", "#FFC107", "#FF9800", "#FF5722"
                        ]
                        
                        Rectangle {
                            width: 28
                            height: 28
                            color: modelData
                            radius: 4
                            border.color: "#333"
                            border.width: 1
                            
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    // Appliquer directement la couleur à l'onglet actuel
                                    // SANS modifier la position de la roue
                                    var color = Qt.color(modelData);
                                    updateCurrentColor(color);
                                    updatePreview();
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Boutons d'action
        RowLayout {
            Layout.fillWidth: true
            spacing: 15
            
            Item { Layout.fillWidth: true }
            
            Button {
                text: "🔄 Réinitialiser"
                Material.background: "#FF9800"
                Material.foreground: "white"
                font.pixelSize: 14
                implicitHeight: 40
                onClicked: loadThemeColors()
            }
            

            
            Button {
                text: "💾 Sauvegarder"
                Material.background: "#4CAF50"
                Material.foreground: "white"
                font.pixelSize: 14
                implicitHeight: 40
                enabled: themeNameField.text.trim() !== ""
                
                onClicked: {
                    var themeName = themeNameField.text.trim();
                    if (themeName) {
                        if (configManager) {
                            configManager.saveCustomTheme(themeName, themeColors);
                        }
                        
                        if (isNewTheme) {
                            themeCreated(themeName, themeColors);
                        } else {
                            themeUpdated(themeName, themeColors);
                        }
                        
                        themeEditor.close();
                    }
                }
            }
        }
        
        // Espacement en bas pour éviter que les boutons soient coupés
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
        }
    }
    }
    
    // Propriétés pour les couleurs du thème
    property var themeColors: ({
        "primary": "#00BCD4",
        "secondary": "#0097A7", 
        "accent": "#FF9800",
        "background": "#121212",
        "surface": "#1E1E1E",
        "text": "#FFFFFF"
    })
    
    function getCurrentColorName() {
        if (colorTabs.currentIndex >= 0 && colorTabs.currentIndex < colorTabs.count) {
            var tab = colorTabs.itemAt(colorTabs.currentIndex);
            return tab ? tab.text : "";
        }
        return "";
    }
    
    function getCurrentColorKey() {
        if (colorTabs.currentIndex >= 0 && colorTabs.currentIndex < colorTabs.count) {
            var tab = colorTabs.itemAt(colorTabs.currentIndex);
            return tab ? tab.colorKey : "primary";
        }
        return "primary";
    }
    
    function updateCurrentColor(color) {
        if (!isUpdatingColorWheel) {
            var key = getCurrentColorKey();
            // Créer une nouvelle copie de l'objet pour forcer la mise à jour
            var newColors = {
                "primary": themeColors["primary"] || "#00BCD4",
                "secondary": themeColors["secondary"] || "#0097A7", 
                "accent": themeColors["accent"] || "#FF9800",
                "background": themeColors["background"] || "#121212",
                "surface": themeColors["surface"] || "#1E1E1E",
                "text": themeColors["text"] || "#FFFFFF"
            };
            newColors[key] = color.toString();
            themeColors = newColors; // Forcer la mise à jour des bindings
        }
    }
    
    function updatePreview() {
        // Utiliser un timer pour éviter trop de mises à jour
        previewUpdateTimer.restart();
    }
    
    Timer {
        id: previewUpdateTimer
        interval: 50
        onTriggered: {
            // Forcer la mise à jour complète de l'aperçu
            // On force une copie de l'objet pour déclencher les bindings
            var newColors = Object.assign({}, themeColors);
            themeColors = newColors;
        }
    }
    
    function loadThemeColors() {
        if (configManager && editingTheme) {
            themeColors = configManager.getThemeColors(editingTheme);
        }
        updateColorWheel();
    }
    
    property bool isUpdatingColorWheel: false
    property bool keepColorWheelPosition: false
    
    function updateColorWheel() {
        // NE PAS changer la position de la roue quand on change d'onglet
        // La roue garde sa position, seule la couleur de l'onglet se met à jour
        if (colorWheel && !isUpdatingColorWheel && !keepColorWheelPosition) {
            isUpdatingColorWheel = true;
            var colorKey = getCurrentColorKey();
            var color = Qt.color(themeColors[colorKey]);
            
            // Mettre à jour la roue des couleurs avec la couleur de l'onglet actuel
            colorWheel.hue = color.hslHue * 360;
            colorWheel.saturation = color.hslSaturation;
            colorWheel.lightness = color.hslLightness;
            
            // Générer la palette et forcer le repaint
            colorWheel.refreshDisplay();
            isUpdatingColorWheel = false;
        }
    }
    
    function syncColorFromWheel() {
        // Synchroniser la couleur de l'onglet actuel avec la roue
        if (colorWheel && !isUpdatingColorWheel) {
            updateCurrentColor(colorWheel.selectedColor);
            updatePreview();
        }
    }
    
    // Quand l'onglet change
    Connections {
        target: colorTabs
        function onCurrentIndexChanged() {
            // Option 1: Garder la position de la roue (recommandé pour UX fluide)
            keepColorWheelPosition = true;
            
            // Option 2: Synchroniser avec la couleur de l'onglet (décommentez si souhaité)
            // updateColorWheel();
        }
    }
    
    Component.onCompleted: {
        if (!isNewTheme) {
            loadThemeColors();
        }
    }
}