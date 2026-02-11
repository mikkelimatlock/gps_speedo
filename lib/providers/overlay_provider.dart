import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:bg_launcher/bg_launcher.dart';
import '../config/overlay_constants.dart';
import '../config/timing_constants.dart';
import '../config/speed_unit.dart';
import '../models/overlay_message.dart';
import '../models/processed_gps_data.dart';
import '../services/gps_data_manager.dart';
import '../services/logger.dart';
import '../services/overlay_service.dart';

enum OverlayError { permission, creationFailed, communicationDegraded }

class OverlayProvider extends ChangeNotifier {
  final OverlayService _overlayService;

  bool _isOverlayActive = false;
  bool _isDisposed = false;
  bool _tapCloseRequested = false;

  StreamSubscription<ProcessedGpsData>? _gpsSubscription;
  StreamSubscription<dynamic>? _overlayMessageSubscription;
  Timer? _overlayStatusCheckTimer;
  Timer? _tapCloseTimer;
  Timer? _gracePeriodTimer;

  // Dependencies — set via update() from ProxyProvider
  GpsDataManager? _gpsManager;
  SpeedUnit _currentUnit = SpeedUnit.kmh;
  int _currentThemeIndex = 0;

  // Error callback — set by SpeedometerScreen after provider is available
  void Function(OverlayError)? onError;

  OverlayProvider(this._overlayService);

  bool get isOverlayActive => _isOverlayActive;

  /// Called by ChangeNotifierProxyProvider2 when GpsDataManager or SettingsProvider changes.
  /// Sets up GPS stream subscription on first call, updates settings references on subsequent calls.
  void updateDependencies({
    required GpsDataManager gpsManager,
    required SpeedUnit currentUnit,
    required int currentThemeIndex,
  }) {
    if (_isDisposed) return;

    _currentUnit = currentUnit;
    _currentThemeIndex = currentThemeIndex;

    // Subscribe to GPS stream on first update (only once)
    if (_gpsManager == null) {
      _gpsManager = gpsManager;
      _gpsSubscription = gpsManager.dataStream.listen((data) {
        if (_isOverlayActive && !_isDisposed) {
          _pushDataToOverlay(data);
        }
      });
      Logger.debug('GPS stream subscription created for overlay', 'OverlayProvider');
    }

    // Push updated settings to overlay if active
    if (_isOverlayActive && _gpsManager != null) {
      _pushDataToOverlay(_gpsManager!.currentData);
    }
  }

  /// Show the floating overlay window
  Future<void> showOverlay() async {
    if (_isDisposed) return;

    // Cancel grace period if user reopens overlay within grace period
    _gracePeriodTimer?.cancel();
    _gracePeriodTimer = null;

    try {
      // Check permission before attempting to show overlay
      final hasPermission = await _overlayService.checkPermission();
      if (!hasPermission) {
        Logger.warn('Overlay permission denied', 'OverlayProvider');
        onError?.call(OverlayError.permission);
        return;
      }

      final overlaySize = _getOverlaySize();
      final gpsData = _gpsManager?.currentData;

      // Send initial display data WITH size info
      final speedText = _gpsManager?.getFormattedSpeed(_currentUnit) ?? '--';
      final headingText = gpsData?.displayHeading ?? 'N/A';
      final unitText = _currentUnit.label;

      await _overlayService.shareData(OverlayMessage.updateDisplay(
        speedText: speedText,
        unitText: unitText,
        headingText: headingText,
        heading: gpsData?.heading ?? -1.0,
        unitIndex: _currentUnit.index,
        themeIndex: _currentThemeIndex,
        overlayWidth: overlaySize['width']!.toDouble(),
        overlayHeight: overlaySize['height']!.toDouble(),
      ).toMap());

      final success = await _overlayService.showOverlay(
        width: overlaySize['width']!,
        height: overlaySize['height']!,
      );

      if (!success) {
        Logger.error('Overlay creation failed or verification failed', 'OverlayProvider');
        onError?.call(OverlayError.creationFailed);
        return;
      }

      Logger.info('OVERLAY LAUNCHED - Size: ${overlaySize['width']}x${overlaySize['height']}', 'OverlayProvider');

      _isOverlayActive = true;
      _startListeningToOverlayMessages();
      _startOverlayStatusCheck();
      notifyListeners();
    } catch (e) {
      Logger.error('Failed to show overlay: $e', 'OverlayProvider');
      onError?.call(OverlayError.creationFailed);
    }
  }

  /// Close the floating overlay window
  Future<void> closeOverlay() async {
    if (!_isOverlayActive || _isDisposed) return;

    try {
      await _overlayService.closeOverlay();
      Logger.info('OVERLAY CLOSED - Requested from main app', 'OverlayProvider');
      _handleOverlayClose();
    } catch (e) {
      Logger.error('Error closing overlay: $e', 'OverlayProvider');
    }
  }

  /// Toggle overlay state (show if hidden, close if active)
  Future<void> toggleOverlay() async {
    if (_isOverlayActive) {
      await closeOverlay();
    } else {
      await showOverlay();
    }
  }

  Map<String, int> _getOverlaySize() {
    final window = WidgetsBinding.instance.platformDispatcher.views.first;
    final physicalSize = window.physicalSize;
    final overlayWidth = (physicalSize.width * OverlayConfig.WIDTH_PERCENTAGE).round();
    final overlayHeight = (overlayWidth * OverlayConfig.ASPECT_RATIO).round();
    return {'width': overlayWidth, 'height': overlayHeight};
  }

  void _pushDataToOverlay(ProcessedGpsData gpsData) {
    if (!_isOverlayActive || _isDisposed) return;

    final speedText = _gpsManager?.getFormattedSpeed(_currentUnit) ?? '--';
    final unitText = _currentUnit.label;
    final headingText = gpsData.displayHeading;

    Logger.debug('Pushing to overlay: speed="$speedText", heading="$headingText"', 'OverlayProvider');

    _overlayService.shareData(OverlayMessage.updateDisplay(
      speedText: speedText,
      unitText: unitText,
      headingText: headingText,
      heading: gpsData.heading,
      unitIndex: _currentUnit.index,
      themeIndex: _currentThemeIndex,
    ).toMap());
  }

  void _startListeningToOverlayMessages() {
    if (_overlayMessageSubscription != null) return;

    _overlayMessageSubscription = _overlayService.overlayListener.listen(
      (data) {
        try {
          if (data is Map) {
            final action = data['action'];
            switch (action) {
              case 'overlayClosed':
                _handleOverlayClose();
                break;
              case 'longPressClose':
                _tapCloseRequested = true;
                _tapCloseTimer?.cancel();
                _tapCloseTimer = Timer(TimingConfig.TAP_CLOSE_DELAY, () {
                  _tapCloseRequested = false;
                });
                break;
              default:
                Logger.warn('Unknown overlay action: "$action"', 'OverlayProvider');
            }
          }
        } catch (e) {
          Logger.error('Error processing overlay message: $e', 'OverlayProvider');
        }
      },
      onError: (error) {
        Logger.error('Overlay listener error: $error', 'OverlayProvider');
      },
    );
  }

  void _stopListeningToOverlayMessages() {
    _overlayMessageSubscription?.cancel();
    _overlayMessageSubscription = null;
  }

  void _startOverlayStatusCheck() {
    _overlayStatusCheckTimer?.cancel();

    _overlayStatusCheckTimer = Timer.periodic(TimingConfig.OVERLAY_STATUS_CHECK_INTERVAL, (timer) async {
      if (_isOverlayActive && !_isDisposed) {
        try {
          final isActive = await _overlayService.isActive();
          if (!isActive) {
            timer.cancel();
            _handleOverlayClose();
          }
        } catch (e) {
          Logger.error('Overlay status check failed: $e', 'OverlayProvider');
        }
      } else {
        timer.cancel();
      }
    });
    Logger.debug('Started overlay status monitoring', 'OverlayProvider');
  }

  void _handleOverlayClose({bool bringToForeground = false}) {
    if (_isDisposed) return;

    final shouldBringToFront = bringToForeground || _tapCloseRequested;

    _tapCloseTimer?.cancel();
    _overlayStatusCheckTimer?.cancel();
    _tapCloseRequested = false;

    _isOverlayActive = false;
    _stopListeningToOverlayMessages();
    notifyListeners();

    // Start GPS grace period (30s) — infrastructure for Phase 4
    _gracePeriodTimer?.cancel();
    _gracePeriodTimer = Timer(TimingConfig.GPS_GRACE_PERIOD, () {
      Logger.info('GPS grace period expired', 'OverlayProvider');
      _gracePeriodTimer = null;
    });

    if (shouldBringToFront) {
      _bringAppToFront();
    }
  }

  void _bringAppToFront() {
    try {
      BgLauncher.bringAppToForeground();
    } catch (e) {
      Logger.error('BgLauncher failed to bring app to front: $e', 'OverlayProvider');
    }
  }

  /// Push current data to overlay — used by background heartbeat
  void pushCurrentData() {
    if (_isOverlayActive && _gpsManager != null && !_isDisposed) {
      _pushDataToOverlay(_gpsManager!.currentData);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _gpsSubscription?.cancel();
    _overlayMessageSubscription?.cancel();
    _overlayStatusCheckTimer?.cancel();
    _tapCloseTimer?.cancel();
    _gracePeriodTimer?.cancel();
    Logger.info('OverlayProvider disposed', 'OverlayProvider');
    super.dispose();
  }
}
