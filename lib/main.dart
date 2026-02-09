import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'screens/speedometer_screen.dart';
import 'screens/overlay_screen.dart';
import 'services/logger.dart';

void main() {
  runApp(const SpeedoApp());
}

// Entry point for overlay window
@pragma("vm:entry-point")
void overlayMain() {
  Logger.info('overlayMain() called', 'Overlay');
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlaySpeedometer(),
  ));
}

class SpeedoApp extends StatelessWidget {
  final bool isOverlayMode;
  
  const SpeedoApp({super.key, this.isOverlayMode = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speedo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.green,
      ),
      home: SpeedometerScreen(isOverlayMode: isOverlayMode),
    );
  }
}