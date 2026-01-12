# test_config_loader.py
# Python tests for configuration loader
#
# Author: Claude Code TDD Implementation
# Version: 1.0.0

import pytest
import json


class TestConfigLoaderDefaults:
    """Test suite for default configuration values"""

    def test_default_config_values(self):
        """Test that default configuration has all required keys"""
        from src.config_loader import get_default_config

        defaults = get_default_config()

        expected_keys = [
            "enabled",
            "default_type",
            "default_duration",
            "language",
            "sound_enabled",
            "position",
        ]

        for key in expected_keys:
            assert key in defaults, f"Missing default key: {key}"

    def test_default_config_types(self):
        """Test that default configuration has correct types"""
        from src.config_loader import get_default_config

        defaults = get_default_config()

        assert isinstance(defaults["enabled"], bool)
        assert isinstance(defaults["default_type"], str)
        assert isinstance(defaults["default_duration"], str)
        assert isinstance(defaults["language"], str)
        assert isinstance(defaults["sound_enabled"], bool)
        assert isinstance(defaults["position"], str)

    def test_default_config_valid_values(self):
        """Test that default configuration has valid values"""
        from src.config_loader import get_default_config

        defaults = get_default_config()

        # Check default_type is valid
        assert defaults["default_type"] in [
            "Information",
            "Warning",
            "Error",
            "Success",
        ]

        # Check default_duration is valid
        assert defaults["default_duration"] in ["Short", "Normal", "Long"]

        # Check language is supported
        assert defaults["language"] in ["en", "ko", "ja", "zh"]

        # Check position is valid
        assert defaults["position"] in [
            "top_right",
            "top_left",
            "bottom_right",
            "bottom_left",
        ]


class TestConfigLoaderLoad:
    """Test suite for loading configuration"""

    @pytest.fixture
    def temp_config_dir(self, tmp_path):
        """Create temporary config directory"""
        config_dir = tmp_path / ".wsl-toast"
        config_dir.mkdir()
        return config_dir

    @pytest.fixture
    def valid_config_file(self, temp_config_dir):
        """Create a valid configuration file"""
        config = {
            "enabled": True,
            "default_type": "Success",
            "default_duration": "Long",
            "language": "ko",
            "sound_enabled": False,
            "position": "bottom_left",
        }

        config_file = temp_config_dir / "config.json"
        config_file.write_text(json.dumps(config, indent=2), encoding="utf-8")
        return config_file

    def test_load_config_from_file(self, valid_config_file):
        """Test loading configuration from file"""
        from src.config_loader import load_config

        config = load_config(str(valid_config_file.parent))

        assert config["enabled"] is True
        assert config["default_type"] == "Success"
        assert config["default_duration"] == "Long"
        assert config["language"] == "ko"
        assert config["sound_enabled"] is False
        assert config["position"] == "bottom_left"

    def test_load_config_falls_back_to_defaults(self, tmp_path):
        """Test that loading config falls back to defaults when file doesn't exist"""
        from src.config_loader import load_config, get_default_config

        config = load_config(str(tmp_path))
        defaults = get_default_config()

        assert config == defaults

    def test_load_config_with_partial_config(self, temp_config_dir):
        """Test loading partial configuration merges with defaults"""
        partial_config = temp_config_dir / "config.json"
        partial_config.write_text(
            '{"enabled": false, "language": "ja"}', encoding="utf-8"
        )

        from src.config_loader import load_config

        config = load_config(str(temp_config_dir))

        assert config["enabled"] is False  # From file
        assert config["language"] == "ja"  # From file
        assert config["default_type"] == "Information"  # Default

    def test_load_config_with_invalid_json(self, temp_config_dir):
        """Test loading configuration with invalid JSON"""
        invalid_file = temp_config_dir / "config.json"
        invalid_file.write_text("{invalid json content}", encoding="utf-8")

        from src.config_loader import load_config, get_default_config

        # Should fall back to defaults
        config = load_config(str(temp_config_dir))
        defaults = get_default_config()

        assert config == defaults

    def test_load_config_caches_result(self, valid_config_file, monkeypatch):
        """Test that loading configuration caches the result"""
        from src.config_loader import load_config, clear_config_cache

        clear_config_cache()

        # Load first time
        config1 = load_config(str(valid_config_file.parent))

        # Modify file
        valid_config_file.write_text('{"enabled": false}', encoding="utf-8")

        # Load second time (should be cached)
        config2 = load_config(str(valid_config_file.parent))

        assert config1 == config2
        assert config1["enabled"] is True  # Should still be True from cache

    def test_clear_cache_works(self, valid_config_file, monkeypatch):
        """Test that clearing cache works correctly"""
        from src.config_loader import load_config, clear_config_cache

        clear_config_cache()

        # Load first time
        config1 = load_config(str(valid_config_file.parent))
        assert config1["enabled"] is True

        # Modify file
        valid_config_file.write_text('{"enabled": false}', encoding="utf-8")

        # Clear cache
        clear_config_cache()

        # Load again (should read new file)
        config2 = load_config(str(valid_config_file.parent))

        assert config2["enabled"] is False


class TestConfigLoaderGetSet:
    """Test suite for getting and setting configuration values"""

    @pytest.fixture
    def temp_config_dir(self, tmp_path):
        """Create temporary config directory"""
        config_dir = tmp_path / ".wsl-toast"
        config_dir.mkdir()
        return config_dir

    def test_get_config_value(self, temp_config_dir):
        """Test getting a specific configuration value"""
        from src.config_loader import get_config_value, clear_config_cache

        # Test with default
        value = get_config_value("default_type", str(temp_config_dir))
        assert value == "Information"

        # Create config with custom value
        config_file = temp_config_dir / "config.json"
        config_file.write_text('{"default_type": "Warning"}', encoding="utf-8")

        # Clear cache to force reload
        clear_config_cache()

        value = get_config_value("default_type", str(temp_config_dir))
        assert value == "Warning"

    def test_get_config_value_with_default(self, temp_config_dir):
        """Test getting config value with custom default"""
        from src.config_loader import get_config_value

        value = get_config_value(
            "nonexistent_key", str(temp_config_dir), default="custom_default"
        )
        assert value == "custom_default"

    def test_set_config_value(self, temp_config_dir):
        """Test setting a configuration value"""
        from src.config_loader import set_config_value, get_config_value

        # Set a value
        set_config_value("default_type", "Error", str(temp_config_dir))

        # Get the value
        value = get_config_value("default_type", str(temp_config_dir))
        assert value == "Error"

    def test_set_config_value_creates_file(self, temp_config_dir):
        """Test that setting config value creates file if it doesn't exist"""
        from src.config_loader import set_config_value

        config_file = temp_config_dir / "config.json"

        assert not config_file.exists()

        set_config_value("enabled", True, str(temp_config_dir))

        assert config_file.exists()

        # Verify content
        data = json.loads(config_file.read_text(encoding="utf-8"))
        assert data["enabled"] is True

    def test_set_config_value_updates_existing(self, temp_config_dir):
        """Test that setting config value updates existing file"""
        from src.config_loader import set_config_value

        config_file = temp_config_dir / "config.json"
        config_file.write_text('{"enabled": true, "language": "en"}', encoding="utf-8")

        set_config_value("language", "ko", str(temp_config_dir))

        data = json.loads(config_file.read_text(encoding="utf-8"))
        assert data["enabled"] is True  # Should preserve existing
        assert data["language"] == "ko"  # Should update


class TestConfigValidator:
    """Test suite for configuration validation"""

    def test_validate_valid_config(self):
        """Test validating a valid configuration"""
        from src.config_loader import validate_config

        config = {
            "enabled": True,
            "default_type": "Information",
            "default_duration": "Normal",
            "language": "en",
            "sound_enabled": True,
            "position": "top_right",
        }

        is_valid, errors = validate_config(config)

        assert is_valid is True
        assert len(errors) == 0

    def test_validate_invalid_type(self):
        """Test validating config with invalid type"""
        from src.config_loader import validate_config

        config = {
            "enabled": True,
            "default_type": "InvalidType",  # Invalid
            "default_duration": "Normal",
            "language": "en",
            "sound_enabled": True,
            "position": "top_right",
        }

        is_valid, errors = validate_config(config)

        assert is_valid is False
        assert len(errors) > 0
        assert any("default_type" in str(e) for e in errors)

    def test_validate_invalid_duration(self):
        """Test validating config with invalid duration"""
        from src.config_loader import validate_config

        config = {
            "enabled": True,
            "default_type": "Information",
            "default_duration": "InvalidDuration",  # Invalid
            "language": "en",
            "sound_enabled": True,
            "position": "top_right",
        }

        is_valid, errors = validate_config(config)

        assert is_valid is False
        assert len(errors) > 0

    def test_validate_invalid_language(self):
        """Test validating config with invalid language"""
        from src.config_loader import validate_config

        config = {
            "enabled": True,
            "default_type": "Information",
            "default_duration": "Normal",
            "language": "invalid",  # Invalid
            "sound_enabled": True,
            "position": "top_right",
        }

        is_valid, errors = validate_config(config)

        assert is_valid is False
        assert len(errors) > 0

    def test_validate_invalid_position(self):
        """Test validating config with invalid position"""
        from src.config_loader import validate_config

        config = {
            "enabled": True,
            "default_type": "Information",
            "default_duration": "Normal",
            "language": "en",
            "sound_enabled": True,
            "position": "invalid_position",  # Invalid
        }

        is_valid, errors = validate_config(config)

        assert is_valid is False
        assert len(errors) > 0
