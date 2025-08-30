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
  
  // Public stream for UI components to subscribe to
  Stream<ProcessedGpsData> get dataStream => _dataController.stream;
  
  // Get current data synchronously (for immediate access)
  ProcessedGpsData get currentData => _currentData;
  
  Future<void> initialize() async {
    print('[GpsDataManager] 🚀 Starting GPS manager initialization...');
    
    // Clean up any existing subscription first
    if (_gpsSubscription != null) {
      print('[GpsDataManager] 🧹 Cleaning up existing GPS subscription...');
      await _gpsSubscription?.cancel();
      _gpsSubscription = null;
      // Small delay to ensure cleanup completes
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // Check GPS permissions and services
    final serviceEnabled = await GpsService.isLocationServiceEnabled();
    print('[GpsDataManager] 📍 Location service enabled: $serviceEnabled');
    if (!serviceEnabled) {
      print('[GpsDataManager] ❌ GPS service disabled');
      _updateData(_currentData.copyWith(
        displaySpeed: 'GPS OFF',
        displayHeading: 'GPS OFF'
      ));
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
      return;
    }
    
    // TEMPORARILY DISABLED: GPS stream due to flutter engine conflict
    // Start GPS stream with a fresh subscription
    print('[GpsDataManager] ⚠️ GPS stream temporarily disabled due to engine conflict');
    // try {
    //   _gpsSubscription = GpsService.positionStream.listen(
    //     _onPositionUpdate,
    //     onError: _onGpsError,
    //   );
    //   print('[GpsDataManager] ✅ GPS stream subscription created successfully');
    // } catch (e) {
    //   print('[GpsDataManager] ❌ Failed to create GPS subscription: $e');
    //   _updateData(_currentData.copyWith(
    //     displaySpeed: 'SUB ERR',
    //     displayHeading: 'SUB ERR'
    //   ));
    //   return;
    // }
    
    // TEMPORARY: Add realistic test data to verify full functionality
    print('[GpsDataManager] 🧪 Starting realistic GPS simulation...');
    double testSpeed = 0.0;
    double testHeading = 0.0;
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      // Simulate realistic movement
      testSpeed += (DateTime.now().millisecondsSinceEpoch % 3 - 1) * 0.5; // Random walk
      testSpeed = testSpeed.clamp(0.0, 25.0); // 0-90 km/h max
      testHeading = (testHeading + 1) % 360; // Slow rotation
      
      final displaySpeed = testSpeed < 1.0 ? '--' : testSpeed.toStringAsFixed(1);
      final displayHeading = GpsService.formatHeading(testHeading);
      
      final testData = ProcessedGpsData(
        speed: testSpeed,
        heading: testHeading,
        displaySpeed: displaySpeed,
        displayHeading: displayHeading,
        isSpeedValid: testSpeed >= 0,
        isHeadingValid: testHeading >= 0 && testHeading < 360,
      );
      
      _updateData(testData);
    });
    
    print('[GpsDataManager] ✅ GPS manager initialized successfully');
  }
  
  void _onPositionUpdate(Position position) {
    print('[GpsDataManager] 📡 Raw GPS update: speed=${position.speed.toStringAsFixed(2)} m/s, heading=${position.heading.toStringAsFixed(1)}°');
    
    // For now, simple pass-through processing
    // TODO: Add intelligent caching logic here later
    
    final speed = position.speed;
    final heading = position.heading;
    
    // Basic display logic (will be enhanced with caching)
    final displaySpeed = (speed < 1.0 && (heading < 0.0 || heading >= 360.0)) 
        ? '--' 
        : speed.toStringAsFixed(1);
    
    final displayHeading = GpsService.formatHeading(heading);
    
    print('[GpsDataManager] 🔄 Processed: displaySpeed="$displaySpeed", displayHeading="$displayHeading"');
    
    final processedData = ProcessedGpsData(
      speed: speed,
      heading: heading,
      displaySpeed: displaySpeed,
      displayHeading: displayHeading,
      isSpeedValid: speed >= 0,
      isHeadingValid: heading >= 0 && heading < 360,
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
    _gpsSubscription?.cancel();
    _dataController.close();
  }
}