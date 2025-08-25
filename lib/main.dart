import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'speed_units.dart';
import 'gps_service.dart';
import 'color_themes.dart';
import 'dart:math' as math; // Import for math.pi

void main() {
  runApp(const SpeedoApp());
}

// Entry point for overlay window
@pragma("vm:entry-point")
void overlayMain() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: 180,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.7), width: 2),
        ),
        child: Stack(
          children: [
            const Center(
              child: Text(
                'GPS\nSPEEDO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.green, 
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => FlutterOverlayWindow.closeOverlay(),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ));
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

class _SpeedometerScreenState extends State<SpeedometerScreen> with WidgetsBindingObserver {
  double _speed = 0.0;
  double _heading = -1.0;
  SpeedUnit _currentUnit = SpeedUnit.kmh;
  int _currentThemeIndex = 0;
  StreamSubscription<Position>? _positionSubscription;
  String _errorMessage = '';
  bool _isInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        // App went to background (home key pressed or task switch)
        if (!_isInBackground) {
          _isInBackground = true;
          _handleBackgroundTransition();
        }
        break;
      case AppLifecycleState.resumed:
        // App came back to foreground
        _isInBackground = false;
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _handleBackgroundTransition() {
    // When app goes to background, show floating window if GPS is active and no error
    print('App went to background, checking conditions for floating window...');
    print('Speed: $_speed, Error: $_errorMessage');
    // Temporarily disable auto-trigger for debugging
    // if (_speed >= 0 && _errorMessage.isEmpty) {
    //   _showFloatingWindow();
    // }
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
        onError: (error) {
          // Only show persistent GPS errors, not temporary signal issues
          final errorString = error.toString().toLowerCase();
          if (!errorString.contains('timeout') && !errorString.contains('temporarily')) {
            setState(() => _errorMessage = 'GPS error: $error');
          }
        },
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

  Future<void> _showFloatingWindow() async {
    try {
      // Share current unit with overlay
      await FlutterOverlayWindow.shareData({
        'action': 'updateUnit',
        'unitIndex': _currentUnit.index,
      });

      // Show the overlay with safer positioning
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "GPS Speedometer",
        overlayContent: 'GPS Speedometer Overlay',
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.none,
        width: 180,
        height: 100,
      );
    } catch (e) {
      print('Error showing floating window: $e');
    }
  }

  Future<void> _closeFloatingWindow() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      print('Error closing floating window: $e');
    }
  }
  
  String _getSpeedDisplayText(double displaySpeed) {
    if (_speed < 1.0 && (_heading < 0.0 || _heading >= 360.0)) {
      return '--';
    }
    return displaySpeed.toStringAsFixed(1);
  }

  Widget _buildSpeedDisplay(String speedText, ColorTheme currentTheme, double fontSize, {bool isLandscape = false}) {
    if (speedText == '--') {
      return Text(
        speedText,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w300,
          color: currentTheme.speedText,
          fontFamily: 'DIN1451Alt',
        ),
      );
    }

    // Split speed into integral and decimal parts
    final parts = speedText.split('.');
    final integralPart = parts[0];
    final decimalPart = parts.length > 1 ? '.${parts[1]}' : '.0';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          integralPart,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w300,
            color: currentTheme.speedText,
            fontFamily: 'DIN1451Alt',
          ),
        ),
        Text(
          decimalPart,
          style: TextStyle(
            fontSize: fontSize * 0.5, // 60% of main font size
            fontWeight: FontWeight.w300,
            color: currentTheme.speedTextSub,
            fontFamily: 'DIN1451Alt',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final displaySpeed = _currentUnit.convert(_speed);
    final speedText = _getSpeedDisplayText(displaySpeed);
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
        // Speed area - takes most space, precise tap targets on text only
        Expanded(
          flex: 7,
          child: Container(
            width: double.infinity,
            color: Colors.transparent,
            padding: const EdgeInsets.all(4),
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
                    flex: 4,
                    child: GestureDetector(
                      onTap: _cycleTheme, // Tap speed to cycle theme
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: _buildSpeedDisplay(speedText, currentTheme, 200),
                      ),
                    ),
                  ),
                  Flexible(
                    flex: 1,
                    child: GestureDetector(
                      onTap: _cycleUnit, // clicking on unit to cycle unit is more intuitive
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Text(
                          _currentUnit.label,
                          style: TextStyle(
                            fontSize: 80,
                            color: currentTheme.unitText,
                            fontFamily: 'DIN1451Alt',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Compass area - compact but fully tappable for floating window
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: _showFloatingWindow, // Tap navigation icon to show floating window
            onLongPress: _closeFloatingWindow, // Long press to close floating window
            child: Container(
              width: double.infinity,
              color: Colors.transparent,
              padding: const EdgeInsets.all(2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    flex: 3,
                    child: Transform.rotate(
                      angle: (_heading >= 0 && _heading < 360) ? (_heading * math.pi / 180.0) : 0,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Icon(
                          Icons.navigation,
                          size: 80,
                          color: currentTheme.headingText,
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    flex: 1,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Text(
                        GpsService.formatHeading(_heading),
                        style: TextStyle(
                          fontSize: 50,
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
        // Speed area - takes majority of space, precise tap targets on text only
        Expanded(
          flex: 66,
          child: Container(
            height: double.infinity,
            color: Colors.transparent,
            padding: const EdgeInsets.all(3),
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
                    flex: 4,
                    child: GestureDetector(
                      onTap: _cycleTheme,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: _buildSpeedDisplay(speedText, currentTheme, 160, isLandscape: true),
                      ),
                    ),
                  ),
                  Flexible(
                    flex: 1,
                    child: GestureDetector(
                      onTap: _cycleUnit,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Text(
                          _currentUnit.label,
                          style: TextStyle(
                            fontSize: 50,
                            color: currentTheme.unitText,
                            fontFamily: 'DIN1451Alt',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Compass area - smaller but fully tappable for floating window
        Expanded(
          flex: 33,
          child: GestureDetector(
            onTap: _showFloatingWindow,
            onLongPress: _closeFloatingWindow, // Long press to close floating window
            child: Container(
              height: double.infinity,
              color: Colors.transparent,
              padding: const EdgeInsets.all(2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    flex: 3,
                    child: Transform.rotate(
                      angle: (_heading >= 0 && _heading < 360) ? (_heading * math.pi / 180.0) : 0,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Icon(
                          Icons.navigation,
                          size: 60,
                          color: currentTheme.headingText,
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    flex: 1,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Text(
                        GpsService.formatHeading(_heading),
                        style: TextStyle(
                          fontSize: 30,
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

class SimpleOverlaySpeedometer extends StatelessWidget {
  const SimpleOverlaySpeedometer({super.key});

  @override
  Widget build(BuildContext context) {
    print("SimpleOverlaySpeedometer build() called");
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 200,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.9), // Highly visible red background
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.yellow, width: 3), // Bright yellow border
        ),
        child: Stack(
          children: [
            // Test content - much more visible
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'FLOATING',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'WINDOW',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.yellow,
                    ),
                  ),
                  const Text(
                    'WORKING!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Close button
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: () => FlutterOverlayWindow.closeOverlay(),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 255, 171, 16), // call the current background colour defined as in `color_themes.dart`
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}