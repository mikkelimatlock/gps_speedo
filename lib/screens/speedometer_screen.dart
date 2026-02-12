import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math' as math;
import '../config/timing_constants.dart';
import '../config/overlay_constants.dart';
import '../config/color_themes.dart';
import '../services/gps_data_manager.dart';
import '../models/processed_gps_data.dart';
import '../providers/settings_provider.dart';
import '../providers/overlay_provider.dart';
import '../services/logger.dart';

class SpeedometerScreen extends StatefulWidget {
  const SpeedometerScreen({super.key});

  @override
  State<SpeedometerScreen> createState() => _SpeedometerScreenState();
}

class _SpeedometerScreenState extends State<SpeedometerScreen> {
  // Local widget state only (not shared app state)
  String _errorMessage = '';
  Timer? _backgroundHeartbeatTimer;
  Timer? _stalenessCheckTimer;

  @override
  void initState() {
    super.initState();
    // Delay GPS init and error callback setup to after first frame so context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGpsManager();
      context.read<OverlayProvider>().onError = _handleOverlayError;
      // Wire overlay provider into GPS manager for lifecycle decisions
      context.read<GpsDataManager>().setOverlayProvider(context.read<OverlayProvider>());
    });
    _ensureOverlayPermission();
    _startBackgroundHeartbeat();
    _stalenessCheckTimer = Timer.periodic(OverlayConfig.STALENESS_CHECK_INTERVAL, (_) {
      if (mounted) setState(() {}); // Trigger rebuild to re-evaluate staleness
    });
  }

  @override
  void dispose() {
    _backgroundHeartbeatTimer?.cancel();
    _stalenessCheckTimer?.cancel();
    try {
      context.read<OverlayProvider>().onError = null;
    } catch (e) {
      // Provider might already be disposed
    }
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

  void _handleOverlayError(OverlayError error) {
    if (!mounted) return;

    String message;
    SnackBarAction? action;

    switch (error) {
      case OverlayError.permission:
        message = 'Overlay permission required';
        action = SnackBarAction(
          label: 'Settings',
          onPressed: () => openAppSettings(),
        );
        break;
      case OverlayError.creationFailed:
        message = 'Failed to create overlay window';
        break;
      case OverlayError.communicationDegraded:
        message = 'Overlay communication degraded';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: const Duration(seconds: 4),
      ),
    );
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
      if (overlay.isOverlayActive) {
        overlay.pushCurrentData();
      }
    });
  }

  Widget _buildSpeedDisplay(String speedText, ColorTheme currentTheme, double fontSize, double opacity) {
    if (speedText == '--') {
      return Text(
        speedText,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w300,
          color: currentTheme.speedText.withValues(alpha: opacity),
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
            color: currentTheme.speedText.withValues(alpha: opacity),
            fontFamily: 'DIN1451Alt',
          ),
        ),
        Text(
          decimalPart,
          style: TextStyle(
            fontSize: fontSize * 0.5,
            fontWeight: FontWeight.w300,
            color: currentTheme.speedTextSub.withValues(alpha: opacity),
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
                    child: Selector<GpsDataManager, ProcessedGpsData>(
                      selector: (_, gps) => gps.currentData,
                      builder: (context, data, _) {
                        final settings = context.read<SettingsProvider>();
                        final displaySpeed = settings.currentUnit.convert(data.speed);

                        // Calculate staleness
                        final age = DateTime.now().difference(data.timestamp);
                        final isDimmed = age >= OverlayConfig.STALENESS_DIM_THRESHOLD;
                        final showDashes = age >= OverlayConfig.STALENESS_DASH_THRESHOLD;
                        final staleOpacity = isDimmed ? OverlayConfig.STALENESS_DIM_OPACITY : 1.0;

                        final speedText = showDashes ? '--' : displaySpeed.toStringAsFixed(1);

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.read<SettingsProvider>().cycleTheme();
                          },
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: _buildSpeedDisplay(speedText, currentTheme, 200, staleOpacity),
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
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.read<SettingsProvider>().cycleUnit();
                          },
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
              child: Selector<GpsDataManager, ProcessedGpsData>(
                selector: (_, gps) => gps.currentData,
                builder: (context, data, _) {
                  // Calculate staleness
                  final age = DateTime.now().difference(data.timestamp);
                  final isDimmed = age >= OverlayConfig.STALENESS_DIM_THRESHOLD;
                  final staleOpacity = isDimmed ? OverlayConfig.STALENESS_DIM_OPACITY : 1.0;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        flex: 3,
                        child: Transform.rotate(
                          angle: (data.heading >= 0 && data.heading < 360) ? (data.heading * math.pi / 180.0) : 0,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Icon(
                              Icons.navigation,
                              size: 80,
                              color: currentTheme.headingText.withValues(alpha: staleOpacity),
                            ),
                          ),
                        ),
                      ),
                      Flexible(
                        flex: 1,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Text(
                            data.displayHeading,
                            style: TextStyle(
                              fontSize: 50,
                              color: currentTheme.headingText.withValues(alpha: staleOpacity),
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
                    child: Selector<GpsDataManager, ProcessedGpsData>(
                      selector: (_, gps) => gps.currentData,
                      builder: (context, data, _) {
                        final settings = context.read<SettingsProvider>();
                        final displaySpeed = settings.currentUnit.convert(data.speed);

                        // Calculate staleness
                        final age = DateTime.now().difference(data.timestamp);
                        final isDimmed = age >= OverlayConfig.STALENESS_DIM_THRESHOLD;
                        final showDashes = age >= OverlayConfig.STALENESS_DASH_THRESHOLD;
                        final staleOpacity = isDimmed ? OverlayConfig.STALENESS_DIM_OPACITY : 1.0;

                        final speedText = showDashes ? '--' : displaySpeed.toStringAsFixed(1);

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.read<SettingsProvider>().cycleTheme();
                          },
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: _buildSpeedDisplay(speedText, currentTheme, 160, staleOpacity),
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
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.read<SettingsProvider>().cycleUnit();
                          },
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
              child: Selector<GpsDataManager, ProcessedGpsData>(
                selector: (_, gps) => gps.currentData,
                builder: (context, data, _) {
                  // Calculate staleness
                  final age = DateTime.now().difference(data.timestamp);
                  final isDimmed = age >= OverlayConfig.STALENESS_DIM_THRESHOLD;
                  final staleOpacity = isDimmed ? OverlayConfig.STALENESS_DIM_OPACITY : 1.0;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        flex: 3,
                        child: Transform.rotate(
                          angle: (data.heading >= 0 && data.heading < 360) ? (data.heading * math.pi / 180.0) : 0,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Icon(
                              Icons.navigation,
                              size: 60,
                              color: currentTheme.headingText.withValues(alpha: staleOpacity),
                            ),
                          ),
                        ),
                      ),
                      Flexible(
                        flex: 1,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Text(
                            data.displayHeading,
                            style: TextStyle(
                              fontSize: 30,
                              color: currentTheme.headingText.withValues(alpha: staleOpacity),
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
