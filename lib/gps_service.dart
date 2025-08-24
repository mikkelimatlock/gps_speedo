import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class GpsService {
  static Stream<Position> get positionStream {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
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
  
  static String getCompassDirection(double heading) {
    if (heading < 0) return 'N/A';
    
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((heading + 22.5) / 45).floor() % 8;
    return directions[index];
  }
  
  static String formatHeading(double heading) {
    if (heading < 0) return 'N/A';
    return '${heading.round()} ${getCompassDirection(heading)}';
  }
}