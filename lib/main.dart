import 'package:flutter/material.dart';
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
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlaySpeedometer(),
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
    // Share unit change with overlay if active
    FlutterOverlayWindow.shareData({
      'action': 'updateSettings',
      'unitIndex': _currentUnit.index,
      'themeIndex': _currentThemeIndex,
    });
  }

  void _cycleTheme() {
    setState(() {
      _currentThemeIndex = ColorThemes.getNextThemeIndex(_currentThemeIndex);
    });
    // Share theme change with overlay if active
    FlutterOverlayWindow.shareData({
      'action': 'updateSettings',
      'themeIndex': _currentThemeIndex,
      'unitIndex': _currentUnit.index,
    });
  }

  Future<void> _showFloatingWindow() async {
    try {
      // Get screen dimensions for proportional sizing
      final screenSize = MediaQuery.of(context).size;
      final overlayWidth = (screenSize.width * 0.4).round(); // 40% of screen width
      final overlayHeight = (overlayWidth * 0.5).round(); // 2:1 aspect ratio
      
      // Share current unit and theme with overlay
      await FlutterOverlayWindow.shareData({
        'action': 'updateSettings',
        'unitIndex': _currentUnit.index,
        'themeIndex': _currentThemeIndex,
        'screenWidth': screenSize.width,
        'screenHeight': screenSize.height,
      });

      // Show the overlay with proportional sizing
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "GPS Speedometer",
        overlayContent: 'GPS Speedometer Overlay',
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.none,
        width: overlayWidth,
        height: overlayHeight,
      );
    } catch (e) {
      // Silent error handling - floating window issues shouldn't crash main app
    }
  }

  Future<void> _closeFloatingWindow() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      // Silent error handling - floating window issues shouldn't crash main app
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

class OverlaySpeedometer extends StatefulWidget {
  const OverlaySpeedometer({super.key});

  @override
  State<OverlaySpeedometer> createState() => _OverlaySpeedometerState();
}

class _OverlaySpeedometerState extends State<OverlaySpeedometer> {
  double _speed = 0.0;
  double _heading = -1.0;
  SpeedUnit _currentUnit = SpeedUnit.kmh;
  int _currentThemeIndex = 0;
  StreamSubscription<Position>? _positionSubscription;
  double _screenWidth = 400;

  @override
  void initState() {
    super.initState();
    _listenToMainAppMessages();
    _initializeGps();
  }

  void _listenToMainAppMessages() {
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map) {
        if (data.containsKey('unitIndex')) {
          setState(() {
            _currentUnit = SpeedUnit.values[data['unitIndex'] ?? 0];
          });
        }
        if (data.containsKey('themeIndex')) {
          setState(() {
            _currentThemeIndex = data['themeIndex'] ?? 0;
          });
        }
        if (data.containsKey('screenWidth')) {
          setState(() {
            _screenWidth = data['screenWidth']?.toDouble() ?? 400;
          });
        }
      }
    });
  }

  Future<void> _initializeGps() async {
    try {
      final serviceEnabled = await GpsService.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final permissionGranted = await GpsService.requestPermissions();
      if (!permissionGranted) return;

      _positionSubscription = GpsService.positionStream.listen(
        (position) {
          setState(() {
            _speed = position.speed;
            _heading = position.heading;
          });
        },
        onError: (error) {
          // Silent error handling for overlay
        },
      );
    } catch (e) {
      // Silent error handling for overlay
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ColorThemes.getTheme(_currentThemeIndex);
    final displaySpeed = _currentUnit.convert(_speed);
    // Per NOTES.txt: Speed section shows only integral part (no decimal, no unit)
    final speedText = displaySpeed < 1.0 ? '--' : displaySpeed.toInt().toString();
    
    // Calculate proportional dimensions
    final overlayWidth = (_screenWidth * 0.4);
    final overlayHeight = (overlayWidth * 0.5);
    final fontSize = (overlayWidth * 0.2); // Font size proportional to width

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        // Use SizedBox to fill the overlay window completely
        width: double.infinity,
        height: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            // Use proper color opacity without deprecated properties
            color: Color.fromARGB(
              ((currentTheme.background.a * 255.0).round() * 0.85).round(),
              (currentTheme.background.r * 255.0).round(),
              (currentTheme.background.g * 255.0).round(),
              (currentTheme.background.b * 255.0).round(),
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color.fromARGB(
                ((currentTheme.speedText.a * 255.0).round() * 0.3).round(),
                (currentTheme.speedText.r * 255.0).round(),
                (currentTheme.speedText.g * 255.0).round(),
                (currentTheme.speedText.b * 255.0).round(),
              ), 
              width: 1
            ),
          ),
          child: Stack(
            children: [
              // Main content - landscape layout (1:1 flex as per NOTES.txt)
              Row(
                children: [
                  // Speed section - left half
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Text(
                            speedText,
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w300,
                              color: currentTheme.speedText,
                              fontFamily: 'DIN1451Alt',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Direction section - right half (same as full-screen behavior)
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            flex: 2,
                            child: Transform.rotate(
                              angle: (_heading >= 0 && _heading < 360) ? (_heading * math.pi / 180.0) : 0,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: Icon(
                                  Icons.navigation,
                                  size: fontSize * 0.8,
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
                                  fontSize: fontSize * 0.4,
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
                ],
              ),
              // Semi-transparent close button (only interaction as per NOTES.txt)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => FlutterOverlayWindow.closeOverlay(),
                  child: Container(
                    width: overlayHeight * 0.2,
                    height: overlayHeight * 0.2,
                    decoration: BoxDecoration(
                      // Avoid deprecated withOpacity - use Color.fromARGB instead
                      color: const Color.fromARGB(153, 244, 67, 54), // red with 60% opacity
                      borderRadius: BorderRadius.circular(overlayHeight * 0.1),
                      border: Border.all(
                        color: const Color.fromARGB(204, 255, 255, 255), // white with 80% opacity
                        width: 1
                      ),
                    ),
                    child: Icon(
                      Icons.close,
                      color: const Color.fromARGB(229, 255, 255, 255), // white with 90% opacity
                      size: overlayHeight * 0.15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}