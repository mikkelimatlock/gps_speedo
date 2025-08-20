import 'package:flutter/material.dart';
import '../providers/location_provider.dart';
import '../providers/settings_provider.dart';

class InfoPanel extends StatelessWidget {
  final LocationProvider locationProvider;
  final SettingsProvider settingsProvider;

  const InfoPanel({
    super.key,
    required this.locationProvider,
    required this.settingsProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (settingsProvider.showCoordinates ||
              settingsProvider.showDistance ||
              settingsProvider.showTripTime ||
              settingsProvider.showAccuracy)
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: _buildInfoCards(context),
              ),
            )
          else
            Expanded(
              child: Center(
                child: Text(
                  'Enable additional metrics in settings',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildInfoCards(BuildContext context) {
    final cards = <Widget>[];

    if (settingsProvider.showCoordinates) {
      cards.add(_buildInfoCard(
        context,
        'Location',
        '${locationProvider.latitude?.toStringAsFixed(6) ?? '--'}\n${locationProvider.longitude?.toStringAsFixed(6) ?? '--'}',
        Icons.location_on,
      ));
    }

    if (settingsProvider.showDistance) {
      final distanceKm = locationProvider.totalDistance / 1000;
      final distanceText = distanceKm < 1 
          ? '${locationProvider.totalDistance.toStringAsFixed(0)} m'
          : '${distanceKm.toStringAsFixed(2)} km';
      
      cards.add(_buildInfoCard(
        context,
        'Distance',
        distanceText,
        Icons.straighten,
      ));
    }

    if (settingsProvider.showTripTime) {
      final duration = locationProvider.tripDuration;
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      final seconds = duration.inSeconds % 60;
      
      String timeText;
      if (hours > 0) {
        timeText = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      } else {
        timeText = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      }
      
      cards.add(_buildInfoCard(
        context,
        'Trip Time',
        timeText,
        Icons.timer,
      ));
    }

    if (settingsProvider.showAccuracy) {
      final accuracy = locationProvider.accuracy;
      final accuracyText = accuracy != null 
          ? '±${accuracy.toStringAsFixed(0)} m'
          : '--';
      
      cards.add(_buildInfoCard(
        context,
        'Accuracy',
        accuracyText,
        Icons.gps_fixed,
      ));
    }

    return cards;
  }

  Widget _buildInfoCard(BuildContext context, String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}