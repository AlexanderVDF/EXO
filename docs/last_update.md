# Dernière mise à jour

> Auto-généré par le hook post-commit

| Champ | Valeur |
|-------|--------|
| **Commit** | `7a91fd4` |
| **Date** | 2026-04-04 17:05:38 +0200 |
| **Auteur** | EXO Developer |
| **Message** | feat: EXO v8.1 Ultra-Low Latency + domotique + docs |

## Fichiers modifiés

```
M	CHANGELOG.md
M	CMakeLists.txt
D	PLAN_IMPLEMENTATION.md
M	PROMPT_MAITRE.md
M	README.md
M	app/audio/ttsmanager.cpp
M	app/audio/ttsmanager.h
M	app/audio/voicepipeline.cpp
M	app/audio/voicepipeline.h
A	app/core/ContextCache.cpp
A	app/core/ContextCache.h
M	app/core/HealthCheck.cpp
M	app/core/HealthCheck.h
A	app/core/LatencyMetrics.cpp
A	app/core/LatencyMetrics.h
M	app/core/assistantmanager.cpp
M	app/core/assistantmanager.h
M	app/llm/claudeapi.cpp
M	app/llm/claudeapi.h
M	config/services.json
A	docs/CHANGELOG.md
A	docs/PLAN_IMPLEMENTATION.md
A	docs/architecture/graph.md
A	docs/last_update.md
A	docs/modules.md
A	docs/pipeline.md
A	docs/services.md
D	gui/index.html
D	gui/package-lock.json
D	gui/package.json
D	gui/postcss.config.js
D	gui/src/App.jsx
D	gui/src/components/Avatar.jsx
D	gui/src/components/Card.jsx
D	gui/src/components/Icon.jsx
D	gui/src/components/Sidebar.jsx
D	gui/src/components/StateIndicator.jsx
D	gui/src/components/TopBar.jsx
D	gui/src/components/Waveform.jsx
D	gui/src/hooks/useWebSocket.js
D	gui/src/index.css
D	gui/src/main.jsx
D	gui/src/screens/Devices.jsx
D	gui/src/screens/Home.jsx
D	gui/src/screens/NetworkMap.jsx
D	gui/src/screens/Plans.jsx
D	gui/src/screens/Settings.jsx
D	gui/src/theme/colors.js
D	gui/src/theme/typography.js
D	gui/tailwind.config.js
D	gui/vite.config.js
A	python/context/__init__.py
A	python/context/context_engine.py
A	python/domotique/__init__.py
A	python/domotique/camera_service.py
A	python/domotique/domotic_service.py
A	python/domotique/echo_service.py
A	python/domotique/homegraph_server.py
A	python/domotique/models.py
A	python/domotique/samsung_service.py
A	python/domotique/voltalis_service.py
A	python/executor/__init__.py
A	python/executor/task_executor_server.py
M	python/memory/memory_server.py
A	python/network/__init__.py
A	python/network/network_map_service.py
A	python/planner/__init__.py
A	python/planner/task_planner_server.py
M	python/stt/stt_server.py
A	python/tools/calendar_service.py
A	python/tools/file_service.py
A	python/tools/system_service.py
M	python/vad/vad_server.py
A	python/verifier/__init__.py
A	python/verifier/task_verifier_server.py
M	qml/MainWindow.qml
A	qml/components/AudioWaveformView.qml
A	qml/components/ExoContextPanel.qml
A	qml/components/ExoOrbVisualizer.qml
A	qml/components/ExoPlanProgress.qml
M	qml/components/qmldir
A	qml/icons/maison.svg
A	qml/icons/reseau.svg
M	qml/pages/HomePage.qml
A	qml/pages/MaisonPage.qml
A	qml/pages/ReseauPage.qml
M	qml/pages/SettingsPage.qml
M	qml/panels/BottomBar.qml
M	qml/panels/Sidebar.qml
D	scripts/_audit_result.json
D	scripts/_benchmark_test.wav
D	scripts/build_docs_site.py
D	scripts/md_to_html.py
A	tests/python/test_calendar_service.py
A	tests/python/test_context_engine.py
A	tests/python/test_context_engine_v8.py
A	tests/python/test_domotique.py
A	tests/python/test_file_service.py
M	tests/python/test_knowledge_server.py
A	tests/python/test_memory_v8.py
M	tests/python/test_news_server.py
A	tests/python/test_system_service.py
A	tests/python/test_task_executor.py
A	tests/python/test_task_planner.py
A	tests/python/test_task_planner_v8.py
A	tests/python/test_task_verifier.py
A	tests/python/test_ull.py
M	tests/python/test_websearch_server.py
```
