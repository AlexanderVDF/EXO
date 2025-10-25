# Version simplifiée pour compilation initiale
cmake_minimum_required(VERSION 3.21)

project(RaspberryAssistant VERSION 2.0.0 LANGUAGES CXX)

# Configuration C++
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Configuration Qt
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS 
    Core 
    Quick 
    QuickControls2
    Widgets
    Network
    Multimedia
    MultimediaWidgets
    TextToSpeech
)

# Sources principales Henri
set(SOURCES
    src/main.cpp
    src/assistantmanager.cpp
    src/configmanager.cpp
    src/logmanager.cpp
    src/claudeapi.cpp
    src/voicemanager.cpp
    src/weathermanager.cpp
)

set(HEADERS
    src/assistantmanager.h
    src/configmanager.h
    src/logmanager.h
    src/claudeapi.h
    src/voicemanager.h
    src/weathermanager.h
)

# Exécutable
qt_add_executable(RaspberryAssistant ${SOURCES} ${HEADERS})

# Module QML
qt_add_qml_module(RaspberryAssistant
    URI RaspberryAssistant
    VERSION 2.0
    QML_FILES
        qml/main.qml
)

# Liaison des bibliothèques (syntaxe PRIVATE pour éviter les conflits)
target_link_libraries(RaspberryAssistant PRIVATE
    Qt6::Core
    Qt6::Quick  
    Qt6::QuickControls2
    Qt6::Widgets
    Qt6::Network
    Qt6::Multimedia
    Qt6::MultimediaWidgets
    Qt6::TextToSpeech
)

# Informations de configuration
message(STATUS "=== Configuration du projet ===")
message(STATUS "Système cible: ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "Type de build: ${CMAKE_BUILD_TYPE}")
message(STATUS "Qt version: ${Qt6_VERSION}")
message(STATUS "==============================")