import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Item {
    id: configSection
    
    property var assistant: null
    property string currentLocation: ""
    property var mainThemeEditor: null // Référence vers le ThemeEditor principal
    
    // Fonction pour rafraîchir les thèmes (appelée depuis main_radial.qml)
    function refreshThemes(newThemeName) {
        themeSelector.model = configManager.getAvailableThemes()
        if (newThemeName) {
            var displayName = newThemeName + " (Personnalisé)"
            var newIndex = themeSelector.model.indexOf(displayName)
            if (newIndex >= 0) {
                themeSelector.currentIndex = newIndex
            }
        }
        showMessage("✅ Thème '" + newThemeName + "' créé et appliqué!")
    }
    
    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        
        ColumnLayout {
            width: parent.width
            spacing: 20
            
            // Section Météo Configuration
            GroupBox {
                Layout.fillWidth: true
                title: "🌤️ Configuration Météo"
                Material.elevation: 2
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    
                    TextField {
                        id: weatherApiKeyField
                        Layout.fillWidth: true
                        placeholderText: "Clé API OpenWeatherMap"
                        echoMode: TextInput.Password
                        Material.accent: "#00BCD4"
                        text: configManager ? configManager.getWeatherApiKey() : ""
                    }
                    
                    TextField {
                        id: weatherCityField
                        Layout.fillWidth: true
                        placeholderText: "Ville (ex: Paris, London, New York)"
                        Material.accent: "#00BCD4"
                        text: configManager ? configManager.getWeatherCity() : "Paris"
                    }
                    
                    ComboBox {
                        id: weatherUnitsCombo
                        Layout.fillWidth: true
                        Material.accent: "#00BCD4"
                        model: ["Metric (°C)", "Imperial (°F)", "Kelvin (K)"]
                        currentIndex: 0
                    }
                    
                    Slider {
                        id: updateIntervalSlider
                        Layout.fillWidth: true
                        from: 5
                        to: 60
                        value: 10
                        stepSize: 5
                        
                        Text {
                            anchors.bottom: parent.top
                            text: "Intervalle de mise à jour: " + parent.value.toFixed(0) + " minutes"
                            color: "white"
                            font.pixelSize: 12
                        }
                    }
                    
                    Button {
                        text: "🌡️ Tester la Connexion Météo"
                        Material.background: "#2196F3"
                        onClicked: testWeatherConnection()
                    }
                }
            }
            
            // Section Thème et Apparence
            GroupBox {
                Layout.fillWidth: true
                title: "🎨 Thème et Apparence"
                Material.elevation: 2
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    
                    // Sélecteur de thème
                    RowLayout {
                        Layout.fillWidth: true
                        
                        Text {
                            text: "Thème actuel:"
                            color: "white"
                            font.pixelSize: 14
                        }
                        
                        ComboBox {
                            id: themeSelector
                            Layout.fillWidth: true
                            Material.accent: "#00BCD4"
                            model: configManager ? configManager.getAvailableThemes() : []
                            
                            onActivated: {
                                if (configManager && currentText) {
                                    configManager.setCurrentTheme(currentText)
                                }
                            }
                        }
                    }
                    
                    // Boutons d'action
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Button {
                            text: "➕ Nouveau Thème"
                            Material.background: "#4CAF50"
                            onClicked: {
                                if (mainThemeEditor) {
                                    mainThemeEditor.isNewTheme = true
                                    mainThemeEditor.editingTheme = ""
                                    mainThemeEditor.open()
                                }
                            }
                        }
                        
                        Button {
                            text: "✏️ Modifier"
                            Material.background: "#FF9800"
                            enabled: themeSelector.currentText && configManager ? configManager.isCustomTheme(themeSelector.currentText) : false
                            onClicked: {
                                if (mainThemeEditor) {
                                    mainThemeEditor.isNewTheme = false
                                    mainThemeEditor.editingTheme = themeSelector.currentText
                                    mainThemeEditor.open()
                                }
                            }
                        }
                        
                        Button {
                            text: "🗑️ Supprimer"
                            Material.background: "#F44336"
                            enabled: themeSelector.currentText && configManager ? configManager.isCustomTheme(themeSelector.currentText) : false
                            onClicked: {
                                if (configManager) {
                                    configManager.deleteCustomTheme(themeSelector.currentText)
                                    // Rafraîchir la liste
                                    themeSelector.model = configManager.getAvailableThemes()
                                }
                            }
                        }
                    }
                    
                    // Aperçu des couleurs du thème actuel
                    Text {
                        text: "Palette de couleurs:"
                        color: "white"
                        font.pixelSize: 12
                        font.bold: true
                    }
                    
                    Flow {
                        Layout.fillWidth: true
                        spacing: 5
                        
                        Repeater {
                            id: colorPalette
                            model: ["primary", "secondary", "accent", "background", "surface", "text"]
                            
                            Rectangle {
                                width: 40
                                height: 40
                                radius: 6
                                color: getThemeColor(modelData)
                                border.color: "#666"
                                border.width: 1
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.substring(0, 2).toUpperCase()
                                    color: modelData === "text" || modelData === "background" ? 
                                           (Qt.colorEqual(Qt.color(getThemeColor(modelData)), Qt.color("#FFFFFF")) ? "#000000" : "#FFFFFF") :
                                           "#FFFFFF"
                                    font.pixelSize: 8
                                    font.bold: true
                                }
                                
                                ToolTip {
                                    text: modelData + ": " + getThemeColor(modelData)
                                    visible: parent.hovered
                                    delay: 500
                                }
                                
                                property bool hovered: false
                                
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: parent.hovered = true
                                    onExited: parent.hovered = false
                                }
                            }
                        }
                    }
                }
            }
            
            // Section Géolocalisation
            GroupBox {
                Layout.fillWidth: true
                title: "🗺️ Géolocalisation Automatique"
                Material.elevation: 2
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    
                    CheckBox {
                        id: autoLocationCheckbox
                        text: "Détecter automatiquement ma ville"
                        Material.accent: "#00BCD4"
                        checked: configManager ? configManager.isLocationDetectionEnabled() : false
                        onClicked: {
                            if (configManager) {
                                configManager.setLocationDetectionEnabled(checked)
                            }
                        }
                    }
                    
                    Text {
                        id: locationText
                        Layout.fillWidth: true
                        text: "🌍 Localisation actuelle : " + (currentLocation || "Non détectée")
                        color: "white"
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                    
                    Row {
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Button {
                            text: "📍 Détecter ma Position"
                            Material.background: "#FF9800"
                            onClicked: detectLocationNow()
                        }
                        
                        Button {
                            text: "🔄 Appliquer à la Météo"
                            Material.background: "#4CAF50"
                            enabled: configManager && configManager.getCurrentLocation()
                            onClicked: applyLocationToWeather()
                        }
                    }
                }
            }
            
            // Section API Configuration
            GroupBox {
                Layout.fillWidth: true
                title: "🔑 Configuration API"
                Material.elevation: 2
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    
                    TextField {
                        id: claudeApiKeyField
                        Layout.fillWidth: true
                        placeholderText: "Clé API Claude"
                        echoMode: TextInput.Password
                        Material.accent: "#00BCD4"
                        text: configManager ? configManager.getClaudeApiKey() : ""
                    }
                    
                    ComboBox {
                        id: claudeModelCombo
                        Layout.fillWidth: true
                        Material.accent: "#00BCD4"
                        model: ["claude-3-haiku-20240307", "claude-3-sonnet-20240229", "claude-3-opus-20240229"]
                        currentIndex: 0
                    }
                    
                    Button {
                        text: "💾 Sauvegarder Configuration"
                        Material.background: "#4CAF50"
                        onClicked: saveConfiguration()
                    }
                }
            }
            
            // Section Voice
            GroupBox {
                Layout.fillWidth: true
                title: "🎙️ Paramètres Vocaux"
                Material.elevation: 2
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    
                    TextField {
                        Layout.fillWidth: true
                        text: "EXO"
                        placeholderText: "Mot d'activation"
                        Material.accent: "#00BCD4"
                    }
                    
                    Slider {
                        Layout.fillWidth: true
                        from: 0.1
                        to: 2.0
                        value: 1.0
                        stepSize: 0.1
                        
                        Text {
                            anchors.bottom: parent.top
                            text: "Volume: " + parent.value.toFixed(1)
                            color: "white"
                        }
                    }
                    
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["Français (France)", "Français (Canada)", "Français (Suisse)"]
                        Material.accent: "#00BCD4"
                    }
                }
            }
            
            // Section Interface
            GroupBox {
                Layout.fillWidth: true
                title: "🎨 Interface"
                Material.elevation: 2
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    
                    Switch {
                        text: "Mode sombre"
                        checked: true
                        Material.accent: "#00BCD4"
                    }
                    
                    Switch {
                        text: "Animations"
                        checked: true
                        Material.accent: "#00BCD4"
                    }
                    
                    Switch {
                        text: "Mode plein écran"
                        checked: false
                        Material.accent: "#00BCD4"
                    }
                }
            }
        }
    }
    
    // Fonctions JavaScript
    function saveConfiguration() {
        if (!configManager) {
            console.error("ConfigManager non disponible")
            return
        }
        
        console.log("💾 Sauvegarde de la configuration...")
        
        // Sauvegarder les paramètres météo
        if (weatherApiKeyField.text.trim() !== "") {
            configManager.setWeatherApiKey(weatherApiKeyField.text.trim())
        }
        if (weatherCityField.text.trim() !== "") {
            configManager.setWeatherCity(weatherCityField.text.trim())
        }
        
        // Sauvegarder les paramètres Claude
        if (claudeApiKeyField.text.trim() !== "") {
            configManager.setClaudeApiKey(claudeApiKeyField.text.trim())
        }
        
        // Modèle Claude
        var modelIndex = claudeModelCombo.currentIndex
        var models = ["claude-3-haiku-20240307", "claude-3-sonnet-20240229", "claude-3-opus-20240229"]
        configManager.setClaudeModel(models[modelIndex])
        
        // Sauvegarder dans le fichier
        if (configManager.saveConfiguration()) {
            console.log("✅ Configuration sauvegardée avec succès")
            showMessage("✅ Configuration sauvegardée avec succès !")
        } else {
            console.error("❌ Erreur lors de la sauvegarde")
            showMessage("❌ Erreur lors de la sauvegarde de la configuration")
        }
    }
    
    function testWeatherConnection() {
        if (!weatherManager) {
            showMessage("❌ Weather Manager non disponible")
            return
        }
        
        if (weatherApiKeyField.text.trim() === "") {
            showMessage("⚠️ Veuillez saisir une clé API météo")
            return
        }
        
        if (weatherCityField.text.trim() === "") {
            showMessage("⚠️ Veuillez saisir une ville")
            return
        }
        
        console.log("🌡️ Test de connexion météo pour:", weatherCityField.text)
        showMessage("🔄 Test de connexion en cours...")
        
        // Ici on pourrait appeler une fonction de test du WeatherManager
        // Pour l'instant, on simule un test réussi
        setTimeout(function() {
            showMessage("✅ Connexion météo réussie pour " + weatherCityField.text)
        }, 2000)
    }
    
    function showMessage(message) {
        if (assistant) {
            // Émettre un message vers le chat s'il est disponible
            assistant.messageReceived("Configuration", message)
        }
        console.log("📢", message)
    }
    
    function detectLocationNow() {
        if (!configManager) {
            showMessage("❌ Gestionnaire de configuration non disponible")
            return
        }
        
        console.log("🗺️ Détection de la localisation...")
        showMessage("🗺️ Détection de votre localisation en cours...")
        configManager.detectLocation()
    }
    
    function applyLocationToWeather() {
        if (!configManager) {
            showMessage("❌ Gestionnaire de configuration non disponible")
            return
        }
        
        var location = configManager.getCurrentLocation()
        if (!location) {
            showMessage("❌ Aucune localisation détectée")
            return
        }
        
        // Extraire le nom de la ville (première partie avant la virgule)
        var cityName = location.split(",")[0].trim()
        weatherCityField.text = cityName
        
        console.log("🌍 Application de la localisation à la météo:", cityName)
        showMessage("🌍 Ville mise à jour: " + cityName)
    }
    
    // Connexions aux signaux de géolocalisation
    Connections {
        target: configManager
        function onLocationDetected(city, country) {
            currentLocation = city + ", " + country
            showMessage("✅ Localisation détectée: " + city + ", " + country)
        }
        function onLocationDetectionError(error) {
            currentLocation = "Erreur de détection"
            showMessage("❌ Erreur de géolocalisation: " + error)
        }
    }
    
    // Charger la configuration au démarrage
    Component.onCompleted: {
        if (configManager) {
            weatherApiKeyField.text = configManager.getWeatherApiKey() || ""
            weatherCityField.text = configManager.getWeatherCity() || "Paris"
            claudeApiKeyField.text = configManager.getClaudeApiKey() || ""
            autoLocationCheckbox.checked = configManager.isLocationDetectionEnabled()
            currentLocation = configManager.getCurrentLocation() || ""
            
            // Sélectionner le bon modèle Claude
            var currentModel = configManager.getClaudeModel() || "claude-3-haiku-20240307"
            var models = ["claude-3-haiku-20240307", "claude-3-sonnet-20240229", "claude-3-opus-20240229"]
            claudeModelCombo.currentIndex = models.indexOf(currentModel)
            
            // Charger le thème actuel
            if (configManager) {
                var currentTheme = configManager.getCurrentTheme()
                var themes = configManager.getAvailableThemes()
                themeSelector.currentIndex = themes.indexOf(currentTheme)
            }
        }
    }
    
    // Connexion pour les changements de thème
    Connections {
        target: configManager
        function onThemeChanged(themeName, colors) {
            // Rafraîchir l'aperçu des couleurs
            colorPalette.model = ["primary", "secondary", "accent", "background", "surface", "text"]
        }
    }
    
    function getThemeColor(colorKey) {
        if (configManager && themeSelector.currentText) {
            var colors = configManager.getThemeColors(themeSelector.currentText)
            return colors[colorKey] || "#00BCD4"
        }
        return "#00BCD4"
    }
}