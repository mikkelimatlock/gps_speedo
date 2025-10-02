import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../gps_service.dart';
import '../speed_units.dart';

class ProcessedGpsData {
  final double speed;           // Raw speed in m/s
  final double heading;         // Raw heading in degrees
  final String displaySpeed;    // Formatted speed text (with -- logic)
  final String displayHeading;  // Formatted heading text
  final bool isSpeedValid;      // True if from recent GPS
  final bool isHeadingValid;    // True if from recent GPS
  
  const ProcessedGpsData({
    required this.speed,
    required this.heading,
    required this.displaySpeed,
    required this.displayHeading,
    required this.isSpeedValid,
    required this.isHeadingValid,
  });
  
  ProcessedGpsData copyWith({
    double? speed,
    double? heading,
    String? displaySpeed,
    String? displayHeading,
    bool? isSpeedValid,
    bool? isHeadingValid,
  }) {
    return ProcessedGpsData(
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      displaySpeed: displaySpeed ?? this.displaySpeed,
      displayHeading: displayHeading ?? this.displayHeading,
      isSpeedValid: isSpeedValid ?? this.isSpeedValid,
      isHeadingValid: isHeadingValid ?? this.isHeadingValid,
    );
  }
}

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
  
  static const Duration _staleDataThreshold = Duration(seconds: 4);
  Timer? _staleDataTimer;

  // Public stream for UI components to subscribe to
  Stream<ProcessedGpsData> get dataStream => _dataController.stream;
  
  // Get current data synchronously (for immediate access)
  ProcessedGpsData get currentData => _currentData;
  
  bool _isInitialized = false;
  
  Future<void> initialize() async {
    if (_isInitialized) {
      print('[GpsDataManager] ⚠️ Already initialized, skipping...');
      return;
    }
    
    print('[GpsDataManager] 🚀 Starting GPS manager initialization...');
    
    // Check GPS permissions and services first
    final serviceEnabled = await GpsService.isLocationServiceEnabled();
    print('[GpsDataManager] 📍 Location service enabled: $serviceEnabled');
    if (!serviceEnabled) {
      print('[GpsDataManager] ❌ GPS service disabled');
      _updateData(_currentData.copyWith(
        displaySpeed: 'GPS OFF',
        displayHeading: 'GPS OFF'
      ));
      _isInitialized = true; // Mark as initialized even if failed
      return;
    }
    
    final permissionGranted = await GpsService.requestPermissions();
    print('[GpsDataManager] 🔐 GPS permission granted: $permissionGranted');
    if (!permissionGranted) {
      print('[GpsDataManager] ❌ GPS permission denied');
      _updateData(_currentData.copyWith(
        displaySpeed: 'NO PERM',
        displayHeading: 'NO PERM'
      ));
      _isInitialized = true; // Mark as initialized even if failed
      return;
    }
    
    // Create GPS stream subscription
    print('[GpsDataManager] 📡 Creating GPS stream subscription...');
    
    try {
      print('[GpsDataManager] 🔧 Getting initial GPS position with long timeout...');
      
      // First, get initial position with long timeout for cold start
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 20), // Long timeout for initial fix
        ),
      );
      
      print('[GpsDataManager] ✅ Initial GPS fix obtained');
      _onPositionUpdate(initialPosition);
      
      // Then start position stream with shorter timeout for updates
      print('[GpsDataManager] 🔧 Starting GPS stream with short update timeout...');
      _gpsSubscription = GpsService.positionStream.listen(
        (Position position) {
          print('[GpsDataManager] 📥 GPS callback triggered');
          _onPositionUpdate(position);
        },
        onError: (error) {
          print('[GpsDataManager] ❌ GPS stream error callback: $error');
          _onGpsError(error);
        },
        onDone: () {
          print('[GpsDataManager] ⚠️ GPS stream done callback - stream ended');
        },
        cancelOnError: false,
      );
      
      print('[GpsDataManager] ✅ GPS stream subscription created');
      print('[GpsDataManager] 🔍 Subscription details: ${_gpsSubscription.runtimeType}');
      
      _isInitialized = true;
      
    } catch (e, stackTrace) {
      print('[GpsDataManager] ❌ GPS subscription creation failed: $e');
      print('[GpsDataManager] 📚 Stack trace: $stackTrace');
      _updateData(_currentData.copyWith(
        displaySpeed: 'GPS ERR',
        displayHeading: 'GPS ERR'
      ));
      _isInitialized = true; // Mark as initialized even if failed
      return;
    }
    
    print('[GpsDataManager] ✅ GPS manager initialized successfully');
  }
  
  void _onPositionUpdate(Position position) {
    print('[GpsDataManager] 📡 Raw GPS update: speed=${position.speed.toStringAsFixed(2)} m/s, heading=${position.heading.toStringAsFixed(1)}°');

    _scheduleStaleDataTimer();

    final rawSpeed = position.speed;
    final bool speedValid = rawSpeed.isFinite && rawSpeed >= 0;
    final double speed = speedValid ? rawSpeed : 0.0;

    final rawHeading = position.heading;
    final bool headingValid = rawHeading.isFinite && rawHeading >= 0 && rawHeading < 360;
    final double heading = headingValid ? rawHeading : _currentData.heading;

    // Basic display logic - TEMPORARILY show all speeds for indoor testing
    // TODO: Re-enable low-speed logic later: (speed < 1.0 && (heading < 0.0 || heading >= 360.0)) ? '--' : ...
    final displaySpeed = speed.toStringAsFixed(1);

    final displayHeading = headingValid
        ? GpsService.formatHeading(heading)
        : _currentData.displayHeading;

    print('[GpsDataManager] 🔄 Processed: displaySpeed="$displaySpeed", displayHeading="$displayHeading"');

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
    _staleDataTimer = Timer(_staleDataThreshold, _handleStaleDataTimeout);
  }

  void _handleStaleDataTimeout() {
    // Avoid overriding explicit GPS error states or repeated stale notifications
    final displayText = _currentData.displaySpeed;
    if (displayText == '--' || displayText.startsWith('GPS') || displayText == 'NO PERM') {
      return;
    }

    final headingStillValid = _currentData.isHeadingValid && _currentData.heading >= 0 && _currentData.heading < 360;
    final displayHeading = headingStillValid ? _currentData.displayHeading : '--';

    print('[GpsDataManager] ⏱️ No GPS updates within ${_staleDataThreshold.inSeconds}s - marking data as stale');

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
    print('[GpsDataManager] 📤 Broadcasting data: ${newData.displaySpeed} ${newData.displayHeading}');
    _currentData = newData;
    _dataController.add(newData);
    print('[GpsDataManager] ✅ Data broadcast complete');
  }
  
  // Format speed for specific unit (used by UI)
  String getFormattedSpeed(SpeedUnit unit) {
    if (_currentData.displaySpeed == '--') return '--';
    
    final convertedSpeed = unit.convert(_currentData.speed);
    return convertedSpeed < 1.0 ? '--' : convertedSpeed.toStringAsFixed(1);
  }
  
  void dispose() {
    print('[GpsDataManager] 🛑 Disposing GPS manager...');
    if (_gpsSubscription != null) {
      print('[GpsDataManager] 🛑 Cancelling GPS subscription...');
      _gpsSubscription?.cancel();
      _gpsSubscription = null;
    }
    print('[GpsDataManager] 🛑 Closing data controller...');
    _staleDataTimer?.cancel();
    _staleDataTimer = null;
    _dataController.close();
    _isInitialized = false;
    print('[GpsDataManager] 🛑 GPS manager disposed');
  }
}
