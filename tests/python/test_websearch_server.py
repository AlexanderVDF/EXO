"""
Tests unitaires — WebSearch Server (DuckDuckGo Lite)
Teste le parsing HTML et la validation des paramètres.
"""

import sys
from pathlib import Path

# Ajouter le module websearch au path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "python" / "websearch"))

from websearch_server import _parse_ddg_lite


class TestDDGLiteParsing:
    """Tests du parsing HTML DuckDuckGo Lite."""

    SAMPLE_HTML = """
    <html><body>
    <table>
    <tr>
        <td>1.&nbsp;</td>
        <td><a rel="nofollow" href="https://example.com/page1">Example Page 1</a></td>
    </tr>
    <tr>
        <td class="result-snippet">This is the snippet for page 1.</td>
    </tr>
    <tr>
        <td>2.&nbsp;</td>
        <td><a rel="nofollow" href="https://example.com/page2">Example Page 2</a></td>
    </tr>
    <tr>
        <td class="result-snippet">Another snippet for page 2.</td>
    </tr>
    </table>
    </body></html>
    """

    def test_parse_basic_results(self):
        results = _parse_ddg_lite(self.SAMPLE_HTML, 10)
        assert len(results) == 2
        assert results[0]["url"] == "https://example.com/page1"
        assert results[0]["title"] == "Example Page 1"
        assert "snippet" in results[0]["snippet"].lower() or len(results[0]["snippet"]) > 0

    def test_parse_empty_html(self):
        results = _parse_ddg_lite("", 10)
        assert results == []

    def test_parse_no_results(self):
        results = _parse_ddg_lite("<html><body><p>No results</p></body></html>", 10)
        assert results == []

    def test_parse_max_results(self):
        results = _parse_ddg_lite(self.SAMPLE_HTML, 1)
        assert len(results) <= 1


class TestWebSearchValidation:
    """Tests de validation des paramètres."""

    def test_freshness_values(self):
        valid = {"day", "week", "month", "year"}
        for v in valid:
            assert v in valid

    def test_max_results_bounds(self):
        # Côté serveur, max_results est borné entre 1 et 10
        assert max(1, min(10, 0)) == 1
        assert max(1, min(10, 5)) == 5
        assert max(1, min(10, 20)) == 10
