import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'speed_units.dart';
import 'gps_service.dart';
import 'color_themes.dart';

void main() {
  runApp(const SpeedoApp());
}

// Entry point for future overlay mode
void mainOverlay() {
  // TODO: Initialize overlay-specific setup
  runApp(const SpeedoApp(isOverlayMode: true));
}

class SpeedoApp extends StatelessWidget {
  final bool isOverlayMode;
  
  const SpeedoApp({super.key, this.isOverlayMode = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speedo',
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
    _enableWakelock();
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      // Wake lock not supported on this platform, continue normally
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    WakelockPlus.disable();
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            
            if (isLandscape) {
              return _buildLandscapeLayout(speedText, currentTheme);
            } else {
              return _buildPortraitLayout(speedText, currentTheme);
            }
          },
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(String speedText, ColorTheme currentTheme) {
    return Column(
      children: [
        // Speed area - takes most space
        Expanded(
          flex: 7,
          child: GestureDetector(
            onTap: _cycleUnit,
            child: Container(
              width: double.infinity,
              color: Colors.transparent,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_errorMessage.isNotEmpty)
                    Flexible(
                      child: Text(
                        _errorMessage,
                        style: TextStyle(
                          color: currentTheme.speedText,
                          fontSize: 18,
                          fontFamily: 'DIN1451Alt',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else ...[
                    Flexible(
                      flex: 3,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          speedText,
                          style: TextStyle(
                            fontSize: 200,
                            fontWeight: FontWeight.w300,
                            color: currentTheme.speedText,
                            fontFamily: 'DIN1451Alt',
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      flex: 1,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _currentUnit.label,
                          style: TextStyle(
                            fontSize: 64,
                            color: currentTheme.unitText,
                            fontFamily: 'DIN1451Alt',
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Compass area - compact but tappable
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: _cycleTheme,
            child: Container(
              width: double.infinity,
              color: Colors.transparent,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    flex: 2,
                    child: Icon(
                      Icons.navigation,
                      size: 100,
                      color: currentTheme.headingText,
                    ),
                  ),
                  Flexible(
                    flex: 1,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        GpsService.formatHeading(_heading),
                        style: TextStyle(
                          fontSize: 96,
                          color: currentTheme.headingText,
                          fontFamily: 'DIN1451Alt',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(String speedText, ColorTheme currentTheme) {
    return Row(
      children: [
        // Speed area - takes majority of space
        Expanded(
          flex: 65,
          child: GestureDetector(
            onTap: _cycleUnit,
            child: Container(
              height: double.infinity,
              color: Colors.transparent,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_errorMessage.isNotEmpty)
                    Flexible(
                      child: Text(
                        _errorMessage,
                        style: TextStyle(
                          color: currentTheme.speedText,
                          fontSize: 16,
                          fontFamily: 'DIN1451Alt',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else ...[
                    Flexible(
                      flex: 3,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          speedText,
                          style: TextStyle(
                            fontSize: 120,
                            fontWeight: FontWeight.w300,
                            color: currentTheme.speedText,
                            fontFamily: 'DIN1451Alt',
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      flex: 1,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _currentUnit.label,
                          style: TextStyle(
                            fontSize: 24,
                            color: currentTheme.unitText,
                            fontFamily: 'DIN1451Alt',
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Compass area - smaller but prominent
        Expanded(
          flex: 35,
          child: GestureDetector(
            onTap: _cycleTheme,
            child: Container(
              height: double.infinity,
              color: Colors.transparent,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    flex: 2,
                    child: Icon(
                      Icons.navigation,
                      size: 32,
                      color: currentTheme.headingText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    flex: 1,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        GpsService.formatHeading(_heading),
                        style: TextStyle(
                          fontSize: 18,
                          color: currentTheme.headingText,
                          fontFamily: 'DIN1451Alt',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}