# ═══════════════════════════════════════════════════════
#  Tests C++ — Qt Test Framework
# ═══════════════════════════════════════════════════════
cmake_minimum_required(VERSION 3.21)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Test Network WebSockets Multimedia TextToSpeech Sql)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 17)

# ── Bibliothèque objet partagée par tous les tests ──
# On compile les modules testables une seule fois.
set(EXO_TEST_SOURCES
    ${CMAKE_SOURCE_DIR}/app/core/ConfigManager.cpp
    ${CMAKE_SOURCE_DIR}/app/core/PipelineEvent.cpp
    ${CMAKE_SOURCE_DIR}/app/core/PipelineTracer.cpp
    ${CMAKE_SOURCE_DIR}/app/core/LogManager.cpp
    ${CMAKE_SOURCE_DIR}/app/core/WebSocketClient.cpp
    ${CMAKE_SOURCE_DIR}/app/core/HealthCheck.cpp
    ${CMAKE_SOURCE_DIR}/app/audio/TTSManager.cpp
    ${CMAKE_SOURCE_DIR}/app/audio/VoicePipeline.cpp
    ${CMAKE_SOURCE_DIR}/app/audio/TTSBackendQt.cpp
    ${CMAKE_SOURCE_DIR}/app/audio/TTSBackendXTTS.cpp
    ${CMAKE_SOURCE_DIR}/app/audio/AudioInputQt.cpp
    ${CMAKE_SOURCE_DIR}/app/llm/ClaudeAPI.cpp
    ${CMAKE_SOURCE_DIR}/app/llm/AIMemoryManager.cpp
    ${CMAKE_SOURCE_DIR}/app/utils/WeatherManager.cpp
)

set(EXO_TEST_HEADERS
    ${CMAKE_SOURCE_DIR}/app/core/ConfigManager.h
    ${CMAKE_SOURCE_DIR}/app/core/PipelineEvent.h
    ${CMAKE_SOURCE_DIR}/app/core/PipelineTypes.h
    ${CMAKE_SOURCE_DIR}/app/core/PipelineTracer.h
    ${CMAKE_SOURCE_DIR}/app/core/LogManager.h
    ${CMAKE_SOURCE_DIR}/app/core/WebSocketClient.h
    ${CMAKE_SOURCE_DIR}/app/core/HealthCheck.h
    ${CMAKE_SOURCE_DIR}/app/audio/VoicePipeline.h
    ${CMAKE_SOURCE_DIR}/app/audio/TTSManager.h
    ${CMAKE_SOURCE_DIR}/app/audio/TTSBackend.h
    ${CMAKE_SOURCE_DIR}/app/audio/TTSBackendQt.h
    ${CMAKE_SOURCE_DIR}/app/audio/TTSBackendXTTS.h
    ${CMAKE_SOURCE_DIR}/app/audio/AudioInput.h
    ${CMAKE_SOURCE_DIR}/app/audio/AudioInputQt.h
    ${CMAKE_SOURCE_DIR}/app/llm/ClaudeAPI.h
    ${CMAKE_SOURCE_DIR}/app/llm/AIMemoryManager.h
    ${CMAKE_SOURCE_DIR}/app/utils/WeatherManager.h
)

add_library(exo_testlib STATIC ${EXO_TEST_SOURCES} ${EXO_TEST_HEADERS})
target_include_directories(exo_testlib PUBLIC
    ${CMAKE_SOURCE_DIR}/app
    ${CMAKE_SOURCE_DIR}/app/core
    ${CMAKE_SOURCE_DIR}/app/audio
    ${CMAKE_SOURCE_DIR}/app/llm
    ${CMAKE_SOURCE_DIR}/app/utils
)
target_link_libraries(exo_testlib PUBLIC
    Qt6::Core Qt6::Network Qt6::WebSockets
    Qt6::Multimedia Qt6::TextToSpeech Qt6::Sql
)

if(ENABLE_RTAUDIO)
    target_sources(exo_testlib PRIVATE
        ${CMAKE_SOURCE_DIR}/app/audio/AudioInputRtAudio.cpp
    )
    target_include_directories(exo_testlib PUBLIC
        ${CMAKE_SOURCE_DIR}/rtaudio
    )
    target_compile_definitions(exo_testlib PUBLIC ENABLE_RTAUDIO)
    target_link_libraries(exo_testlib PUBLIC rtaudio)
endif()

# ── Macro helper : un test = un exécutable CTest ──
function(exo_add_test NAME)
    add_executable(${NAME} ${NAME}.cpp)
    target_link_libraries(${NAME} PRIVATE exo_testlib Qt6::Test)
    add_test(NAME ${NAME} COMMAND ${NAME})
    set_tests_properties(${NAME} PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
    )
endfunction()

# ── Tests unitaires ──
exo_add_test(test_configmanager)
exo_add_test(test_pipelineevent)
exo_add_test(test_circularaudiobuffer)
exo_add_test(test_audiopreprocessor)
exo_add_test(test_tts_dsp)
exo_add_test(test_pipelinetracer)
exo_add_test(test_healthcheck)
