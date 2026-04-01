"""
Tests unitaires — News Server (RSS)
Teste le parsing RSS et le nettoyage HTML.
"""

import sys
from pathlib import Path

# Ajouter le module news au path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "python" / "news"))

from news_server import _clean_html, RSS_FEEDS


class TestCleanHTML:
    """Tests du nettoyage HTML dans les descriptions RSS."""

    def test_strip_tags(self):
        assert _clean_html("<p>Hello <b>world</b></p>") == "Hello world"

    def test_strip_img(self):
        result = _clean_html('<img src="photo.jpg"/>Some text')
        assert "img" not in result
        assert "Some text" in result

    def test_empty_string(self):
        assert _clean_html("") == ""

    def test_entities(self):
        result = _clean_html("&amp; &lt; &gt;")
        assert "&" in result

    def test_plain_text_passthrough(self):
        assert _clean_html("Just plain text") == "Just plain text"

    def test_nested_tags(self):
        result = _clean_html("<div><p><span>Deep</span> text</p></div>")
        assert "Deep" in result
        assert "text" in result


class TestRSSFeedsConfig:
    """Tests de la configuration des flux RSS."""

    def test_french_general_feeds_exist(self):
        assert "fr" in RSS_FEEDS
        assert "general" in RSS_FEEDS["fr"]
        assert len(RSS_FEEDS["fr"]["general"]) > 0

    def test_english_feeds_exist(self):
        assert "en" in RSS_FEEDS
        assert "general" in RSS_FEEDS["en"]

    def test_tech_category_exists(self):
        assert "tech" in RSS_FEEDS["fr"]
        assert len(RSS_FEEDS["fr"]["tech"]) > 0

    def test_science_category_exists(self):
        assert "science" in RSS_FEEDS["fr"]
        assert len(RSS_FEEDS["fr"]["science"]) > 0

    def test_all_feeds_are_urls(self):
        for region in RSS_FEEDS:
            for topic in RSS_FEEDS[region]:
                for url in RSS_FEEDS[region][topic]:
                    assert url.startswith("http"), f"Invalid feed URL: {url}"
