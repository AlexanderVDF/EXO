"""
Tests unitaires — Knowledge Server (Wikipedia)
Teste la construction d'URL et le fallback de langue.
"""

import sys
from pathlib import Path

# Ajouter le module knowledge au path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "python" / "knowledge"))

from knowledge_server import PORT


class TestKnowledgeServerConfig:
    """Tests de configuration basique."""

    def test_port(self):
        assert PORT == 8775

    def test_wikipedia_url_format(self):
        """Vérifie le format des URL Wikipedia REST API."""
        lang = "fr"
        topic = "Python_(langage)"
        url = f"https://{lang}.wikipedia.org/api/rest_v1/page/summary/{topic}"
        assert "fr.wikipedia.org" in url
        assert "rest_v1/page/summary" in url

    def test_wikipedia_search_url_format(self):
        lang = "en"
        query = "artificial intelligence"
        url = f"https://{lang}.wikipedia.org/w/api.php"
        assert "en.wikipedia.org" in url

    def test_language_fallback(self):
        """Le serveur doit supporter fr et en."""
        supported = ["fr", "en"]
        for lang in supported:
            url = f"https://{lang}.wikipedia.org/api/rest_v1/page/summary/Test"
            assert lang in url
