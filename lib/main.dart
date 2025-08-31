import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/services.dart'; // For HapticFeedback
import 'dart:async';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:bg_launcher/bg_launcher.dart'; // For bringing app to foreground
import 'speed_units.dart';
import 'color_themes.dart';
import 'services/gps_data_manager.dart';
import 'dart:math' as math; // Import for math.pi

// Global debug configuration (removed - now handled by GPS manager)

// Debug helper - only prints in debug builds
void customDebugPrint(String message) {
  if (kDebugMode) {
    print(message);
  }
}

void main() {
  runApp(const SpeedoApp());
}

// Entry point for overlay window
@pragma("vm:entry-point")
void overlayMain() {
  customDebugPrint('[Overlay] 🚀 overlayMain() called');
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
  SpeedUnit _currentUnit = SpeedUnit.kmh;
  int _currentThemeIndex = 0;
  StreamSubscription<ProcessedGpsData>? _gpsDataSubscription;
  StreamSubscription<dynamic>? _overlaySubscription;
  ProcessedGpsData _currentGpsData = const ProcessedGpsData(
    speed: 0.0,
    heading: -1.0,
    displaySpeed: '--',
    displayHeading: 'N/A',
    isSpeedValid: false,
    isHeadingValid: false,
  );
  String _errorMessage = '';
  bool _isInBackground = false;
  bool _isOverlayActive = false;
  bool _tapCloseRequested = false;
  Timer? _tapCloseTimer;
  
  // Single source of truth for overlay sizing
  Map<String, int> _getOverlaySize() {
    final window = WidgetsBinding.instance.platformDispatcher.views.first;
    final physicalSize = window.physicalSize;
    
    // Use actual physical pixels for overlay sizing
    final overlayWidth = (physicalSize.width * 0.45).round(); // 45% of actual screen width
    final overlayHeight = (overlayWidth * 0.6).round();
    
    return {'width': overlayWidth, 'height': overlayHeight};
  }

  Timer? _backgroundHeartbeatTimer;
  Timer? _overlayStatusCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeGpsManager();
    _enableWakelock();
    _ensureOverlayPermission();
    // Overlay listener will be created lazily when overlay is shown
    _startBackgroundHeartbeat();
  }
  
  void _startListeningToOverlayMessages() {
    // Only create listener when overlay is actually shown
    if (_overlaySubscription != null) {
      return;
    }
    _overlaySubscription = FlutterOverlayWindow.overlayListener.listen(
      (data) {
        try {
          if (data is Map) {
            final action = data['action'];
            switch (action) {
              case 'overlayClosed':
                _handleOverlayClose();
                break;
              case 'longPressClose':
                _tapCloseRequested = true; // Reusing the flag for long press
                // Set a timer to reset this flag if overlay doesn't close soon
                _tapCloseTimer?.cancel();
                _tapCloseTimer = Timer(const Duration(milliseconds: 500), () {
                  _tapCloseRequested = false;
                });
                break;
              // 'bringToFront' action handler removed per NOTES.txt (tap to bring front functionality disabled)
              default:
                customDebugPrint('[Main] ⚠️  Unknown overlay action: "$action"');
            }
          }
        } catch (e, stackTrace) {
          customDebugPrint('[Main] ❌ Error processing overlay message: $e');
          customDebugPrint('[Main] 📚 Stack trace: $stackTrace');
        }
      },
      onError: (error) {
        customDebugPrint('[Main] ❌ Overlay listener error: $error');
      },
    );
  }
  
  void _stopListeningToOverlayMessages() {
    _overlaySubscription?.cancel();
    _overlaySubscription = null;
  }
  
  void _startOverlayStatusCheck() {
    // Cancel any existing timer first
    _overlayStatusCheckTimer?.cancel();
    
    _overlayStatusCheckTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      if (_isOverlayActive) {
        try {
          final isActive = await FlutterOverlayWindow.isActive();
          if (!isActive) {
            timer.cancel(); // Cancel the timer before handling close
            _handleOverlayClose();
          }
        } catch (e) {
          customDebugPrint('[Main] ❌ Overlay status check failed: $e');
        }
      } else {
        // If overlay is not supposed to be active, cancel the timer
        timer.cancel();
      }
    });
    customDebugPrint('[Main] 🔍 Started overlay status monitoring');
  }

  void _handleOverlayClose({bool bringToForeground = false}) {
    // Check if this was a long-press close based on recent signal
    final shouldBringToFront = bringToForeground || _tapCloseRequested;
    
    // Cancel timers and reset flag
    _tapCloseTimer?.cancel();
    _overlayStatusCheckTimer?.cancel();
    _tapCloseRequested = false;
    
    setState(() {
      _isOverlayActive = false;
    });
    _stopListeningToOverlayMessages(); // Clean up listener when overlay closes
    
    // Bring app to foreground on long press close, otherwise quiet close
    if (shouldBringToFront) {
      _bringAppToFront();
    }
  }
  
  
  void _startBackgroundHeartbeat() {
    // Aggressive heartbeat to keep main app process active for overlay communication
    _backgroundHeartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isInBackground && _isOverlayActive) {
        // Minimal activity to prevent hibernation
        if (mounted) {
          // Force data push to overlay to maintain communication
          _pushDataToOverlay();
          // Small state update to keep Flutter engine active
          setState(() {
            // Tiny update that doesn't affect UI but keeps engine alive
            _isInBackground = _isInBackground;
          });
        }
      } else if (_isInBackground) {
        if (mounted) {
          // Lighter heartbeat when no overlay is active
          setState(() {
            _isInBackground = _isInBackground;
          });
        }
      }
    });
  }
  
  void _bringAppToFront() async {
    try {
      // Use proper Android method to bring app to foreground
      BgLauncher.bringAppToForeground();
      
      // Update app state to reflect foreground status
      if (mounted) {
        setState(() {
          _isInBackground = false;
        });
      }
    } catch (e) {
      customDebugPrint('[Main] ❌ BgLauncher failed to bring app to front: $e');
      
      // Enhanced fallback: try alternative approach
      try {
        if (mounted) {
          setState(() {
            _isInBackground = false;
          });
        }
      } catch (fallbackError) {
        customDebugPrint('[Main] ❌ Fallback method also failed: $fallbackError');
      }
    }
  }

  Future<void> _enableWakelock() async {
    try {
      // Force enable wake lock even if already enabled for robustness
      await WakelockPlus.enable();
      final isEnabled = await WakelockPlus.enabled;
      
      // Double-check wake lock status for debugging
      if (!isEnabled) {
        customDebugPrint('[Main] ⚠️  Wake lock not properly enabled, retrying...');
        await WakelockPlus.enable();
      }
    } catch (e) {
      customDebugPrint('[Main] ❌ Wake lock failed: $e');
      // Wake lock not supported on this platform, continue normally
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsDataSubscription?.cancel();
    _overlaySubscription?.cancel();
    _backgroundHeartbeatTimer?.cancel();
    _overlayStatusCheckTimer?.cancel();
    _tapCloseTimer?.cancel();
    WakelockPlus.disable();
    customDebugPrint('[Main] 🛑 Main app disposed - all subscriptions and timers canceled');
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
    // Enhanced background persistence - keep GPS stream active
    _enableWakelock();
    _requestBatteryOptimizationExemption();
    
    // If overlay is active, ensure more frequent data pushing
    if (_isOverlayActive) {
      _pushDataToOverlay();
    }
  }
  
  Future<void> _requestBatteryOptimizationExemption() async {
    try {
      // This would show Android's battery optimization whitelist dialog
      // Note: This requires platform-specific implementation which we'd need to add via method channel
      // For now, we'll rely on other persistence mechanisms
    } catch (e) {
      customDebugPrint('[Main] ⚠️  Battery optimization exemption not available: $e');
    }
  }
  
  Future<void> _ensureOverlayPermission() async {
    try {
      // Check if overlay permission is granted (required for bg_launcher to work properly)
      final isGranted = await FlutterOverlayWindow.isPermissionGranted();
      
      if (!isGranted) {
        await FlutterOverlayWindow.requestPermission();
      }
    } catch (e) {
      customDebugPrint('[Main] ❌ Error checking overlay permission: $e');
    }
  }

  Future<void> _initializeGpsManager() async {
    print('[Main] 🚀 Starting GPS manager initialization...');
    try {
      // Initialize the GPS manager
      print('[Main] 📡 Calling GpsDataManager.instance.initialize()...');
      await GpsDataManager.instance.initialize();
      print('[Main] ✅ GPS manager initialization completed');
      
      // Subscribe to processed GPS data
      print('[Main] 🎧 Setting up data stream subscription...');
      _gpsDataSubscription = GpsDataManager.instance.dataStream.listen(
        _onGpsDataUpdate,
        onError: (error) {
          print('[Main] ❌ GPS data stream error: $error');
          setState(() => _errorMessage = 'GPS manager error: $error');
        },
      );
      print('[Main] ✅ GPS data stream subscription active');
      
      customDebugPrint('[Main] 🛰️ GPS manager initialized and subscribed');
    } catch (e) {
      print('[Main] ❌ GPS manager initialization exception: $e');
      setState(() => _errorMessage = 'Failed to initialize GPS manager');
      customDebugPrint('[Main] ❌ GPS manager initialization failed: $e');
    }
  }

  void _onGpsDataUpdate(ProcessedGpsData gpsData) {
    print('[Main] 📥 Received GPS data: ${gpsData.speed.toStringAsFixed(1)} m/s, ${gpsData.displayHeading}');
    
    setState(() {
      _currentGpsData = gpsData;
      _errorMessage = '';
    });
    
    print('[Main] ✅ State updated with GPS data');
    final convertedSpeed = _currentUnit.convert(gpsData.speed);
    customDebugPrint('[Main] 📡 Converted for display: ${convertedSpeed.toStringAsFixed(1)} ${_currentUnit.label}, ${gpsData.displayHeading}');
    
    // Always push display data to overlay if active - critical for background communication
    if (_isOverlayActive) {
      _pushDataToOverlay();
      customDebugPrint('[Main] 📤 Data pushed to overlay from GPS update');
    }
  }
  
  
  void _pushDataToOverlay() {
    // Only push data if overlay is actually active (listener check was causing race conditions)
    if (!_isOverlayActive) {
      customDebugPrint('[Main] 🚫 Skipping data push - no active overlay (active: $_isOverlayActive, subscription: ${_overlaySubscription != null})');
      return;
    }
    
    customDebugPrint('[Main] ✅ Overlay guard passed - pushing data (active: $_isOverlayActive, subscription: ${_overlaySubscription != null})');
    
    // Get formatted speed for current unit from GPS manager
    final speedText = GpsDataManager.instance.getFormattedSpeed(_currentUnit);
    final unitText = _currentUnit.label.toString();
    final headingText = _currentGpsData.displayHeading;
    
    customDebugPrint('[Main] 📤 SENDING to overlay:');
    customDebugPrint('  speedText: "$speedText"');
    customDebugPrint('  headingText: "$headingText"');
    customDebugPrint('  direction: ${_currentGpsData.heading.toStringAsFixed(1)}°');
    customDebugPrint('  unit: $unitText, theme: $_currentThemeIndex');
    
    FlutterOverlayWindow.shareData({
      'action': 'updateDisplay',
      'speedText': speedText,
      'unitText': unitText,
      'headingText': headingText,
      'heading': _currentGpsData.heading,
      'unitIndex': _currentUnit.index,
      'themeIndex': _currentThemeIndex,
    });
  }

  void _cycleUnit() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentUnit = _currentUnit.next;
    });
    // Push updated display data to overlay
    _pushDataToOverlay();
  }

  void _cycleTheme() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentThemeIndex = ColorThemes.getNextThemeIndex(_currentThemeIndex);
    });
    // Push updated display data to overlay
    _pushDataToOverlay();
  }

  Future<void> _showFloatingWindow() async {
    try {
      // Use centralized sizing function
      final overlaySize = _getOverlaySize();
      
      // Send initial display data WITH size info (only needed on creation)
      final speedText = GpsDataManager.instance.getFormattedSpeed(_currentUnit);
      final headingText = _currentGpsData.displayHeading;
      
      await FlutterOverlayWindow.shareData({
        'action': 'updateDisplay',
        'speedText': speedText,
        'headingText': headingText,
        'heading': _currentGpsData.heading,
        'unitIndex': _currentUnit.index,
        'themeIndex': _currentThemeIndex,
        'overlayWidth': overlaySize['width']!.toDouble(),
        'overlayHeight': overlaySize['height']!.toDouble(),
      });

      // Show the overlay with proportional sizing based on system resolution
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "Speedometer",
        overlayContent: 'Speedo overlay active',
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.none,
        // Use consistent sizing from centralized function
        width: overlaySize['width']!,
        height: overlaySize['height']!,
      );
      
      customDebugPrint('[Main] 🟢 OVERLAY LAUNCHED - Size: ${overlaySize['width']}x${overlaySize['height']}');
      
      // Set overlay active immediately and synchronously
      _isOverlayActive = true;
      customDebugPrint('[Main] ✅ _isOverlayActive set to: $_isOverlayActive');
      
      // Start listening to overlay messages after state is set
      _startListeningToOverlayMessages();
      
      // Start periodic overlay status check since message-based detection is unreliable
      _startOverlayStatusCheck();
      
      // Force UI update
      if (mounted) setState(() {});
    } catch (e) {
      // Silent error handling - floating window issues shouldn't crash main app
    }
  }

  Future<void> _closeFloatingWindow() async {
    if (!_isOverlayActive) {
      customDebugPrint('[Main] ⚠️  No overlay to close');
      return;
    }
    
    try {
      await FlutterOverlayWindow.closeOverlay();
      customDebugPrint('[Main] 🔴 OVERLAY CLOSED - Requested from main app');
      _handleOverlayClose(); // This will set _isOverlayActive = false and stop listener
    } catch (e) {
      customDebugPrint('[Main] ❌ Error closing overlay: $e');
    }
  }
  
  String _getSpeedDisplayText(double displaySpeed) {
    // TEMPORARILY disabled for indoor testing - show all speeds
    // TODO: Re-enable: if (_currentGpsData.speed < 1.0 && (_currentGpsData.heading < 0.0 || _currentGpsData.heading >= 360.0)) return '--';
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
    final displaySpeed = _currentUnit.convert(_currentGpsData.speed);
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
                    flex: 7,
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
                    child: FittedBox(
                      fit: BoxFit.contain,
                    ),
                  ),
                  Flexible(
                    flex: 2,
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
                  Flexible(
                    flex: 1,
                    child: FittedBox(
                      fit: BoxFit.contain,
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
              HapticFeedback.lightImpact();
              customDebugPrint('[Main] 🖱️  Navigation area tapped - overlay active: $_isOverlayActive');
              if (_isOverlayActive) {
                _closeFloatingWindow();
              } else {
                _showFloatingWindow();
              }
            },
            onLongPress: () {
              customDebugPrint('[Main] 🖱️  Navigation area long-pressed - overlay active: $_isOverlayActive');
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
                      angle: (_currentGpsData.heading >= 0 && _currentGpsData.heading < 360) ? (_currentGpsData.heading * math.pi / 180.0) : 0,
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
                        _currentGpsData.displayHeading,
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
          flex: 60,
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
          flex: 35,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              customDebugPrint('[Main] 🖱️  Navigation area tapped (landscape) - overlay active: $_isOverlayActive');
              if (_isOverlayActive) {
                _closeFloatingWindow();
              } else {
                _showFloatingWindow();
              }
            },
            onLongPress: () {
              customDebugPrint('[Main] 🖱️  Navigation area long-pressed (landscape) - overlay active: $_isOverlayActive');
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
                      angle: (_currentGpsData.heading >= 0 && _currentGpsData.heading < 360) ? (_currentGpsData.heading * math.pi / 180.0) : 0,
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
                        _currentGpsData.displayHeading,
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
        Expanded(
          flex: 1,
          child: FittedBox(
            fit: BoxFit.contain,
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
  String _unitText = 'km/h';
  String _headingText = 'N/A';
  double _heading = -1.0;
  int _currentThemeIndex = 0;
  double _systemScreenWidth = 400;
  double _overlayWidth = 280;
  double _overlayHeight = 140;

  @override
  void initState() {
    super.initState();
    customDebugPrint('[Overlay] 🟢 CREATED - Floating window initialized (${DateTime.now().millisecondsSinceEpoch})');
    _getSystemScreenSize();
    _listenToMainAppMessages();
  }
  
  @override
  void dispose() {
    customDebugPrint('[Overlay] 🔴 DISPOSING - Overlay widget disposed (${DateTime.now().millisecondsSinceEpoch})');
    super.dispose();
  }

  void _getSystemScreenSize() {
    try {
      // Get actual system screen resolution, not just app window size
      final window = WidgetsBinding.instance.platformDispatcher.views.first;
      final physicalSize = window.physicalSize;
      final devicePixelRatio = window.devicePixelRatio;
      final systemSize = physicalSize / devicePixelRatio;
      
      customDebugPrint('[Overlay] 🔍 Screen detection:');
      customDebugPrint('  physicalSize: ${physicalSize.width.round()}x${physicalSize.height.round()}');
      customDebugPrint('  devicePixelRatio: $devicePixelRatio');
      customDebugPrint('  calculated systemSize: ${systemSize.width.round()}x${systemSize.height.round()}');
      
      setState(() {
        _systemScreenWidth = systemSize.width;
      });
      
      customDebugPrint('[Overlay] ✅ _systemScreenWidth set to: ${_systemScreenWidth.round()}');
    } catch (e) {
      customDebugPrint('[Overlay] ❌ Error getting system screen size: $e');
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
          _unitText = data['unitText'];
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
        
        customDebugPrint('[Overlay] 📡 UPDATE received:');
        customDebugPrint('  speedText: "$_speedText"');
        customDebugPrint('  headingText: "$_headingText"'); 
        customDebugPrint('  direction: ${_heading.toStringAsFixed(1)}°');
        customDebugPrint('  themeIndex: $_currentThemeIndex');
        customDebugPrint('  systemScreenWidth: ${_systemScreenWidth.round()}');
        customDebugPrint('  overlaySize from main: ${_overlayWidth.round()}x${_overlayHeight.round()}');
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final buildTimestamp = DateTime.now().millisecondsSinceEpoch;
    final currentTheme = ColorThemes.getTheme(_currentThemeIndex);
    
    // Use overlay dimensions provided by main app (not calculated locally)
    final fontSize = (_overlayWidth * 0.2); // Font size proportional to actual overlay width
    
    customDebugPrint('[Overlay] 🔨 Building overlay widget ($buildTimestamp)');
    customDebugPrint('[Overlay] 📐 Window size: ${_overlayWidth.round()}x${_overlayHeight.round()}, fontSize: ${fontSize.round()}');

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        // Use SizedBox to fill the overlay window completely
        width: double.infinity,
        height: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            color: currentTheme.background.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: currentTheme.speedText.withValues(alpha: 0.3), 
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
                    flex: 55,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              flex: 3,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: Text(
                                  (_speedText),
                                  style: TextStyle(
                                    fontSize: fontSize,
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
                                fit: BoxFit.contain,
                                child: Text(
                                  _unitText,
                                  style: TextStyle(
                                    fontSize: fontSize * 0.6,
                                    fontWeight: FontWeight.w300,
                                    color: currentTheme.unitText,
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
                  // Direction section - right half (same as full-screen behavior)
                  Expanded(
                    flex: 45,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            flex: 5,
                            child: Transform.rotate(
                              angle: (_heading >= 0 && _heading < 360) ? (_heading * math.pi / 180.0) : 0,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: Icon(
                                  Icons.navigation,
                                  size: fontSize * 0.72,
                                  color: currentTheme.headingText,
                                ),
                              ),
                            ),
                          ),
                          Flexible(
                            flex: 2,
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
              // Transparent full-overlay gesture detection layer
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent, // Ensure gestures are captured
                  onPanStart: (details) {
                    customDebugPrint('[Overlay] 🖐️ Pan start detected - gestures are working!');
                  },
                  onLongPress: () async {
                    final timestamp = DateTime.now().millisecondsSinceEpoch;
                    customDebugPrint('[Overlay] 🔴 Long press detected - closing overlay and bringing main app to front ($timestamp)');
                    try {
                      // Skip haptic feedback in overlay - platform services not available
                      customDebugPrint('[Overlay] 📳 Skipping haptic feedback (overlay context limitation)');
                      
                      // Signal main app to bring to foreground when overlay closes (non-blocking)
                      customDebugPrint('[Overlay] 📤 Sending bring-to-front close signal...');
                      FlutterOverlayWindow.shareData({
                        'action': 'longPressClose',
                      }).then((_) {
                        customDebugPrint('[Overlay] ✅ Long press close signal sent successfully');
                      }).catchError((error) {
                        customDebugPrint('[Overlay] ❌ Long press close signal failed (expected): $error');
                      });
                      
                      // Small delay to give signal a chance
                      await Future.delayed(const Duration(milliseconds: 50));
                      
                      // Close the overlay
                      customDebugPrint('[Overlay] 🔴 Attempting to close overlay...');
                      await FlutterOverlayWindow.closeOverlay();
                      customDebugPrint('[Overlay] ✅ Overlay closed successfully via long press');
                      
                    } catch (e, stackTrace) {
                      customDebugPrint('[Overlay] ❌ Long press close failed: $e');
                      customDebugPrint('[Overlay] 📚 Stack trace: $stackTrace');
                      // Fallback: try to close anyway
                      try {
                        customDebugPrint('[Overlay] 🔄 Attempting fallback close...');
                        await FlutterOverlayWindow.closeOverlay();
                        customDebugPrint('[Overlay] ✅ Fallback close succeeded');
                      } catch (fallbackError) {
                        customDebugPrint('[Overlay] ❌ Fallback close also failed: $fallbackError');
                      }
                    }
                  },
                  // Tap to bring main app to front functionality removed per NOTES.txt
                  // onTap: () async {
                  //   final timestamp = DateTime.now().millisecondsSinceEpoch;
                  //   customDebugPrint('[Overlay] 👆 Tap detected - bringing main app to foreground ($timestamp)');
                  //   try {
                  //     // Try to signal main app to come to foreground (non-blocking)
                  //     customDebugPrint('[Overlay] 📤 Attempting to signal bring-to-front...');
                  //     FlutterOverlayWindow.shareData({
                  //       'action': 'bringToFront',
                  //     }).catchError((error) {
                  //       customDebugPrint('[Overlay] ❌ Bring-to-front signal failed (expected): $error');
                  //     });
                  //     
                  //     customDebugPrint('[Overlay] ✅ Tap gesture completed (overlay stays open)');
                  //     
                  //   } catch (e, stackTrace) {
                  //     customDebugPrint('[Overlay] ❌ Tap gesture failed: $e');
                  //     customDebugPrint('[Overlay] 📚 Stack trace: $stackTrace');
                  //   }
                  // },
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.transparent,
                    child: Center(
                      child: Text(
                        'GESTURE',
                        style: TextStyle(
                          color: Colors.transparent,
                          fontSize: 1,
                        ),
                      ),
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