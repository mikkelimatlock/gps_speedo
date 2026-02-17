import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/speed_unit.dart';
import '../config/color_themes.dart';
import '../services/logger.dart';

class SettingsProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  int _currentThemeIndex = 0;
  SpeedUnit _currentUnit = SpeedUnit.kmh;

  // Getters for read access
  int get currentThemeIndex => _currentThemeIndex;
  SpeedUnit get currentUnit => _currentUnit;
  ColorTheme get currentTheme => ColorThemes.getTheme(_currentThemeIndex);

  /// Constructor loads settings synchronously from pre-initialized SharedPreferences.
  /// SharedPreferences MUST be initialized before constructing this provider.
  SettingsProvider(this._prefs) {
    _loadSettings();
    Logger.info('Settings loaded: theme=$_currentThemeIndex, unit=${_currentUnit.label}', 'SettingsProvider');
  }

  void _loadSettings() {
    _currentThemeIndex = _prefs.getInt('themeIndex') ?? 0;
    final unitIndex = _prefs.getInt('unitIndex') ?? 0;
    _currentUnit = SpeedUnit.values[unitIndex.clamp(0, SpeedUnit.values.length - 1)];
    // No notifyListeners() — constructor runs before first build
  }

  /// Cycle to next theme with haptic feedback and persistence
  void cycleTheme() {
    HapticFeedback.lightImpact();
    _currentThemeIndex = ColorThemes.getNextThemeIndex(_currentThemeIndex);
    _prefs.setInt('themeIndex', _currentThemeIndex);
    Logger.debug('Theme cycled to index $_currentThemeIndex', 'SettingsProvider');
    notifyListeners();
  }

  /// Cycle to next speed unit with haptic feedback and persistence
  void cycleUnit() {
    HapticFeedback.lightImpact();
    _currentUnit = _currentUnit.next;
    _prefs.setInt('unitIndex', _currentUnit.index);
    Logger.debug('Unit cycled to ${_currentUnit.label}', 'SettingsProvider');
    notifyListeners();
  }
}
