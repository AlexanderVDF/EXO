# Version simplifiée pour compilation initiale
cmake_minimum_required(VERSION 3.21)

project(RaspberryAssistant VERSION 4.2.0 LANGUAGES CXX)

# ── Options ──
option(ENABLE_RTAUDIO "Enable RtAudio backend (WASAPI on Windows)" ON)
option(BUILD_TESTS    "Build unit tests (Qt Test + CTest)"         ON)

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
    WebSockets
    Sql
)

# Sources principales — architecture modulaire app/
set(SOURCES
    app/main.cpp
    app/core/AssistantManager.cpp
    app/core/ConfigManager.cpp
    app/core/LogManager.cpp
    app/core/PipelineEvent.cpp
    app/core/PipelineTracer.cpp
    app/core/WebSocketClient.cpp
    app/core/HealthCheck.cpp
    app/core/ServiceManager.cpp
    app/audio/VoicePipeline.cpp
    app/audio/TTSManager.cpp
    app/audio/TTSBackendQt.cpp
    app/audio/TTSBackendXTTS.cpp
    app/audio/AudioInputQt.cpp
    app/audio/AudioDeviceManager.cpp
    app/llm/ClaudeAPI.cpp
    app/llm/AIMemoryManager.cpp
    app/utils/WeatherManager.cpp
)

set(HEADERS
    app/core/AssistantManager.h
    app/core/ConfigManager.h
    app/core/LogManager.h
    app/core/PipelineEvent.h
    app/core/PipelineTypes.h
    app/core/PipelineTracer.h
    app/core/WebSocketClient.h
    app/core/HealthCheck.h
    app/core/ServiceManager.h
    app/audio/VoicePipeline.h
    app/audio/TTSManager.h
    app/audio/TTSBackend.h
    app/audio/TTSBackendQt.h
    app/audio/TTSBackendXTTS.h
    app/audio/AudioInput.h
    app/audio/AudioInputQt.h
    app/audio/AudioDeviceManager.h
    app/llm/ClaudeAPI.h
    app/llm/AIMemoryManager.h
    app/utils/WeatherManager.h
)

# ── RtAudio (optional) ──
if(ENABLE_RTAUDIO)
    # Build RtAudio as static lib with WASAPI only
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
    set(RTAUDIO_BUILD_PYTHON OFF CACHE BOOL "" FORCE)
    add_subdirectory(rtaudio EXCLUDE_FROM_ALL)

    list(APPEND SOURCES app/audio/AudioInputRtAudio.cpp)
    list(APPEND HEADERS app/audio/AudioInputRtAudio.h)
endif()

# Exécutable avec console pour debug
qt_add_executable(RaspberryAssistant ${SOURCES} ${HEADERS})
set_target_properties(RaspberryAssistant PROPERTIES
    WIN32_EXECUTABLE FALSE  # Console app sur Windows pour voir les erreurs
)

# Qt QML policies
qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 OLD)

# Theme singleton property
set_source_files_properties(qml/theme/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

# Module QML
qt_add_qml_module(RaspberryAssistant
    URI RaspberryAssistant
    VERSION 4.0
    QML_FILES
        qml/MainWindow.qml
        # ── Pages ──
        qml/pages/HomePage.qml
        qml/pages/SettingsPage.qml
        qml/pages/PipelinePage.qml
        qml/pages/LogsPage.qml
        qml/pages/HistoryPage.qml
        # ── Panels ──
        qml/panels/Sidebar.qml
        qml/panels/BottomBar.qml
        qml/panels/HeaderBar.qml
        # ── Theme ──
        qml/theme/Theme.qml
        # ── Components ──
        qml/components/ExoButton.qml
        qml/components/ExoCard.qml
        qml/components/ExoSwitch.qml
        qml/components/ExoSlider.qml
        qml/components/ExoTextField.qml
        qml/components/ExoDialog.qml
        qml/components/ExoNotification.qml
        qml/components/ExoPanelHeader.qml
        qml/components/ExoSearchField.qml
        qml/components/ExoProgressBar.qml
        qml/components/ExoBadge.qml
        qml/components/ExoStatusPill.qml
        qml/components/ExoConfirmDialog.qml
        qml/components/ExoSheet.qml
        qml/components/ExoTab.qml
        qml/components/ExoPipelineStatus.qml
        qml/components/ExoServiceStatus.qml
        qml/components/ExoMicButton.qml
        qml/components/ExoWaveform.qml
        qml/components/ExoStatusIndicator.qml
        qml/components/ExoMicrophoneLevel.qml
        qml/components/ExoVisualizer.qml
        qml/components/ExoTranscriptView.qml
        qml/components/ExoResponseView.qml
        qml/components/ExoSplashScreen.qml
    RESOURCES
        qml/theme/qmldir
        qml/components/qmldir
        qml/pages/qmldir
        qml/panels/qmldir
        qml/icons/chat.svg
        qml/icons/debug.svg
        qml/icons/history.svg
        qml/icons/logs.svg
        qml/icons/microphone.svg
        qml/icons/pipeline.svg
        qml/icons/send.svg
        qml/icons/settings.svg
        qml/icons/stt.svg
        qml/icons/tts.svg
        qml/icons/vad.svg
        qml/icons/wakeword.svg
)

# Chemins d'inclusion — app/ comme racine + sous-dossiers
target_include_directories(RaspberryAssistant PRIVATE 
    ${CMAKE_CURRENT_SOURCE_DIR}/app
    ${CMAKE_CURRENT_SOURCE_DIR}/app/core
    ${CMAKE_CURRENT_SOURCE_DIR}/app/audio
    ${CMAKE_CURRENT_SOURCE_DIR}/app/llm
    ${CMAKE_CURRENT_SOURCE_DIR}/app/utils
)

# ── RtAudio include + compile definition ──
if(ENABLE_RTAUDIO)
    target_include_directories(RaspberryAssistant PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/rtaudio
    )
    target_compile_definitions(RaspberryAssistant PRIVATE ENABLE_RTAUDIO)
endif()

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
    Qt6::WebSockets
    Qt6::Sql
)

if(ENABLE_RTAUDIO)
    target_link_libraries(RaspberryAssistant PRIVATE rtaudio)
endif()



# Copier les fichiers de configuration vers le répertoire de build
add_custom_target(${PROJECT_NAME}_copy_config ALL
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_SOURCE_DIR}/config
        $<TARGET_FILE_DIR:RaspberryAssistant>/config
    COMMENT "Copie config/ vers le répertoire de sortie"
)
add_dependencies(RaspberryAssistant ${PROJECT_NAME}_copy_config)

# ── Auto-deploy Qt DLLs (Windows) ──
if(WIN32)
    find_program(WINDEPLOYQT windeployqt6 HINTS "${Qt6_DIR}/../../../bin")
    if(WINDEPLOYQT)
        add_custom_command(TARGET RaspberryAssistant POST_BUILD
            COMMAND "${WINDEPLOYQT}"
                --no-translations
                --qmldir "${CMAKE_SOURCE_DIR}/qml"
                "$<TARGET_FILE:RaspberryAssistant>"
            COMMENT "Running windeployqt..."
        )
    endif()
endif()

# Informations de configuration
message(STATUS "=== Configuration du projet ===")
message(STATUS "Système cible: ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "Type de build: ${CMAKE_BUILD_TYPE}")
message(STATUS "Qt version: ${Qt6_VERSION}")
message(STATUS "Tests: ${BUILD_TESTS}")
message(STATUS "==============================")

# ── Tests ──
if(BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests/cpp)
endif()