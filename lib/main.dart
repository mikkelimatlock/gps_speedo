import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'speed_units.dart';
import 'gps_service.dart';
import 'color_themes.dart';
import 'dart:math' as math; // Import for math.pi

// Debug helper - only prints in debug builds
void debugPrint(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

void main() {
  runApp(const SpeedoApp());
}

// Entry point for overlay window
@pragma("vm:entry-point")
void overlayMain() {
  debugPrint('[Overlay] 🚀 overlayMain() called');
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
  bool _isOverlayActive = false;

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
    
    // Push display data to overlay if active
    _pushDataToOverlay();
  }
  
  void _pushDataToOverlay() {
    // Send complete display data to overlay including screen size
    final displaySpeed = _currentUnit.convert(_speed);
    final speedText = displaySpeed < 1.0 ? '--' : displaySpeed.toInt().toString();
    final headingText = GpsService.formatHeading(_heading);
    
    // Get system screen size to share with overlay
    final window = WidgetsBinding.instance.platformDispatcher.views.first;
    final systemSize = window.physicalSize / window.devicePixelRatio;
    
    debugPrint('[Main] 📤 SENDING to overlay:');
    debugPrint('  speedText: "$speedText"');
    debugPrint('  headingText: "$headingText"');
    debugPrint('  direction: ${_heading.toStringAsFixed(1)}°');
    debugPrint('  unit: ${_currentUnit.label}, theme: $_currentThemeIndex');
    debugPrint('  systemScreen: ${systemSize.width.round()}x${systemSize.height.round()}');
    
    // Calculate overlay size the same way as when launching
    final overlayWidth = (systemSize.width * 0.4).round();
    final overlayHeight = (overlayWidth * 0.5).round();
    
    FlutterOverlayWindow.shareData({
      'action': 'updateDisplay',
      'speedText': speedText,
      'headingText': headingText,
      'heading': _heading,
      'unitIndex': _currentUnit.index,
      'themeIndex': _currentThemeIndex,
      'systemScreenWidth': systemSize.width,
      'systemScreenHeight': systemSize.height,
      'overlayWidth': overlayWidth.clamp(280, 480).toDouble(),
      'overlayHeight': overlayHeight.clamp(140, 240).toDouble(),
    });
  }

  void _cycleUnit() {
    setState(() {
      _currentUnit = _currentUnit.next;
    });
    // Push updated display data to overlay
    _pushDataToOverlay();
  }

  void _cycleTheme() {
    setState(() {
      _currentThemeIndex = ColorThemes.getNextThemeIndex(_currentThemeIndex);
    });
    // Push updated display data to overlay
    _pushDataToOverlay();
  }

  Future<void> _showFloatingWindow() async {
    try {
      // Get actual system screen resolution for proportional sizing
      final window = WidgetsBinding.instance.platformDispatcher.views.first;
      final systemSize = window.physicalSize / window.devicePixelRatio;
      final overlayWidth = (systemSize.width * 0.4).round(); // 40% of system screen width
      final overlayHeight = (overlayWidth * 0.5).round(); // 2:1 aspect ratio
      
      // Debug info for development
      // debugPrint('[Main] System resolution: ${systemSize.width.round()}x${systemSize.height.round()}');
      // debugPrint('[Main] Calculated overlay size: ${overlayWidth}x${overlayHeight}');
      
      // Send initial display data to overlay including screen size
      final displaySpeed = _currentUnit.convert(_speed);
      final speedText = displaySpeed < 1.0 ? '--' : displaySpeed.toInt().toString();
      final headingText = GpsService.formatHeading(_heading);
      
      await FlutterOverlayWindow.shareData({
        'action': 'updateDisplay',
        'speedText': speedText,
        'headingText': headingText,
        'heading': _heading,
        'unitIndex': _currentUnit.index,
        'themeIndex': _currentThemeIndex,
        'systemScreenWidth': systemSize.width,
        'systemScreenHeight': systemSize.height,
        'overlayWidth': overlayWidth.clamp(280, 480).toDouble(),
        'overlayHeight': overlayHeight.clamp(140, 240).toDouble(),
      });

      // Show the overlay with proportional sizing based on system resolution
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "GPS Speedometer",
        overlayContent: 'GPS Speedometer Overlay',
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.none,
        // Use system-based proportional sizing with reasonable limits
        width: overlayWidth.clamp(280, 480),
        height: overlayHeight.clamp(140, 240),
      );
      
      debugPrint('[Main] 🟢 OVERLAY LAUNCHED - Size: ${overlayWidth.clamp(280, 480)}x${overlayHeight.clamp(140, 240)}');
      setState(() {
        _isOverlayActive = true;
      });
    } catch (e) {
      // Silent error handling - floating window issues shouldn't crash main app
    }
  }

  Future<void> _closeFloatingWindow() async {
    if (!_isOverlayActive) {
      debugPrint('[Main] ⚠️  No overlay to close');
      return;
    }
    
    try {
      await FlutterOverlayWindow.closeOverlay();
      debugPrint('[Main] 🔴 OVERLAY CLOSED - Requested from main app');
      setState(() {
        _isOverlayActive = false;
      });
    } catch (e) {
      debugPrint('[Main] ❌ Error closing overlay: $e');
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
          flex: 65,
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
          flex: 32,
          child: GestureDetector(
            onTap: () {
              debugPrint('[Main] 🖱️  Navigation area tapped - overlay active: $_isOverlayActive');
              if (_isOverlayActive) {
                _closeFloatingWindow();
              } else {
                _showFloatingWindow();
              }
            },
            onLongPress: () {
              debugPrint('[Main] 🖱️  Navigation area long-pressed - overlay active: $_isOverlayActive');
              _closeFloatingWindow();
            },
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
                    flex: 1,
                    child: FittedBox(),
                  ),
                  Flexible(
                    flex: 20,
                    child: GestureDetector(
                      onTap: _cycleTheme,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: _buildSpeedDisplay(speedText, currentTheme, 160, isLandscape: true),
                      ),
                    ),
                  ),
                  Flexible(
                    flex: 7,
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
                  Flexible(
                    flex: 5,
                    child: FittedBox(),
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
            onTap: () {
              debugPrint('[Main] 🖱️  Navigation area tapped (landscape) - overlay active: $_isOverlayActive');
              if (_isOverlayActive) {
                _closeFloatingWindow();
              } else {
                _showFloatingWindow();
              }
            },
            onLongPress: () {
              debugPrint('[Main] 🖱️  Navigation area long-pressed (landscape) - overlay active: $_isOverlayActive');
              _closeFloatingWindow();
            },
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
  String _speedText = '--';
  String _headingText = 'N/A';
  double _heading = -1.0;
  int _currentThemeIndex = 0;
  double _systemScreenWidth = 400;
  double _overlayWidth = 280;
  double _overlayHeight = 140;

  @override
  void initState() {
    super.initState();
    debugPrint('[Overlay] 🟢 CREATED - Floating window initialized');
    _getSystemScreenSize();
    _listenToMainAppMessages();
  }

  void _getSystemScreenSize() {
    try {
      // Get actual system screen resolution, not just app window size
      final window = WidgetsBinding.instance.platformDispatcher.views.first;
      final physicalSize = window.physicalSize;
      final devicePixelRatio = window.devicePixelRatio;
      final systemSize = physicalSize / devicePixelRatio;
      
      debugPrint('[Overlay] 🔍 Screen detection:');
      debugPrint('  physicalSize: ${physicalSize.width.round()}x${physicalSize.height.round()}');
      debugPrint('  devicePixelRatio: $devicePixelRatio');
      debugPrint('  calculated systemSize: ${systemSize.width.round()}x${systemSize.height.round()}');
      
      setState(() {
        _systemScreenWidth = systemSize.width;
      });
      
      debugPrint('[Overlay] ✅ _systemScreenWidth set to: ${_systemScreenWidth.round()}');
    } catch (e) {
      debugPrint('[Overlay] ❌ Error getting system screen size: $e');
      // Fallback to reasonable default
      setState(() {
        _systemScreenWidth = 400;
      });
    }
  }

  void _listenToMainAppMessages() {
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map && data['action'] == 'updateDisplay') {
        setState(() {
          _speedText = data['speedText'] ?? '--';
          _headingText = data['headingText'] ?? 'N/A';
          _heading = data['heading']?.toDouble() ?? -1.0;
          _currentThemeIndex = data['themeIndex'] ?? 0;
          // Update screen size and overlay dimensions if provided by main app
          if (data.containsKey('systemScreenWidth')) {
            _systemScreenWidth = data['systemScreenWidth']?.toDouble() ?? _systemScreenWidth;
          }
          if (data.containsKey('overlayWidth')) {
            _overlayWidth = data['overlayWidth']?.toDouble() ?? _overlayWidth;
          }
          if (data.containsKey('overlayHeight')) {
            _overlayHeight = data['overlayHeight']?.toDouble() ?? _overlayHeight;
          }
        });
        
        debugPrint('[Overlay] 📡 UPDATE received:');
        debugPrint('  speedText: "$_speedText"');
        debugPrint('  headingText: "$_headingText"'); 
        debugPrint('  direction: ${_heading.toStringAsFixed(1)}°');
        debugPrint('  themeIndex: $_currentThemeIndex');
        debugPrint('  systemScreenWidth: ${_systemScreenWidth.round()}');
        debugPrint('  overlaySize from main: ${_overlayWidth.round()}x${_overlayHeight.round()}');
      }
    });
  }

  @override
  void dispose() {
    debugPrint('[Overlay] 🔴 DESTROYED - Floating window disposed');
    // No GPS subscription to cancel - overlay is display-only
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ColorThemes.getTheme(_currentThemeIndex);
    
    // Use overlay dimensions provided by main app (not calculated locally)
    final fontSize = (_overlayWidth * 0.2); // Font size proportional to actual overlay width
    
    debugPrint('[Overlay] 📐 Window size: ${_overlayWidth.round()}x${_overlayHeight.round()}, fontSize: ${fontSize.round()}');

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        // Use SizedBox to fill the overlay window completely
        width: double.infinity,
        height: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            color: currentTheme.background.withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: currentTheme.speedText.withOpacity(0.3), 
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
                            _speedText,
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
                                _headingText,
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
                    width: _overlayHeight * 0.2,
                    height: _overlayHeight * 0.2,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(_overlayHeight * 0.1),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.8),
                        width: 1
                      ),
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.white.withOpacity(0.9),
                      size: _overlayHeight * 0.15,
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