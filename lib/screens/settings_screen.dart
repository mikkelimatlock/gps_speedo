import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            children: [
              _buildSectionHeader(context, 'Display'),
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Switch between light and dark themes'),
                value: settings.isDarkMode,
                onChanged: settings.setDarkMode,
              ),
              
              ListTile(
                title: const Text('Speed Unit'),
                subtitle: Text('Current: ${settings.speedUnitString}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showSpeedUnitDialog(context, settings),
              ),
              
              ListTile(
                title: const Text('Speedometer Style'),
                subtitle: Text(settings.speedometerStyle == SpeedometerStyle.digital 
                    ? 'Digital Display' 
                    : 'Analog Gauge'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showSpeedometerStyleDialog(context, settings),
              ),
              
              const Divider(),
              _buildSectionHeader(context, 'Information Display'),
              
              SwitchListTile(
                title: const Text('Show Coordinates'),
                subtitle: const Text('Display current latitude and longitude'),
                value: settings.showCoordinates,
                onChanged: settings.setShowCoordinates,
              ),
              
              SwitchListTile(
                title: const Text('Show Distance'),
                subtitle: const Text('Display total trip distance'),
                value: settings.showDistance,
                onChanged: settings.setShowDistance,
              ),
              
              SwitchListTile(
                title: const Text('Show Trip Time'),
                subtitle: const Text('Display elapsed trip time'),
                value: settings.showTripTime,
                onChanged: settings.setShowTripTime,
              ),
              
              SwitchListTile(
                title: const Text('Show GPS Accuracy'),
                subtitle: const Text('Display current GPS accuracy'),
                value: settings.showAccuracy,
                onChanged: settings.setShowAccuracy,
              ),
              
              const Divider(),
              _buildSectionHeader(context, 'About'),
              
              ListTile(
                title: const Text('GPS Speedometer'),
                subtitle: const Text('Version 1.0.0\nCreated with Claude Code'),
                leading: const Icon(Icons.info_outline),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showSpeedUnitDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Speed Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<SpeedUnit>(
              title: const Text('Kilometers per hour (km/h)'),
              value: SpeedUnit.kmh,
              groupValue: settings.speedUnit,
              onChanged: (value) {
                if (value != null) {
                  settings.setSpeedUnit(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<SpeedUnit>(
              title: const Text('Miles per hour (mph)'),
              value: SpeedUnit.mph,
              groupValue: settings.speedUnit,
              onChanged: (value) {
                if (value != null) {
                  settings.setSpeedUnit(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSpeedometerStyleDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Speedometer Style'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<SpeedometerStyle>(
              title: const Text('Digital Display'),
              subtitle: const Text('Clean numeric display'),
              value: SpeedometerStyle.digital,
              groupValue: settings.speedometerStyle,
              onChanged: (value) {
                if (value != null) {
                  settings.setSpeedometerStyle(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<SpeedometerStyle>(
              title: const Text('Analog Gauge'),
              subtitle: const Text('Classic circular speedometer'),
              value: SpeedometerStyle.analog,
              groupValue: settings.speedometerStyle,
              onChanged: (value) {
                if (value != null) {
                  settings.setSpeedometerStyle(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}