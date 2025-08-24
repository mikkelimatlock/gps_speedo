import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'speed_units.dart';
import 'gps_service.dart';
import 'color_themes.dart';

void main() {
  runApp(const GpsSpeedoApp());
}

// Entry point for future overlay mode
void mainOverlay() {
  // TODO: Initialize overlay-specific setup
  runApp(const GpsSpeedoApp(isOverlayMode: true));
}

class GpsSpeedoApp extends StatelessWidget {
  final bool isOverlayMode;
  
  const GpsSpeedoApp({super.key, this.isOverlayMode = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Speedo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.green,
      ),
      home: SpeedometerScreen(isOverlayMode: isOverlayMode),
    );
  }
}

class SpeedometerScreen extends StatefulWidget {
  final bool isOverlayMode;
  
  const SpeedometerScreen({super.key, this.isOverlayMode = false});

  @override
  State<SpeedometerScreen> createState() => _SpeedometerScreenState();
}

class _SpeedometerScreenState extends State<SpeedometerScreen> {
  double _speed = 0.0;
  double _heading = -1.0;
  SpeedUnit _currentUnit = SpeedUnit.kmh;
  int _currentThemeIndex = 0;
  StreamSubscription<Position>? _positionSubscription;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeGps();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeGps() async {
    try {
      final serviceEnabled = await GpsService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _errorMessage = 'Location services disabled');
        return;
      }

      final permissionGranted = await GpsService.requestPermissions();
      if (!permissionGranted) {
        setState(() => _errorMessage = 'Location permission denied');
        return;
      }

      _positionSubscription = GpsService.positionStream.listen(
        _onPositionUpdate,
        onError: (error) => setState(() => _errorMessage = 'GPS error: $error'),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Failed to initialize GPS');
    }
  }

  void _onPositionUpdate(Position position) {
    setState(() {
      _speed = position.speed;
      _heading = position.heading;
      _errorMessage = '';
    });
  }

  void _cycleUnit() {
    setState(() {
      _currentUnit = _currentUnit.next;
    });
  }

  void _cycleTheme() {
    setState(() {
      _currentThemeIndex = ColorThemes.getNextThemeIndex(_currentThemeIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final displaySpeed = _currentUnit.convert(_speed);
    final speedText = displaySpeed.toStringAsFixed(0);
    final currentTheme = ColorThemes.getTheme(_currentThemeIndex);
    
    return Scaffold(
      backgroundColor: currentTheme.background,
      body: SafeArea(
        child: GestureDetector(
          onTap: _cycleTheme,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent,
            child: Column(
              children: [
                // Speed display - takes most space, tappable
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: _cycleUnit,
                    child: Container(
                      width: double.infinity,
                      color: Colors.transparent,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_errorMessage.isNotEmpty)
                            Text(
                              _errorMessage,
                              style: TextStyle(
                                color: currentTheme.speedText,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            )
                          else ...[
                            Text(
                              speedText,
                              style: TextStyle(
                                fontSize: 120,
                                fontWeight: FontWeight.w300,
                                color: currentTheme.speedText,
                              ),
                            ),
                            Text(
                              _currentUnit.label,
                              style: TextStyle(
                                fontSize: 24,
                                color: currentTheme.unitText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // Compass display - compact
                Expanded(
                  flex: 1,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.navigation,
                          size: 32,
                          color: currentTheme.headingText,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          GpsService.formatHeading(_heading),
                          style: TextStyle(
                            fontSize: 18,
                            color: currentTheme.headingText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}