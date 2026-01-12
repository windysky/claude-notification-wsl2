# template_loader.py
# Multi-language notification template loader with fallback support
#
# Author: Claude Code TDD Implementation
# Version: 1.0.0

import json
from pathlib import Path
from typing import Dict, Any, Optional


class TemplateLoader:
    """Load and manage notification templates with language fallback"""

    # Default templates directory
    DEFAULT_TEMPLATES_DIR = Path(__file__).parent.parent / "templates" / "notifications"

    # Supported languages
    SUPPORTED_LANGUAGES = ["en", "ko", "ja", "zh"]

    # Fallback language
    FALLBACK_LANGUAGE = "en"

    def __init__(self, templates_dir: Optional[Path] = None):
        """
        Initialize the template loader

        Args:
            templates_dir: Custom templates directory path (optional)
        """
        self.templates_dir = (
            Path(templates_dir) if templates_dir else self.DEFAULT_TEMPLATES_DIR
        )
        self._cache: Dict[str, Dict[str, Any]] = {}

    def get_available_languages(self) -> list[str]:
        """
        Get list of available template languages

        Returns:
            List of language codes with available templates
        """
        available = []
        for lang in self.SUPPORTED_LANGUAGES:
            template_file = self.templates_dir / f"{lang}.json"
            if template_file.exists():
                available.append(lang)
        return available

    def _load_template_file(self, language: str) -> Dict[str, Any]:
        """
        Load template file for a specific language

        Args:
            language: Language code (e.g., 'en', 'ko', 'ja', 'zh')

        Returns:
            Dictionary containing template data

        Raises:
            FileNotFoundError: If template file doesn't exist
            json.JSONDecodeError: If template file is invalid JSON
        """
        template_file = self.templates_dir / f"{language}.json"

        if not template_file.exists():
            raise FileNotFoundError(f"Template file not found: {template_file}")

        with open(template_file, "r", encoding="utf-8") as f:
            return json.load(f)

    def get_template(self, key: str, language: str = "en") -> Dict[str, str]:
        """
        Get a specific template with language fallback

        Args:
            key: Template key (e.g., 'tool_completed', 'error_occurred')
            language: Preferred language code (default: 'en')

        Returns:
            Dictionary with 'title' and 'message' keys

        Raises:
            KeyError: If template key doesn't exist in any language
            ValueError: If language is not supported
        """
        # Validate language
        if language not in self.SUPPORTED_LANGUAGES:
            # Try to fallback to English
            if language != self.FALLBACK_LANGUAGE:
                return self.get_template(key, self.FALLBACK_LANGUAGE)
            raise ValueError(f"Unsupported language: {language}")

        # Load template (with caching)
        if language not in self._cache:
            try:
                self._cache[language] = self._load_template_file(language)
            except (FileNotFoundError, json.JSONDecodeError):
                # Fallback to English if load fails
                if language != self.FALLBACK_LANGUAGE:
                    return self.get_template(key, self.FALLBACK_LANGUAGE)
                raise

        templates = self._cache[language]

        # Get template key
        if key not in templates:
            # Fallback to English if key doesn't exist
            if language != self.FALLBACK_LANGUAGE:
                return self.get_template(key, self.FALLBACK_LANGUAGE)
            raise KeyError(f"Template key not found: {key}")

        template = templates[key]

        # Validate template structure
        if "title" not in template or "message" not in template:
            raise ValueError(f"Invalid template structure for key: {key}")

        return template

    def get_title(self, key: str, language: str = "en") -> str:
        """
        Get template title

        Args:
            key: Template key
            language: Language code

        Returns:
            Template title string
        """
        template = self.get_template(key, language)
        return template["title"]

    def get_message(self, key: str, language: str = "en") -> str:
        """
        Get template message

        Args:
            key: Template key
            language: Language code

        Returns:
            Template message string
        """
        template = self.get_template(key, language)
        return template["message"]

    def get_notification_data(
        self, key: str, language: str = "en", **kwargs
    ) -> Dict[str, str]:
        """
        Get notification data with optional message formatting

        Args:
            key: Template key
            language: Language code
            **kwargs: Optional parameters for message formatting

        Returns:
            Dictionary with 'title' and 'message' keys
        """
        template = self.get_template(key, language)

        title = template["title"]
        message = template["message"]

        # Format message with kwargs if provided
        if kwargs:
            try:
                message = message.format(**kwargs)
            except (KeyError, ValueError):
                # If formatting fails, return original message
                pass

        return {"title": title, "message": message}

    def clear_cache(self) -> None:
        """Clear the template cache"""
        self._cache.clear()


# Global template loader instance
_global_loader: Optional[TemplateLoader] = None


def get_template_loader(templates_dir: Optional[Path] = None) -> TemplateLoader:
    """
    Get or create the global template loader instance

    Args:
        templates_dir: Custom templates directory (optional)

    Returns:
        TemplateLoader instance
    """
    global _global_loader

    if _global_loader is None or templates_dir is not None:
        _global_loader = TemplateLoader(templates_dir)

    return _global_loader


def get_template(key: str, language: str = "en") -> Dict[str, str]:
    """
    Convenience function to get a template

    Args:
        key: Template key
        language: Language code

    Returns:
        Dictionary with 'title' and 'message' keys
    """
    loader = get_template_loader()
    return loader.get_template(key, language)


def get_notification_data(key: str, language: str = "en", **kwargs) -> Dict[str, str]:
    """
    Convenience function to get notification data

    Args:
        key: Template key
        language: Language code
        **kwargs: Optional parameters for message formatting

    Returns:
        Dictionary with 'title' and 'message' keys
    """
    loader = get_template_loader()
    return loader.get_notification_data(key, language, **kwargs)
