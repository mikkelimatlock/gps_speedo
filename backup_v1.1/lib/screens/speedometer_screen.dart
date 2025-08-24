import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/digital_speedometer.dart';
import '../widgets/analog_speedometer.dart';
import '../widgets/info_panel.dart';
import '../widgets/speed_unit_selector.dart';
import 'settings_screen.dart';

class SpeedometerScreen extends StatefulWidget {
  const SpeedometerScreen({super.key});

  @override
  State<SpeedometerScreen> createState() => _SpeedometerScreenState();
}

class _SpeedometerScreenState extends State<SpeedometerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationProvider>().initializeLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Speedometer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<LocationProvider>().resetTrip();
            },
            tooltip: 'Reset Trip',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer2<LocationProvider, SettingsProvider>(
        builder: (context, locationProvider, settingsProvider, child) {
          if (!locationProvider.hasLocationPermission) {
            return _buildPermissionError(locationProvider.errorMessage);
          }

          if (locationProvider.errorMessage.isNotEmpty) {
            return _buildError(locationProvider.errorMessage);
          }

          return Column(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Expanded(
                      child: _buildSpeedometer(locationProvider, settingsProvider),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: const SpeedUnitSelector(),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: InfoPanel(
                  locationProvider: locationProvider,
                  settingsProvider: settingsProvider,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSpeedometer(LocationProvider locationProvider, SettingsProvider settingsProvider) {
    final speed = settingsProvider.convertSpeed(locationProvider.currentSpeed);
    
    return GestureDetector(
      onTap: () {
        final newStyle = settingsProvider.speedometerStyle == SpeedometerStyle.digital
            ? SpeedometerStyle.analog
            : SpeedometerStyle.digital;
        settingsProvider.setSpeedometerStyle(newStyle);
      },
      child: settingsProvider.speedometerStyle == SpeedometerStyle.digital
          ? DigitalSpeedometer(
              speed: speed,
              unit: settingsProvider.speedUnitString,
            )
          : AnalogSpeedometer(
              speed: speed,
              unit: settingsProvider.speedUnitString,
            ),
    );
  }

  Widget _buildPermissionError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Location Permission Required',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.read<LocationProvider>().initializeLocation();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              'GPS Error',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.read<LocationProvider>().initializeLocation();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}