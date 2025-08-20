import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SpeedUnitSelector extends StatelessWidget {
  const SpeedUnitSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: SpeedUnit.values.map((unit) {
            final isSelected = settings.speedUnit == unit;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ElevatedButton(
                  onPressed: () => settings.setSpeedUnit(unit),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surface,
                    foregroundColor: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    elevation: isSelected ? 4 : 1,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    _getUnitDisplayText(unit),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _getUnitDisplayText(SpeedUnit unit) {
    switch (unit) {
      case SpeedUnit.kmh:
        return 'km/h';
      case SpeedUnit.mph:
        return 'mph';
      case SpeedUnit.knots:
        return 'knots';
    }
  }
}