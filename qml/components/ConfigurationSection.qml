import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Item {
    id: configSection
    
    property var assistant: null
    
    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        
        ColumnLayout {
            width: parent.width
            spacing: 20
            
            // Section API Configuration
            GroupBox {
                Layout.fillWidth: true
                title: "🔑 Configuration API"
                Material.elevation: 2
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    
                    TextField {
                        Layout.fillWidth: true
                        placeholderText: "Clé API Claude"
                        echoMode: TextInput.Password
                        Material.accent: "#00BCD4"
                    }
                    
                    TextField {
                        Layout.fillWidth: true
                        placeholderText: "Clé API OpenWeatherMap"
                        echoMode: TextInput.Password
                        Material.accent: "#00BCD4"
                    }
                    
                    Button {
                        text: "💾 Sauvegarder"
                        Material.background: "#4CAF50"
                        onClicked: {
                            // TODO: Sauvegarder configuration
                            console.log("Sauvegarde configuration")
                        }
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
}