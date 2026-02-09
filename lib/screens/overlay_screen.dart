import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../config/color_themes.dart';
import '../config/overlay_constants.dart';
import '../models/overlay_message.dart';
import '../services/logger.dart';

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
    Logger.info('CREATED - Floating window initialized (${DateTime.now().millisecondsSinceEpoch})', 'Overlay');
    _getSystemScreenSize();
    _listenToMainAppMessages();
  }

  @override
  void dispose() {
    Logger.info('DISPOSING - Overlay widget disposed (${DateTime.now().millisecondsSinceEpoch})', 'Overlay');
    super.dispose();
  }

  void _getSystemScreenSize() {
    try {
      // Get actual system screen resolution, not just app window size
      final window = WidgetsBinding.instance.platformDispatcher.views.first;
      final physicalSize = window.physicalSize;
      final devicePixelRatio = window.devicePixelRatio;
      final systemSize = physicalSize / devicePixelRatio;

      Logger.debug('Screen detection:', 'Overlay');
      Logger.debug('  physicalSize: ${physicalSize.width.round()}x${physicalSize.height.round()}', 'Overlay');
      Logger.debug('  devicePixelRatio: $devicePixelRatio', 'Overlay');
      Logger.debug('  calculated systemSize: ${systemSize.width.round()}x${systemSize.height.round()}', 'Overlay');

      setState(() {
        _systemScreenWidth = systemSize.width;
      });

      Logger.debug('_systemScreenWidth set to: ${_systemScreenWidth.round()}', 'Overlay');
    } catch (e) {
      Logger.error('Error getting system screen size: $e', 'Overlay');
      // Fallback to reasonable default
      setState(() {
        _systemScreenWidth = OverlayConfig.DEFAULT_SCREEN_WIDTH;
      });
    }
  }

  void _listenToMainAppMessages() {
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map) {
        final message = OverlayMessage.fromMap(data);
        if (message.action == 'updateDisplay') {
          setState(() {
            _speedText = message.speedText ?? '--';
            _unitText = message.unitText ?? '';
            _headingText = message.headingText ?? 'N/A';
            _heading = message.heading ?? -1.0;
            _currentThemeIndex = message.themeIndex ?? 0;
            // Update overlay dimensions if provided by main app
            if (message.overlayWidth != null) {
              _overlayWidth = message.overlayWidth!;
            }
            if (message.overlayHeight != null) {
              _overlayHeight = message.overlayHeight!;
            }
          });

          Logger.debug('UPDATE received:', 'Overlay');
          Logger.debug('  speedText: "$_speedText"', 'Overlay');
          Logger.debug('  headingText: "$_headingText"', 'Overlay');
          Logger.debug('  direction: ${_heading.toStringAsFixed(1)}°', 'Overlay');
          Logger.debug('  themeIndex: $_currentThemeIndex', 'Overlay');
          Logger.debug('  systemScreenWidth: ${_systemScreenWidth.round()}', 'Overlay');
          Logger.debug('  overlaySize from main: ${_overlayWidth.round()}x${_overlayHeight.round()}', 'Overlay');
        }
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final buildTimestamp = DateTime.now().millisecondsSinceEpoch;
    final currentTheme = ColorThemes.getTheme(_currentThemeIndex);

    // Use overlay dimensions provided by main app (not calculated locally)
    final fontSize = (_overlayWidth * OverlayConfig.FONT_SIZE_RATIO);

    Logger.debug('Building overlay widget ($buildTimestamp)', 'Overlay');
    Logger.debug('Window size: ${_overlayWidth.round()}x${_overlayHeight.round()}, fontSize: ${fontSize.round()}', 'Overlay');

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        // Use SizedBox to fill the overlay window completely
        width: double.infinity,
        height: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            color: currentTheme.background.withValues(alpha: OverlayConfig.BACKGROUND_OPACITY),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: currentTheme.speedText.withValues(alpha: OverlayConfig.BORDER_OPACITY),
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
                                    fontSize: fontSize * OverlayConfig.UNIT_FONT_RATIO,
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
                                  size: fontSize * OverlayConfig.ICON_SIZE_RATIO,
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
                                  fontSize: fontSize * OverlayConfig.HEADING_FONT_RATIO,
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
                    Logger.debug('Pan start detected - gestures are working!', 'Overlay');
                  },
                  onLongPress: () async {
                    final timestamp = DateTime.now().millisecondsSinceEpoch;
                    Logger.info('Long press detected - closing overlay and bringing main app to front ($timestamp)', 'Overlay');
                    try {
                      // Skip haptic feedback in overlay - platform services not available
                      Logger.debug('Skipping haptic feedback (overlay context limitation)', 'Overlay');

                      // Signal main app to bring to foreground when overlay closes (non-blocking)
                      Logger.debug('Sending bring-to-front close signal...', 'Overlay');
                      FlutterOverlayWindow.shareData(OverlayMessage.longPressClose().toMap()).then((_) {
                        Logger.debug('Long press close signal sent successfully', 'Overlay');
                      }).catchError((error) {
                        Logger.warn('Long press close signal failed (expected): $error', 'Overlay');
                      });

                      // Small delay to give signal a chance
                      await Future.delayed(const Duration(milliseconds: 50));

                      // Close the overlay
                      Logger.info('Attempting to close overlay...', 'Overlay');
                      await FlutterOverlayWindow.closeOverlay();
                      Logger.info('Overlay closed successfully via long press', 'Overlay');

                    } catch (e, stackTrace) {
                      Logger.error('Long press close failed: $e', 'Overlay');
                      Logger.error('Stack trace: $stackTrace', 'Overlay');
                      // Fallback: try to close anyway
                      try {
                        Logger.debug('Attempting fallback close...', 'Overlay');
                        await FlutterOverlayWindow.closeOverlay();
                        Logger.info('Fallback close succeeded', 'Overlay');
                      } catch (fallbackError) {
                        Logger.error('Fallback close also failed: $fallbackError', 'Overlay');
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
