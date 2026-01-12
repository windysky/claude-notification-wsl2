# test_template_coverage.py
# Additional tests to improve coverage to 85%+
#
# Author: Claude Code TDD Implementation
# Version: 1.0.0

import json
import pytest


class TestTemplateLoaderCoverage:
    """Additional tests to improve template loader coverage"""

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
        }

        templates_dir = tmp_path / "notifications"
        templates_dir.mkdir()

        for filename, content in templates.items():
            (templates_dir / filename).write_text(
                json.dumps(content, ensure_ascii=False), encoding="utf-8"
            )

        return templates_dir

    def test_get_title(self, mock_templates):
        """Test get_title method"""
        from src.template_loader import TemplateLoader

        loader = TemplateLoader(mock_templates)
        title = loader.get_title("tool_completed", "en")

        assert title == "Tool Completed"

    def test_get_message(self, mock_templates):
        """Test get_message method"""
        from src.template_loader import TemplateLoader

        loader = TemplateLoader(mock_templates)
        message = loader.get_message("tool_completed", "en")

        assert message == "Tool finished successfully"

    def test_get_notification_data_basic(self, mock_templates):
        """Test get_notification_data without formatting"""
        from src.template_loader import TemplateLoader

        loader = TemplateLoader(mock_templates)
        data = loader.get_notification_data("tool_completed", "en")

        assert data["title"] == "Tool Completed"
        assert data["message"] == "Tool finished successfully"

    def test_get_notification_data_with_formatting(self, tmp_path):
        """Test get_notification_data with message formatting"""
        from src.template_loader import TemplateLoader

        # Create template with placeholders
        templates_dir = tmp_path / "notifications"
        templates_dir.mkdir()

        template = {
            "test_key": {
                "title": "Test Title",
                "message": "Hello {name}, you have {count} notifications",
            }
        }

        (templates_dir / "en.json").write_text(
            json.dumps(template, ensure_ascii=False), encoding="utf-8"
        )

        loader = TemplateLoader(templates_dir)
        data = loader.get_notification_data("test_key", "en", name="World", count=5)

        assert data["message"] == "Hello World, you have 5 notifications"

    def test_get_notification_data_invalid_formatting(self, tmp_path):
        """Test get_notification_data with invalid formatting parameters"""
        from src.template_loader import TemplateLoader

        templates_dir = tmp_path / "notifications"
        templates_dir.mkdir()

        template = {
            "test_key": {
                "title": "Test",
                "message": "No placeholders here",
            }
        }

        (templates_dir / "en.json").write_text(
            json.dumps(template, ensure_ascii=False), encoding="utf-8"
        )

        loader = TemplateLoader(templates_dir)

        # Pass extra parameters that don't match placeholders
        data = loader.get_notification_data("test_key", "en", invalid_param="value")

        # Should return original message
        assert data["message"] == "No placeholders here"

    def test_clear_cache(self, mock_templates):
        """Test cache clearing"""
        from src.template_loader import TemplateLoader

        loader = TemplateLoader(mock_templates)

        # Load template
        template1 = loader.get_template("tool_completed", "en")

        # Clear cache
        loader.clear_cache()

        # Load again (should not be cached)
        template2 = loader.get_template("tool_completed", "en")

        # Values should be the same
        assert template1 == template2

    def test_get_template_key_error(self, mock_templates):
        """Test get_template with non-existent key"""
        from src.template_loader import TemplateLoader

        loader = TemplateLoader(mock_templates)

        with pytest.raises(KeyError):
            loader.get_template("nonexistent_key", "en")

    def test_get_template_unsupported_language_no_english(self, tmp_path):
        """Test get_template with unsupported language and no English fallback"""
        from src.template_loader import TemplateLoader

        # Create templates without English
        templates_dir = tmp_path / "notifications"
        templates_dir.mkdir()

        template = {"test_key": {"title": "Test", "message": "Test message"}}

        (templates_dir / "ko.json").write_text(
            json.dumps(template, ensure_ascii=False), encoding="utf-8"
        )

        loader = TemplateLoader(templates_dir)

        # Request unsupported language when English doesn't exist
        # Should raise FileNotFoundError when trying to load English fallback
        with pytest.raises(FileNotFoundError):
            loader.get_template("test_key", "fr")

    def test_load_template_file_not_found(self, tmp_path):
        """Test _load_template_file with missing file"""
        from src.template_loader import TemplateLoader

        templates_dir = tmp_path / "notifications"
        templates_dir.mkdir()

        loader = TemplateLoader(templates_dir)

        with pytest.raises(FileNotFoundError):
            loader._load_template_file("missing.json")

    def test_global_template_loader(self, tmp_path):
        """Test global template loader functions"""
        from src.template_loader import (
            get_template_loader,
            get_template,
        )
        from src.config_loader import clear_config_cache as config_clear_cache

        # Clear any existing cache
        config_clear_cache()

        templates_dir = tmp_path / "notifications"
        templates_dir.mkdir()

        template = {
            "test_key": {
                "title": "Global Test",
                "message": "Global test message",
            }
        }

        (templates_dir / "en.json").write_text(
            json.dumps(template, ensure_ascii=False), encoding="utf-8"
        )

        # Get global loader with custom path
        get_template_loader(templates_dir)
        template_data = get_template("test_key", "en")

        assert template_data["title"] == "Global Test"


class TestConfigLoaderCoverage:
    """Additional tests to improve config loader coverage"""

    def test_config_exists(self, tmp_path):
        """Test config_exists function"""
        from src.config_loader import config_exists

        # Test with non-existent config
        result = config_exists(str(tmp_path))
        assert result is False

        # Create config file
        config_file = tmp_path / "config.json"
        config_file.write_text('{"enabled": true}', encoding="utf-8")

        result = config_exists(str(tmp_path))
        assert result is True

    def test_get_config_path(self, tmp_path):
        """Test get_config_path function"""
        from src.config_loader import get_config_path

        config_path = get_config_path(str(tmp_path))

        assert config_path == tmp_path / "config.json"

    def test_reset_config(self, tmp_path):
        """Test reset_config function"""
        from src.config_loader import (
            reset_config,
            load_config,
            get_default_config,
            clear_config_cache,
        )

        # Create a custom config
        config_file = tmp_path / "config.json"
        config_file.write_text('{"enabled": false, "language": "ko"}', encoding="utf-8")

        clear_config_cache()

        # Reset to defaults
        reset_config(str(tmp_path))

        # Load and verify
        config = load_config(str(tmp_path))
        defaults = get_default_config()

        assert config == defaults

    def test_merge_config(self):
        """Test merge_config function"""
        from src.config_loader import merge_config

        base = {"enabled": True, "language": "en", "default_type": "Information"}
        override = {"language": "ko", "sound_enabled": False}

        merged = merge_config(base, override)

        assert merged["enabled"] is True  # From base
        assert merged["language"] == "ko"  # Overridden
        assert merged["sound_enabled"] is False  # From override
        assert merged["default_type"] == "Information"  # From base

    def test_validate_config_invalid_types(self):
        """Test validate_config with invalid types"""
        from src.config_loader import validate_config

        # Invalid enabled type
        config = {
            "enabled": "true",  # Should be boolean
            "default_type": "Information",
            "default_duration": "Normal",
            "language": "en",
        }

        is_valid, errors = validate_config(config)
        assert is_valid is False
        assert len(errors) > 0

    def test_get_config_value_missing_key_with_default(self, tmp_path):
        """Test get_config_value with missing key and default"""
        from src.config_loader import get_config_value

        value = get_config_value("missing_key", str(tmp_path), default="my_default")

        assert value == "my_default"

    def test_save_config_creates_directory(self, tmp_path):
        """Test save_config creates directory if needed"""
        from src.config_loader import save_config, load_config, clear_config_cache

        new_dir = tmp_path / "new_config_dir"

        config = {"enabled": True, "language": "ja"}

        clear_config_cache()
        save_config(config, str(new_dir))

        # Verify directory was created
        assert new_dir.exists()

        # Verify config was saved
        loaded = load_config(str(new_dir))
        assert loaded["language"] == "ja"
