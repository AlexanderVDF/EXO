import QtQuick 2.15
import QtQuick.Controls 2.15

ApplicationWindow {
    visible: true
    width: 1024
    height: 600
    title: "Test EXO"
    
    Rectangle {
        anchors.fill: parent
        color: "#0D4F5C"
        
        Text {
            anchors.centerIn: parent
            text: "EXO TEST"
            color: "white"
            font.pixelSize: 48
            font.bold: true
        }
    }
}