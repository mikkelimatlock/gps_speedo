import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SpeedUnit { kmh, mph }
enum SpeedometerStyle { digital, analog }

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  SpeedUnit _speedUnit = SpeedUnit.kmh;
  SpeedometerStyle _speedometerStyle = SpeedometerStyle.digital;
  bool _showCoordinates = false;
  bool _showDistance = false;
  bool _showTripTime = false;
  bool _showAccuracy = false;

  bool get isDarkMode => _isDarkMode;
  SpeedUnit get speedUnit => _speedUnit;
  SpeedometerStyle get speedometerStyle => _speedometerStyle;
  bool get showCoordinates => _showCoordinates;
  bool get showDistance => _showDistance;
  bool get showTripTime => _showTripTime;
  bool get showAccuracy => _showAccuracy;

  String get speedUnitString => _speedUnit == SpeedUnit.kmh ? 'km/h' : 'mph';

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _speedUnit = SpeedUnit.values[prefs.getInt('speedUnit') ?? 0];
    _speedometerStyle = SpeedometerStyle.values[prefs.getInt('speedometerStyle') ?? 0];
    _showCoordinates = prefs.getBool('showCoordinates') ?? false;
    _showDistance = prefs.getBool('showDistance') ?? false;
    _showTripTime = prefs.getBool('showTripTime') ?? false;
    _showAccuracy = prefs.getBool('showAccuracy') ?? false;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    notifyListeners();
  }

  Future<void> setSpeedUnit(SpeedUnit unit) async {
    _speedUnit = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('speedUnit', unit.index);
    notifyListeners();
  }

  Future<void> setSpeedometerStyle(SpeedometerStyle style) async {
    _speedometerStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('speedometerStyle', style.index);
    notifyListeners();
  }

  Future<void> setShowCoordinates(bool value) async {
    _showCoordinates = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showCoordinates', value);
    notifyListeners();
  }

  Future<void> setShowDistance(bool value) async {
    _showDistance = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showDistance', value);
    notifyListeners();
  }

  Future<void> setShowTripTime(bool value) async {
    _showTripTime = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showTripTime', value);
    notifyListeners();
  }

  Future<void> setShowAccuracy(bool value) async {
    _showAccuracy = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showAccuracy', value);
    notifyListeners();
  }

  double convertSpeed(double speedMps) {
    if (_speedUnit == SpeedUnit.kmh) {
      return speedMps * 3.6;
    } else {
      return speedMps * 2.237;
    }
  }
}