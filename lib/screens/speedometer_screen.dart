import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:wakelock_plus/wakelock_plus.dart';
import '../config/timing_constants.dart';
import '../config/color_themes.dart';
import '../services/gps_data_manager.dart';
import '../providers/settings_provider.dart';
import '../providers/overlay_provider.dart';
import '../services/logger.dart';

class SpeedometerScreen extends StatefulWidget {
  const SpeedometerScreen({super.key});

  @override
  State<SpeedometerScreen> createState() => _SpeedometerScreenState();
}

class _SpeedometerScreenState extends State<SpeedometerScreen> with WidgetsBindingObserver {
  // Local widget state only (not shared app state)
  String _errorMessage = '';
  bool _isInBackground = false;
  Timer? _backgroundHeartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Delay GPS init to after first frame so context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGpsManager();
    });
    _enableWakelock();
    _ensureOverlayPermission();
    _startBackgroundHeartbeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundHeartbeatTimer?.cancel();
    WakelockPlus.disable();
    Logger.info('SpeedometerScreen disposed', 'Main');
    super.dispose();
  }

  Future<void> _initializeGpsManager() async {
    Logger.info('Starting GPS manager initialization...', 'Main');
    try {
      await context.read<GpsDataManager>().initialize();
      Logger.info('GPS manager initialized', 'Main');
    } catch (e) {
      Logger.error('GPS manager initialization failed: $e', 'Main');
      if (mounted) {
        setState(() => _errorMessage = 'Failed to initialize GPS manager');
      }
    }
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
      final isEnabled = await WakelockPlus.enabled;
      if (!isEnabled) {
        Logger.warn('Wake lock not properly enabled, retrying...', 'Main');
        await WakelockPlus.enable();
      }
    } catch (e) {
      Logger.error('Wake lock failed: $e', 'Main');
    }
  }

  Future<void> _ensureOverlayPermission() async {
    try {
      // Note: Overlay permission request is handled by OverlayProvider,
      // but we check here to avoid issues at app startup
    } catch (e) {
      Logger.error('Error checking overlay permission: $e', 'Main');
    }
  }

  void _startBackgroundHeartbeat() {
    _backgroundHeartbeatTimer = Timer.periodic(TimingConfig.HEARTBEAT_INTERVAL, (timer) {
      if (!mounted) return;
      final overlay = context.read<OverlayProvider>();
      if (_isInBackground && overlay.isOverlayActive) {
        overlay.pushCurrentData();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
        if (!_isInBackground) {
          _isInBackground = true;
          _handleBackgroundTransition();
        }
        break;
      case AppLifecycleState.resumed:
        _isInBackground = false;
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _handleBackgroundTransition() {
    _enableWakelock();
    _requestBatteryOptimizationExemption();
    if (context.read<OverlayProvider>().isOverlayActive) {
      context.read<OverlayProvider>().pushCurrentData();
    }
  }

  Future<void> _requestBatteryOptimizationExemption() async {
    try {
      // Platform-specific implementation would go here
    } catch (e) {
      Logger.warn('Battery optimization exemption not available: $e', 'Main');
    }
  }

  String _getSpeedDisplayText(double displaySpeed) {
    // TEMPORARILY disabled for indoor testing - show all speeds
    // TODO: Re-enable: if (_currentGpsData.speed < 1.0 && (_currentGpsData.heading < 0.0 || _currentGpsData.heading >= 360.0)) return '--';
    return displaySpeed.toStringAsFixed(1);
  }

  Widget _buildSpeedDisplay(String speedText, ColorTheme currentTheme, double fontSize) {
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
            fontSize: fontSize * 0.5,
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
    return Selector<SettingsProvider, ColorTheme>(
      selector: (_, settings) => settings.currentTheme,
      builder: (context, currentTheme, _) {
        return Scaffold(
          backgroundColor: currentTheme.background,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape = constraints.maxWidth > constraints.maxHeight;
                if (isLandscape) {
                  return _buildLandscapeLayout(currentTheme);
                } else {
                  return _buildPortraitLayout(currentTheme);
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortraitLayout(ColorTheme currentTheme) {
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
                    child: Selector<GpsDataManager, double>(
                      selector: (_, gps) => gps.currentData.speed,
                      builder: (context, speed, _) {
                        final settings = context.read<SettingsProvider>();
                        final displaySpeed = settings.currentUnit.convert(speed);
                        final speedText = _getSpeedDisplayText(displaySpeed);
                        return GestureDetector(
                          onTap: () => context.read<SettingsProvider>().cycleTheme(),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: _buildSpeedDisplay(speedText, currentTheme, 200),
                          ),
                        );
                      },
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
                    child: Selector<SettingsProvider, String>(
                      selector: (_, settings) => settings.currentUnit.label,
                      builder: (context, unitLabel, _) {
                        return GestureDetector(
                          onTap: () => context.read<SettingsProvider>().cycleUnit(),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Text(
                              unitLabel,
                              style: TextStyle(
                                fontSize: 80,
                                color: currentTheme.unitText,
                                fontFamily: 'DIN1451Alt',
                              ),
                            ),
                          ),
                        );
                      },
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
              context.read<OverlayProvider>().toggleOverlay();
            },
            onLongPress: () {
              context.read<OverlayProvider>().closeOverlay();
            },
            child: Container(
              width: double.infinity,
              color: Colors.transparent,
              padding: const EdgeInsets.all(2),
              child: Selector<GpsDataManager, (double heading, String displayHeading)>(
                selector: (_, gps) => (gps.currentData.heading, gps.currentData.displayHeading),
                builder: (context, data, _) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        flex: 3,
                        child: Transform.rotate(
                          angle: (data.$1 >= 0 && data.$1 < 360) ? (data.$1 * math.pi / 180.0) : 0,
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
                            data.$2,
                            style: TextStyle(
                              fontSize: 50,
                              color: currentTheme.headingText,
                              fontFamily: 'DIN1451Alt',
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(ColorTheme currentTheme) {
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
                    child: Selector<GpsDataManager, double>(
                      selector: (_, gps) => gps.currentData.speed,
                      builder: (context, speed, _) {
                        final settings = context.read<SettingsProvider>();
                        final displaySpeed = settings.currentUnit.convert(speed);
                        final speedText = _getSpeedDisplayText(displaySpeed);
                        return GestureDetector(
                          onTap: () => context.read<SettingsProvider>().cycleTheme(),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: _buildSpeedDisplay(speedText, currentTheme, 160),
                          ),
                        );
                      },
                    ),
                  ),
                  Flexible(
                    flex: 7,
                    child: Selector<SettingsProvider, String>(
                      selector: (_, settings) => settings.currentUnit.label,
                      builder: (context, unitLabel, _) {
                        return GestureDetector(
                          onTap: () => context.read<SettingsProvider>().cycleUnit(),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Text(
                              unitLabel,
                              style: TextStyle(
                                fontSize: 50,
                                color: currentTheme.unitText,
                                fontFamily: 'DIN1451Alt',
                              ),
                            ),
                          ),
                        );
                      },
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
              context.read<OverlayProvider>().toggleOverlay();
            },
            onLongPress: () {
              context.read<OverlayProvider>().closeOverlay();
            },
            child: Container(
              height: double.infinity,
              color: Colors.transparent,
              padding: const EdgeInsets.all(2),
              child: Selector<GpsDataManager, (double heading, String displayHeading)>(
                selector: (_, gps) => (gps.currentData.heading, gps.currentData.displayHeading),
                builder: (context, data, _) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        flex: 3,
                        child: Transform.rotate(
                          angle: (data.$1 >= 0 && data.$1 < 360) ? (data.$1 * math.pi / 180.0) : 0,
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
                            data.$2,
                            style: TextStyle(
                              fontSize: 30,
                              color: currentTheme.headingText,
                              fontFamily: 'DIN1451Alt',
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
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
