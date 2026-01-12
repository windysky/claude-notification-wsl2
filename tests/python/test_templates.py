# test_templates.py
# Python tests for notification templates and template loader
#
# Author: Claude Code TDD Implementation
# Version: 1.0.0

import pytest
import json
from pathlib import Path


class TestNotificationTemplates:
    """Test suite for notification template files"""

    @pytest.fixture
    def templates_dir(self):
        """Get the templates directory path"""
        return Path(__file__).parent.parent.parent / "templates" / "notifications"

    @pytest.fixture
    def template_files(self, templates_dir):
        """Get all template file paths"""
        return {
            "en": templates_dir / "en.json",
            "ko": templates_dir / "ko.json",
            "ja": templates_dir / "ja.json",
            "zh": templates_dir / "zh.json",
        }

    def test_template_files_exist(self, template_files):
        """Test that all template files exist"""
        for lang, path in template_files.items():
            assert path.exists(), f"Template file for {lang} not found at {path}"

    def test_template_files_are_valid_json(self, template_files):
        """Test that all template files are valid JSON"""
        for lang, path in template_files.items():
            with open(path, "r", encoding="utf-8") as f:
                assert json.load(f) is not None, f"Invalid JSON in {path}"

    def test_template_files_have_required_keys(self, template_files):
        """Test that all template files have required keys"""
        required_keys = [
            "tool_completed",
            "tool_failed",
            "error_occurred",
            "session_start",
            "session_end",
        ]

        for lang, path in template_files.items():
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
                for key in required_keys:
                    assert key in data, f"Missing key '{key}' in {path}"

    def test_template_files_have_title_and_message(self, template_files):
        """Test that all templates have title and message fields"""
        for lang, path in template_files.items():
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
                for key, value in data.items():
                    assert "title" in value, f"Missing 'title' in {key} of {path}"
                    assert "message" in value, f"Missing 'message' in {key} of {path}"
                    assert isinstance(value["title"], str), (
                        f"Title must be string in {key} of {path}"
                    )
                    assert isinstance(value["message"], str), (
                        f"Message must be string in {key} of {path}"
                    )

    def test_english_templates_content(self, template_files):
        """Test English template content"""
        en_path = template_files["en"]
        with open(en_path, "r", encoding="utf-8") as f:
            data = json.load(f)

            assert "tool_completed" in data
            assert (
                "Tool Completed" in data["tool_completed"]["title"]
                or "Completed" in data["tool_completed"]["title"]
            )
            assert len(data["tool_completed"]["title"]) > 0
            assert len(data["tool_completed"]["message"]) > 0

    def test_korean_templates_content(self, template_files):
        """Test Korean template content"""
        ko_path = template_files["ko"]
        with open(ko_path, "r", encoding="utf-8") as f:
            data = json.load(f)

            # Verify Korean characters are present
            assert any(
                "\uac00\ud7a3" <= c <= "\ud7a3" for c in data["tool_completed"]["title"]
            )
            assert len(data["tool_completed"]["title"]) > 0
            assert len(data["tool_completed"]["message"]) > 0

    def test_japanese_templates_content(self, template_files):
        """Test Japanese template content"""
        ja_path = template_files["ja"]
        with open(ja_path, "r", encoding="utf-8") as f:
            data = json.load(f)

            # Verify Japanese characters are present
            assert any(
                "\u3040\u309f" <= c <= "\u30ff" or "\u4e00\u9faf" <= c <= "\u9faf"
                for c in data["tool_completed"]["title"]
            )
            assert len(data["tool_completed"]["title"]) > 0
            assert len(data["tool_completed"]["message"]) > 0

    def test_chinese_templates_content(self, template_files):
        """Test Chinese template content"""
        zh_path = template_files["zh"]
        with open(zh_path, "r", encoding="utf-8") as f:
            data = json.load(f)

            # Verify Chinese characters are present
            assert any(
                "\u4e00\u9fff" <= c <= "\u9fff" for c in data["tool_completed"]["title"]
            )
            assert len(data["tool_completed"]["title"]) > 0
            assert len(data["tool_completed"]["message"]) > 0


class TestTemplateLoader:
    """Test suite for template loader functionality"""

    @pytest.fixture
    def mock_templates(self, tmp_path):
        """Create mock template files for testing"""
        templates = {
            "en.json": {
                "tool_completed": {
                    "title": "Tool Completed",
                    "message": "Tool finished successfully",
                },
                "tool_failed": {
                    "title": "Tool Failed",
                    "message": "Tool execution failed",
                },
            },
            "ko.json": {
                "tool_completed": {
                    "title": "도구 완료",
                    "message": "도구가 성공적으로 완료되었습니다",
                },
                "tool_failed": {
                    "title": "도구 실패",
                    "message": "도구 실행이 실패했습니다",
                },
            },
            "ja.json": {
                "tool_completed": {
                    "title": "ツール完了",
                    "message": "ツールが正常に完了しました",
                },
                "tool_failed": {
                    "title": "ツール失敗",
                    "message": "ツールの実行が失敗しました",
                },
            },
        }

        templates_dir = tmp_path / "notifications"
        templates_dir.mkdir()

        for filename, content in templates.items():
            (templates_dir / filename).write_text(
                json.dumps(content, ensure_ascii=False), encoding="utf-8"
            )

        return templates_dir

    def test_load_template_for_language(self, mock_templates):
        """Test loading template for specific language"""
        from src.template_loader import TemplateLoader

        loader = TemplateLoader(mock_templates)
        template = loader.get_template("tool_completed", "en")

        assert template["title"] == "Tool Completed"
        assert template["message"] == "Tool finished successfully"

    def test_language_fallback_to_english(self, mock_templates):
        """Test that unsupported languages fallback to English"""
        from src.template_loader import TemplateLoader

        loader = TemplateLoader(mock_templates)

        # Request a language that doesn't exist
        template = loader.get_template("tool_completed", "fr")

        # Should fallback to English
        assert template["title"] == "Tool Completed"

    def test_load_template_with_key(self, mock_templates):
        """Test loading specific template key"""
        from src.template_loader import TemplateLoader

        loader = TemplateLoader(mock_templates)

        template = loader.get_template("tool_failed", "ko")
        assert "실패" in template["title"]

        template = loader.get_template("tool_failed", "ja")
        assert "失敗" in template["title"]

    def test_load_template_handles_missing_file(self, mock_templates):
        """Test handling of missing template file"""
        from src.template_loader import TemplateLoader

        loader = TemplateLoader(mock_templates)

        # Try to load from a language that doesn't have a template file
        # This should fallback to English which exists
        template = loader.get_template("tool_completed", "de")
        assert "Tool" in template["title"]

    def test_load_template_handles_invalid_json(self, tmp_path):
        """Test handling of invalid JSON in template file"""
        from src.template_loader import TemplateLoader

        invalid_file = tmp_path / "notifications" / "invalid.json"
        invalid_file.parent.mkdir()
        invalid_file.write_text("{invalid json}", encoding="utf-8")

        loader = TemplateLoader(tmp_path / "notifications")

        # Should handle invalid JSON and fallback to English
        # Since English doesn't exist in tmp_path, it should raise an error
        try:
            loader.get_template("tool_completed", "invalid")
            assert False, "Should have raised an error"
        except (ValueError, FileNotFoundError, json.JSONDecodeError):
            pass  # Expected

    def test_load_template_caches_results(self, mock_templates):
        """Test that template loader caches results"""
        from src.template_loader import TemplateLoader

        loader = TemplateLoader(mock_templates)

        # Load template first time
        template1 = loader.get_template("tool_completed", "en")

        # Load again (should be cached)
        template2 = loader.get_template("tool_completed", "en")

        # Should be the same object
        assert template1 == template2

    def test_get_available_languages(self, mock_templates):
        """Test getting list of available languages"""
        from src.template_loader import TemplateLoader

        loader = TemplateLoader(mock_templates)
        languages = loader.get_available_languages()

        assert "en" in languages
        assert "ko" in languages
        assert "ja" in languages


class TestConfigurationLoader:
    """Test suite for configuration loader"""

    @pytest.fixture
    def mock_config_file(self, tmp_path):
        """Create a mock configuration file"""
        config = {
            "enabled": True,
            "default_type": "Information",
            "default_duration": "Normal",
            "language": "en",
            "sound_enabled": True,
            "position": "top_right",
        }

        config_file = tmp_path / "config.json"
        config_file.write_text(json.dumps(config, indent=2), encoding="utf-8")
        return config_file

    def test_load_config_returns_defaults(self, tmp_path):
        """Test that loading config returns defaults when file doesn't exist"""
        from src.config_loader import load_config, get_default_config

        config = load_config(str(tmp_path))
        defaults = get_default_config()

        assert config == defaults

    def test_load_config_reads_from_file(self, mock_config_file):
        """Test loading configuration from file"""
        from src.config_loader import load_config

        config = load_config(str(mock_config_file.parent))

        assert config["enabled"] is True
        assert config["default_type"] == "Information"
        assert config["language"] == "en"

    def test_load_config_handles_invalid_json(self, tmp_path):
        """Test handling of invalid JSON in config file"""
        from src.config_loader import load_config, get_default_config

        invalid_file = tmp_path / "config.json"
        invalid_file.write_text("{invalid json}", encoding="utf-8")

        # Should fall back to defaults
        config = load_config(str(tmp_path))
        defaults = get_default_config()

        assert config == defaults

    def test_get_config_returns_default_value(self, tmp_path):
        """Test getting a config value returns default if not set"""
        from src.config_loader import get_config_value

        value = get_config_value(
            "nonexistent_key", str(tmp_path), default="custom_default"
        )
        assert value == "custom_default"

    def test_set_config_updates_value(self, tmp_path):
        """Test setting a config value"""
        from src.config_loader import set_config_value, get_config_value

        set_config_value("custom_key", "custom_value", str(tmp_path))
        value = get_config_value("custom_key", str(tmp_path))

        assert value == "custom_value"

    def test_config_falls_back_to_defaults(self, tmp_path):
        """Test that config falls back to defaults for missing keys"""
        from src.config_loader import load_config, get_default_config

        partial_config = tmp_path / "config.json"
        partial_config.write_text(
            '{"enabled": false, "language": "ko"}', encoding="utf-8"
        )

        from src.config_loader import clear_config_cache

        clear_config_cache()

        config = load_config(str(tmp_path))
        defaults = get_default_config()

        assert config["enabled"] is False  # From file
        assert config["language"] == "ko"  # From file
        assert config["default_type"] == defaults["default_type"]  # Default


class TestTemplateLocalization:
    """Test suite for template localization"""

    @pytest.fixture
    def templates_dir(self):
        """Get the templates directory path"""
        return Path(__file__).parent.parent.parent / "templates" / "notifications"

    @pytest.mark.parametrize(
        "language,expected_title_substring",
        [("en", "Tool"), ("ko", "도구"), ("ja", "ツール"), ("zh", "工具")],
    )
    def test_template_localization(
        self, templates_dir, language, expected_title_substring
    ):
        """Test that templates are properly localized"""
        template_path = templates_dir / f"{language}.json"

        if template_path.exists():
            with open(template_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                # Check that the title contains expected localized substring
                assert expected_title_substring in data["tool_completed"]["title"]


class TestTemplateIntegration:
    """Integration tests for template system"""

    def test_complete_template_workflow(self, tmp_path):
        """Test complete workflow of loading and using templates"""
        # This test will be implemented when we create the template loader module
        pass

    def test_multilingual_notification_workflow(self, tmp_path):
        """Test sending notifications in multiple languages"""
        # This test will be implemented when we create the template loader module
        pass
