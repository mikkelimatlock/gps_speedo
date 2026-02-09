import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../gps_service.dart';
import '../config/speed_unit.dart';
import '../config/gps_constants.dart';
import '../models/processed_gps_data.dart';
import 'logger.dart';

class GpsDataManager {
  static GpsDataManager? _instance;
  static GpsDataManager get instance => _instance ??= GpsDataManager._internal();
  
  GpsDataManager._internal();
  
  StreamSubscription<Position>? _gpsSubscription;
  final StreamController<ProcessedGpsData> _dataController = 
      StreamController<ProcessedGpsData>.broadcast();
  
  ProcessedGpsData _currentData = const ProcessedGpsData(
    speed: 0.0,
    heading: -1.0,
    displaySpeed: '--',
    displayHeading: 'N/A',
    isSpeedValid: false,
    isHeadingValid: false,
  );
  
  Timer? _staleDataTimer;

  // Public stream for UI components to subscribe to
  Stream<ProcessedGpsData> get dataStream => _dataController.stream;
  
  // Get current data synchronously (for immediate access)
  ProcessedGpsData get currentData => _currentData;
  
  bool _isInitialized = false;
  
  Future<void> initialize() async {
    if (_isInitialized) {
      Logger.warn('Already initialized, skipping...', 'GpsDataManager');
      return;
    }

    Logger.info('Starting GPS manager initialization...', 'GpsDataManager');

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
      _onPositionUpdate(initialPosition);

      // Then start position stream with shorter timeout for updates
      Logger.debug('Starting GPS stream with short update timeout...', 'GpsDataManager');
      _gpsSubscription = GpsService.positionStream.listen(
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
    );

    _updateData(processedData);
  }
  
  void _onGpsError(dynamic error) {
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
    Logger.debug('Broadcasting data: ${newData.displaySpeed} ${newData.displayHeading}', 'GpsDataManager');
    _currentData = newData;
    _dataController.add(newData);
    Logger.debug('Data broadcast complete', 'GpsDataManager');
  }
  
  // Format speed for specific unit (used by UI)
  String getFormattedSpeed(SpeedUnit unit) {
    if (_currentData.displaySpeed == '--') return '--';
    
    final convertedSpeed = unit.convert(_currentData.speed);
    return convertedSpeed < 1.0 ? '--' : convertedSpeed.toStringAsFixed(1);
  }
  
  void dispose() {
    Logger.info('Disposing GPS manager...', 'GpsDataManager');
    if (_gpsSubscription != null) {
      Logger.debug('Cancelling GPS subscription...', 'GpsDataManager');
      _gpsSubscription?.cancel();
      _gpsSubscription = null;
    }
    Logger.debug('Closing data controller...', 'GpsDataManager');
    _staleDataTimer?.cancel();
    _staleDataTimer = null;
    _dataController.close();
    _isInitialized = false;
    Logger.info('GPS manager disposed', 'GpsDataManager');
  }
}
