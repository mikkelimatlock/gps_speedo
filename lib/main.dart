import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/speedometer_screen.dart';
import 'screens/overlay_screen.dart';
import 'services/gps_data_manager.dart';
import 'services/overlay_service.dart';
import 'providers/settings_provider.dart';
import 'providers/overlay_provider.dart';
import 'services/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        Provider<SharedPreferences>.value(value: prefs),
        Provider<OverlayService>(create: (_) => OverlayService()),
        ChangeNotifierProvider(
          create: (context) => SettingsProvider(context.read<SharedPreferences>()),
        ),
        ChangeNotifierProvider(
          create: (_) => GpsDataManager(),
        ),
        ChangeNotifierProxyProvider2<GpsDataManager, SettingsProvider, OverlayProvider>(
          create: (context) => OverlayProvider(context.read<OverlayService>()),
          update: (_, gpsManager, settings, overlay) => overlay!
            ..updateDependencies(
              gpsManager: gpsManager,
              currentUnit: settings.currentUnit,
              currentThemeIndex: settings.currentThemeIndex,
            ),
        ),
      ],
      child: const SpeedoApp(),
    ),
  );
}

@pragma("vm:entry-point")
void overlayMain() {
  Logger.info('overlayMain() called', 'Overlay');
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlaySpeedometer(),
  ));
}

class SpeedoApp extends StatelessWidget {
  const SpeedoApp({super.key});

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
      home: const SpeedometerScreen(),
    );
  }
}
