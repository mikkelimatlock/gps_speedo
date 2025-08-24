import 'package:flutter/material.dart';

class DigitalSpeedometer extends StatelessWidget {
  final double speed;
  final String unit;

  const DigitalSpeedometer({
    super.key,
    required this.speed,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final speedText = speed.toStringAsFixed(0);
    
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
              color: theme.colorScheme.surface,
            ),
            child: Column(
              children: [
                Text(
                  speedText,
                  style: TextStyle(
                    fontSize: 80,
                    fontWeight: FontWeight.bold,
                    color: _getSpeedColor(speed, theme),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  unit,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSpeedIndicator(speed, theme),
        ],
      ),
    );
  }

  Color _getSpeedColor(double speed, ThemeData theme) {
    if (speed < 30) {
      return Colors.green;
    } else if (speed < 60) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Widget _buildSpeedIndicator(double speed, ThemeData theme) {
    final maxSpeed = 120.0;
    final progress = (speed / maxSpeed).clamp(0.0, 1.0);
    
    return Column(
      children: [
        Text(
          'Speed Progress',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 200,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _getSpeedColor(speed, theme),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toStringAsFixed(0)}%',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}