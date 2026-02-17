import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../gps_service.dart';
import '../config/speed_unit.dart';
import '../config/gps_constants.dart';
import '../config/timing_constants.dart';
import '../models/processed_gps_data.dart';
import '../providers/overlay_provider.dart';
import 'logger.dart';

class GpsDataManager extends ChangeNotifier with WidgetsBindingObserver {
  GpsDataManager();
  
  StreamSubscription<Position>? _gpsSubscription;
  final StreamController<ProcessedGpsData> _dataController =
      StreamController<ProcessedGpsData>.broadcast();

  ProcessedGpsData _currentData = ProcessedGpsData(
    speed: 0.0,
    heading: -1.0,
    displaySpeed: '--',
    displayHeading: 'N/A',
    isSpeedValid: false,
    isHeadingValid: false,
    timestamp: DateTime.now(),
  );

  Timer? _staleDataTimer;
  Timer? _backgroundGracePeriodTimer;
  bool _isDisposed = false;

  // Overlay provider reference for background decision-making
  OverlayProvider? _overlayProvider;

  // Lifecycle and precision state
  LocationAccuracy _currentAccuracy = LocationAccuracy.high;
  bool _hasFirstFix = false;
  DateTime? _firstFixTime;
  bool _isAppInForeground = true;
  bool _isGpsActive = false;

  // Public stream for UI components to subscribe to
  Stream<ProcessedGpsData> get dataStream => _dataController.stream;
  
  // Get current data synchronously (for immediate access)
  ProcessedGpsData get currentData => _currentData;
  
  bool _isInitialized = false;

  /// Set overlay provider reference for background GPS decision-making
  void setOverlayProvider(OverlayProvider provider) {
    _overlayProvider = provider;
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      Logger.warn('Already initialized, skipping...', 'GpsDataManager');
      return;
    }

    Logger.info('Starting GPS manager initialization...', 'GpsDataManager');

    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Check GPS permissions and services first
    final serviceEnabled = await GpsService.isLocationServiceEnabled();
    Logger.debug('Location service enabled: $serviceEnabled', 'GpsDataManager');
    if (!serviceEnabled) {
      Logger.error('GPS service disabled', 'GpsDataManager');
      _updateData(_currentData.copyWith(
        displaySpeed: 'GPS OFF',
        displayHeading: 'GPS OFF'
      ));
      _isInitialized = true; // Mark as initialized even if failed
      return;
    }
    
    final permissionGranted = await GpsService.requestPermissions();
    Logger.debug('GPS permission granted: $permissionGranted', 'GpsDataManager');
    if (!permissionGranted) {
      Logger.error('GPS permission denied', 'GpsDataManager');
      _updateData(_currentData.copyWith(
        displaySpeed: 'NO PERM',
        displayHeading: 'NO PERM'
      ));
      _isInitialized = true; // Mark as initialized even if failed
      return;
    }
    
    // Create GPS stream subscription
    Logger.debug('Creating GPS stream subscription...', 'GpsDataManager');

    try {
      Logger.debug('Getting initial GPS position with long timeout...', 'GpsDataManager');

      // First, get initial position with long timeout for cold start
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: GpsConfig.INITIAL_FIX_TIMEOUT,
        ),
      );

      Logger.info('Initial GPS fix obtained', 'GpsDataManager');
      _hasFirstFix = true;
      _firstFixTime = DateTime.now();
      _onPositionUpdate(initialPosition);

      // Then start position stream with current accuracy
      Logger.debug('Starting GPS stream with accuracy: $_currentAccuracy', 'GpsDataManager');
      _gpsSubscription = GpsService.createPositionStream(accuracy: _currentAccuracy).listen(
        (Position position) {
          Logger.debug('GPS callback triggered', 'GpsDataManager');
          _onPositionUpdate(position);
        },
        onError: (error) {
          Logger.error('GPS stream error callback: $error', 'GpsDataManager');
          _onGpsError(error);
        },
        onDone: () {
          Logger.warn('GPS stream done callback - stream ended', 'GpsDataManager');
        },
        cancelOnError: false,
      );

      Logger.info('GPS stream subscription created', 'GpsDataManager');
      Logger.debug('Subscription details: ${_gpsSubscription.runtimeType}', 'GpsDataManager');

      _isGpsActive = true;
      _updateWakeLock();
      _isInitialized = true;

    } catch (e, stackTrace) {
      Logger.error('GPS subscription creation failed: $e', 'GpsDataManager');
      Logger.error('Stack trace: $stackTrace', 'GpsDataManager');
      _updateData(_currentData.copyWith(
        displaySpeed: 'GPS ERR',
        displayHeading: 'GPS ERR'
      ));
      _isInitialized = true; // Mark as initialized even if failed
      return;
    }

    Logger.info('GPS manager initialized successfully', 'GpsDataManager');
  }
  
  void _onPositionUpdate(Position position) {
    Logger.debug('Raw GPS update: speed=${position.speed.toStringAsFixed(2)} m/s, heading=${position.heading.toStringAsFixed(1)}°', 'GpsDataManager');

    _scheduleStaleDataTimer();

    final rawSpeed = position.speed;
    final bool speedValid = rawSpeed.isFinite && rawSpeed >= 0;
    final double speed = speedValid ? rawSpeed : 0.0;

    final rawHeading = position.heading;
    final bool headingValid = rawHeading.isFinite && rawHeading >= GpsConfig.VALID_HEADING_MIN && rawHeading < GpsConfig.VALID_HEADING_MAX;
    final double heading = headingValid ? rawHeading : _currentData.heading;

    // Basic display logic - TEMPORARILY show all speeds for indoor testing
    // TODO: Re-enable low-speed logic later: (speed < GpsConfig.LOW_SPEED_THRESHOLD && (heading < GpsConfig.VALID_HEADING_MIN || heading >= GpsConfig.VALID_HEADING_MAX)) ? '--' : ...
    final displaySpeed = speed.toStringAsFixed(1);

    final displayHeading = headingValid
        ? GpsService.formatHeading(heading)
        : _currentData.displayHeading;

    Logger.debug('Processed: displaySpeed="$displaySpeed", displayHeading="$displayHeading"', 'GpsDataManager');

    final processedData = ProcessedGpsData(
      speed: speed,
      heading: heading,
      displaySpeed: displaySpeed,
      displayHeading: displayHeading,
      isSpeedValid: speedValid,
      isHeadingValid: headingValid,
      timestamp: DateTime.now(),
    );

    _updateData(processedData);

    // Check precision switching after first-fix gate
    if (_hasFirstFix && _firstFixTime != null) {
      final timeSinceFirstFix = DateTime.now().difference(_firstFixTime!);
      if (timeSinceFirstFix >= GpsConfig.PRECISION_SWITCH_FIRST_FIX_DELAY) {
        _checkPrecisionSwitch(position.speed);
      }
    }
  }
  
  void _onGpsError(dynamic error) {
    if (_isDisposed) return;
    // Handle GPS errors gracefully
    final errorString = error.toString().toLowerCase();
    if (!errorString.contains('timeout') && !errorString.contains('temporarily')) {
      _updateData(_currentData.copyWith(
        displaySpeed: 'GPS ERR',
        displayHeading: 'GPS ERR',
        isSpeedValid: false,
        isHeadingValid: false,
      ));
    }
  }
  
  void _scheduleStaleDataTimer() {
    _staleDataTimer?.cancel();
    _staleDataTimer = Timer(GpsConfig.STALE_DATA_THRESHOLD, _handleStaleDataTimeout);
  }

  void _handleStaleDataTimeout() {
    if (_isDisposed) return;
    // Avoid overriding explicit GPS error states or repeated stale notifications
    final displayText = _currentData.displaySpeed;
    if (displayText == '--' || displayText.startsWith('GPS') || displayText == 'NO PERM') {
      return;
    }

    final headingStillValid = _currentData.isHeadingValid && _currentData.heading >= GpsConfig.VALID_HEADING_MIN && _currentData.heading < GpsConfig.VALID_HEADING_MAX;
    final displayHeading = headingStillValid ? _currentData.displayHeading : '--';

    Logger.warn('No GPS updates within ${GpsConfig.STALE_DATA_THRESHOLD.inSeconds}s - marking data as stale', 'GpsDataManager');

    final staleData = _currentData.copyWith(
      displaySpeed: '--',
      displayHeading: displayHeading,
      isSpeedValid: false,
      isHeadingValid: headingStillValid,
    );

    _staleDataTimer = null;
    _updateData(staleData);
  }

  void _updateData(ProcessedGpsData newData) {
    if (_isDisposed) return;
    Logger.debug('Broadcasting data: ${newData.displaySpeed} ${newData.displayHeading}', 'GpsDataManager');
    _currentData = newData;
    _dataController.add(newData);
    notifyListeners();
    Logger.debug('Data broadcast complete', 'GpsDataManager');
  }
  
  // Format speed for specific unit (used by UI)
  String getFormattedSpeed(SpeedUnit unit) {
    if (_currentData.displaySpeed == '--') return '--';

    final convertedSpeed = unit.convert(_currentData.speed);
    return convertedSpeed < 1.0 ? '--' : convertedSpeed.toStringAsFixed(1);
  }

  /// Check if GPS precision should be switched based on speed
  void _checkPrecisionSwitch(double speedMps) {
    if (_currentAccuracy == LocationAccuracy.high) {
      // Switch to MEDIUM if speed drops below down-threshold
      if (speedMps < GpsConfig.PRECISION_DOWN_THRESHOLD_MPS) {
        _switchPrecision(LocationAccuracy.medium);
      }
    } else if (_currentAccuracy == LocationAccuracy.medium) {
      // Switch to HIGH if speed exceeds up-threshold
      if (speedMps > GpsConfig.PRECISION_UP_THRESHOLD_MPS) {
        _switchPrecision(LocationAccuracy.high);
      }
    }
  }

  /// Switch GPS precision and restart stream with new accuracy
  void _switchPrecision(LocationAccuracy newAccuracy) {
    if (_currentAccuracy == newAccuracy) return;

    final speedKmh = _currentData.speed * 3.6;
    Logger.debug('Precision switched to $newAccuracy at ${speedKmh.toStringAsFixed(1)} km/h', 'GpsDataManager');

    _currentAccuracy = newAccuracy;

    // Cancel existing subscription and create new one with new accuracy
    _gpsSubscription?.cancel();
    _gpsSubscription = GpsService.createPositionStream(accuracy: newAccuracy).listen(
      (Position position) {
        Logger.debug('GPS callback triggered', 'GpsDataManager');
        _onPositionUpdate(position);
      },
      onError: (error) {
        Logger.error('GPS stream error callback: $error', 'GpsDataManager');
        _onGpsError(error);
      },
      onDone: () {
        Logger.warn('GPS stream done callback - stream ended', 'GpsDataManager');
      },
      cancelOnError: false,
    );
  }

  /// Handle app lifecycle state changes for background GPS management
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App going to background
      _isAppInForeground = false;
      final overlayActive = _overlayProvider?.isOverlayActive ?? false;

      if (overlayActive) {
        Logger.info('App backgrounded with overlay active - maintaining full GPS', 'GpsDataManager');
      } else {
        Logger.info('App backgrounded without overlay - starting ${TimingConfig.BACKGROUND_GRACE_PERIOD.inSeconds}s grace period', 'GpsDataManager');
        _backgroundGracePeriodTimer?.cancel();
        _backgroundGracePeriodTimer = Timer(TimingConfig.BACKGROUND_GRACE_PERIOD, _onGracePeriodExpired);
      }

      _updateWakeLock();
    } else if (state == AppLifecycleState.resumed) {
      // App returning to foreground
      _isAppInForeground = true;

      // Cancel grace period if running
      _backgroundGracePeriodTimer?.cancel();
      _backgroundGracePeriodTimer = null;

      // Restart GPS if it was stopped
      if (_gpsSubscription == null && _isInitialized) {
        _restartGps();
      }

      _updateWakeLock();
    }
  }

  /// Grace period timer callback - re-check overlay state before stopping GPS
  void _onGracePeriodExpired() {
    // Race condition protection: overlay may have been activated during grace period
    final overlayActive = _overlayProvider?.isOverlayActive ?? false;

    if (overlayActive) {
      Logger.info('Overlay became active during grace period - keeping GPS', 'GpsDataManager');
      _backgroundGracePeriodTimer = null;
      return;
    }

    _stopGps();
    _backgroundGracePeriodTimer = null;
  }

  /// Stop GPS tracking (backgrounded without overlay)
  void _stopGps() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    _isGpsActive = false;
    _staleDataTimer?.cancel();
    _updateWakeLock();
    Logger.info('GPS stopped (backgrounded without overlay)', 'GpsDataManager');
  }

  /// Restart GPS tracking (app foregrounded)
  void _restartGps() {
    Logger.info('Restarting GPS (app foregrounded)', 'GpsDataManager');

    _gpsSubscription = GpsService.createPositionStream(accuracy: _currentAccuracy).listen(
      (Position position) {
        Logger.debug('GPS callback triggered', 'GpsDataManager');
        _onPositionUpdate(position);
      },
      onError: (error) {
        Logger.error('GPS stream error callback: $error', 'GpsDataManager');
        _onGpsError(error);
      },
      onDone: () {
        Logger.warn('GPS stream done callback - stream ended', 'GpsDataManager');
      },
      cancelOnError: false,
    );

    _isGpsActive = true;
    _updateWakeLock();
  }

  /// Update wake lock based on GPS state and app visibility
  void _updateWakeLock() {
    final overlayActive = _overlayProvider?.isOverlayActive ?? false;
    final shouldKeepAwake = _isGpsActive && (overlayActive || _isAppInForeground);

    if (shouldKeepAwake) {
      WakelockPlus.enable();
      Logger.debug('Wake lock enabled (GPS: $_isGpsActive, overlay: $overlayActive, foreground: $_isAppInForeground)', 'GpsDataManager');
    } else {
      WakelockPlus.disable();
      Logger.debug('Wake lock disabled (GPS: $_isGpsActive, overlay: $overlayActive, foreground: $_isAppInForeground)', 'GpsDataManager');
    }
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    Logger.info('Disposing GPS manager...', 'GpsDataManager');

    // Remove lifecycle observer BEFORE super.dispose()
    WidgetsBinding.instance.removeObserver(this);

    // Cancel all timers and subscriptions
    _backgroundGracePeriodTimer?.cancel();
    _backgroundGracePeriodTimer = null;

    if (_gpsSubscription != null) {
      Logger.debug('Cancelling GPS subscription...', 'GpsDataManager');
      _gpsSubscription?.cancel();
      _gpsSubscription = null;
    }

    _staleDataTimer?.cancel();
    _staleDataTimer = null;

    Logger.debug('Closing data controller...', 'GpsDataManager');
    _dataController.close();

    // Disable wake lock as safety net
    WakelockPlus.disable();

    Logger.info('GPS manager disposed', 'GpsDataManager');
    super.dispose();
  }
}
