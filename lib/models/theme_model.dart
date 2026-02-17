import '../config/color_themes.dart';

/// Theme model that wraps ColorThemes with rotation and state management.
/// Holds all possible color palettes via delegation, exposing only the current set.
class ThemeModel {
  final int _currentIndex;

  const ThemeModel({int currentIndex = 0}) : _currentIndex = currentIndex;

  /// Get the current active color theme
  ColorTheme get current => ColorThemes.getTheme(_currentIndex);

  /// Get the name of the current theme
  String get currentSetName => current.name;

  /// Get the current theme index
  int get currentIndex => _currentIndex;

  /// Rotate to the next theme (circular)
  ThemeModel rotate() {
    return ThemeModel(
      currentIndex: ColorThemes.getNextThemeIndex(_currentIndex),
    );
  }

  /// Create a copy with an updated theme index
  ThemeModel copyWith({int? currentIndex}) {
    return ThemeModel(
      currentIndex: currentIndex ?? _currentIndex,
    );
  }
}
