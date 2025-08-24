import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationProvider extends ChangeNotifier {
  Position? _currentPosition;
  double _currentSpeed = 0.0;
  double _totalDistance = 0.0;
  DateTime? _tripStartTime;
  bool _isTracking = false;
  bool _hasLocationPermission = false;
  String _errorMessage = '';
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _previousPosition;

  Position? get currentPosition => _currentPosition;
  double get currentSpeed => _currentSpeed;
  double get totalDistance => _totalDistance;
  DateTime? get tripStartTime => _tripStartTime;
  bool get isTracking => _isTracking;
  bool get hasLocationPermission => _hasLocationPermission;
  String get errorMessage => _errorMessage;
  
  double? get latitude => _currentPosition?.latitude;
  double? get longitude => _currentPosition?.longitude;
  double? get accuracy => _currentPosition?.accuracy;

  Duration get tripDuration {
    if (_tripStartTime == null) return Duration.zero;
    return DateTime.now().difference(_tripStartTime!);
  }

  Future<void> initializeLocation() async {
    await _checkLocationPermission();
    if (_hasLocationPermission) {
      await _startLocationTracking();
    }
  }

  Future<void> _checkLocationPermission() async {
    final permission = await Permission.locationWhenInUse.status;
    
    if (permission.isDenied) {
      final result = await Permission.locationWhenInUse.request();
      _hasLocationPermission = result.isGranted;
    } else if (permission.isPermanentlyDenied) {
      _hasLocationPermission = false;
      _errorMessage = 'Location permission is permanently denied. Please enable it in settings.';
    } else {
      _hasLocationPermission = permission.isGranted;
    }

    if (!_hasLocationPermission) {
      _errorMessage = 'Location permission is required for the speedometer to work.';
    } else {
      _errorMessage = '';
    }

    notifyListeners();
  }

  Future<void> _startLocationTracking() async {
    if (!_hasLocationPermission) return;

    try {
      final isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationServiceEnabled) {
        _errorMessage = 'Location services are disabled. Please enable them.';
        notifyListeners();
        return;
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onLocationUpdate,
        onError: (error) {
          _errorMessage = 'Location error: $error';
          notifyListeners();
        },
      );

      _isTracking = true;
      _tripStartTime = DateTime.now();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to start location tracking: $e';
      notifyListeners();
    }
  }

  void _onLocationUpdate(Position position) {
    _currentPosition = position;
    _currentSpeed = position.speed;

    if (_previousPosition != null) {
      final distance = Geolocator.distanceBetween(
        _previousPosition!.latitude,
        _previousPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      _totalDistance += distance;
    }

    _previousPosition = position;
    _errorMessage = '';
    notifyListeners();
  }

  void resetTrip() {
    _totalDistance = 0.0;
    _tripStartTime = DateTime.now();
    _previousPosition = _currentPosition;
    notifyListeners();
  }

  Future<void> stopTracking() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isTracking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}