# Dernière mise à jour

> Auto-généré par le hook post-commit

| Champ | Valeur |
|-------|--------|
| **Commit** | `bef1c81` |
| **Date** | 2026-04-11 16:13:42 +0200 |
| **Auteur** | EXO Developer |
| **Message** | feat(v28.0): simulation spatiale avancée + cohérence totale doc/code/config |

## Fichiers modifiés

```
M	.copilot-instructions.md
M	.gitignore
M	CHANGELOG.md
M	CMakeLists.txt
M	PROMPT_MAITRE.md
M	README.md
M	__test_mem_dir__/metadata_v2.json
M	app/audio/TTSBackendXTTS.h
M	app/audio/ttsmanager.cpp
M	app/audio/ttsmanager.h
M	app/audio/voicepipeline.cpp
M	app/audio/voicepipeline.h
M	app/core/HealthCheck.h
M	app/core/assistantmanager.cpp
M	app/core/assistantmanager.h
M	app/core/configmanager.h
A	app/floorplan/FloorPlanController.cpp
A	app/floorplan/FloorPlanController.h
A	app/floorplan/FloorPlanEnums.h
A	app/floorplan/FloorPlanItem.cpp
A	app/floorplan/FloorPlanItem.h
A	app/floorplan/FloorPlanModel.cpp
A	app/floorplan/FloorPlanModel.h
A	app/floorplan/FloorPlanSerializer.cpp
A	app/floorplan/FloorPlanSerializer.h
M	app/llm/claudeapi.cpp
M	app/llm/claudeapi.h
M	app/main.cpp
A	app/simulation/SimulationController.cpp
A	app/simulation/SimulationController.h
A	app/simulation/SimulationEngine.cpp
A	app/simulation/SimulationEngine.h
A	app/simulation/SimulationEntity.cpp
A	app/simulation/SimulationEntity.h
A	app/simulation/SimulationEnums.h
A	app/simulation/SimulationPropagation.cpp
A	app/simulation/SimulationPropagation.h
A	app/simulation/SimulationResult.cpp
A	app/simulation/SimulationResult.h
A	app/simulation/SimulationScenario.cpp
A	app/simulation/SimulationScenario.h
A	app/test/TestController.cpp
A	app/test/TestController.h
M	config/assistant.conf.example
M	config/services.json
D	docs/CHANGELOG.md
M	docs/PLAN_IMPLEMENTATION.md
M	docs/architecture/graph.md
M	docs/last_update.md
M	docs/modules.md
M	docs/pipeline.md
M	docs/services.md
M	exo/__init__.py
M	exo_launcher.py
M	launch_exo.ps1
M	pyproject.toml
M	python/memory/memory_server.py
M	python/nlu/nlu_server.py
M	python/shared/__init__.py
M	python/shared/base_service.py
M	python/shared/config_manager.py
A	python/start_missing_services.py
A	python/stt/faster_whisper_backend.py
M	python/stt/stt_server.py
M	python/stt/whisper_cpp.py
A	python/test/exo_test_runner.py
M	python/tts/cosyvoice_engine.py
M	python/tts/tts_server.py
M	python/vad/vad_server.py
M	python/wakeword/wakeword_server.py
M	qml/MainWindow.qml
A	qml/cognitive/AgentsPanel.qml
A	qml/cognitive/AnomalyPanel.qml
A	qml/cognitive/CausalityGraph.qml
A	qml/cognitive/CognitiveMinimap.qml
A	qml/cognitive/CognitiveSpatialView.qml
A	qml/cognitive/CognitiveTimeline.qml
A	qml/cognitive/MetricsPanel.qml
A	qml/cognitive/PipelineTimeline.qml
A	qml/cognitive/RiskPanel.qml
A	qml/cognitive/ScenarioPanel.qml
A	qml/cognitive/SimulationCausalityGraph.qml
A	qml/cognitive/SimulationMinimap.qml
A	qml/cognitive/SimulationOverlay.qml
A	qml/cognitive/SimulationRiskPanel.qml
A	qml/cognitive/SimulationScenarioPanel.qml
A	qml/cognitive/SimulationTimeline.qml
A	qml/cognitive/SpatialOverlay.qml
A	qml/cognitive/TracePanel.qml
A	qml/cognitive/qmldir
A	qml/components/CameraCone.qml
A	qml/components/CognitiveTimeline.qml
A	qml/components/EngineHeatmap.qml
M	qml/components/ExoSplashScreen.qml
A	qml/components/FloorPlanProperties.qml
A	qml/components/FloorPlanTools.qml
A	qml/components/FurniturePalette.qml
A	qml/components/GovernancePanel.qml
A	qml/components/MemoryInspector.qml
A	qml/components/ModeSwitch.qml
A	qml/components/ObservabilityDashboard.qml
A	qml/components/PipelineView.qml
A	qml/components/VoicePipelineView.qml
M	qml/components/qmldir
A	qml/pages/FloorPlanPage.qml
M	qml/pages/HomePage.qml
M	qml/pages/SettingsPage.qml
A	qml/pages/SimulationPage.qml
M	qml/pages/qmldir
M	qml/panels/HeaderBar.qml
M	qml/panels/Sidebar.qml
A	qml/panels/StabilityPanel.qml
M	qml/panels/qmldir
M	scripts/create_desktop_shortcut.ps1
M	tests/cpp/CMakeLists.txt
A	tests/cpp/test_simulation.cpp
M	tests/python/test_v9_config.py
```
