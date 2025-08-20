import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/location_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/speedometer_screen.dart';

void main() {
  runApp(const SpeedometerApp());
}

class SpeedometerApp extends StatelessWidget {
  const SpeedometerApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'GPS Speedometer',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(settings.isDarkMode),
            home: const SpeedometerScreen(),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(bool isDarkMode) {
    return ThemeData(
      useMaterial3: true,
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
    );
  }
}
