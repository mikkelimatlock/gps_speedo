import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class GpsService {
  static double? _lastValidHeading;
  
  static Stream<Position> get positionStream {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }
  
  static Future<bool> requestPermissions() async {
    final permission = await Permission.locationWhenInUse.request();
    return permission.isGranted;
  }
  
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
  
  static double getCachedHeading(double heading) {
    if (heading >= 0 && heading <= 360) {
      _lastValidHeading = heading;
      return heading;
    }
    return _lastValidHeading ?? 0.0;
  }
  
  static String getCompassDirection(double heading) {
    final cachedHeading = getCachedHeading(heading);
    
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((cachedHeading + 22.5) / 45).floor() % 8;
    return directions[index];
  }
  
  static String formatHeading(double heading) {
    final cachedHeading = getCachedHeading(heading);
    return '${cachedHeading.round()}° ${getCompassDirection(heading)}';
  }
}