class ProcessedGpsData {
  final double speed;           // Raw speed in m/s
  final double heading;         // Raw heading in degrees
  final String displaySpeed;    // Formatted speed text (with -- logic)
  final String displayHeading;  // Formatted heading text
  final bool isSpeedValid;      // True if from recent GPS
  final bool isHeadingValid;    // True if from recent GPS
  final DateTime timestamp;     // Timestamp for staleness detection

  const ProcessedGpsData({
    required this.speed,
    required this.heading,
    required this.displaySpeed,
    required this.displayHeading,
    required this.isSpeedValid,
    required this.isHeadingValid,
    required this.timestamp,
  });

  ProcessedGpsData copyWith({
    double? speed,
    double? heading,
    String? displaySpeed,
    String? displayHeading,
    bool? isSpeedValid,
    bool? isHeadingValid,
    DateTime? timestamp,
  }) {
    return ProcessedGpsData(
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      displaySpeed: displaySpeed ?? this.displaySpeed,
      displayHeading: displayHeading ?? this.displayHeading,
      isSpeedValid: isSpeedValid ?? this.isSpeedValid,
      isHeadingValid: isHeadingValid ?? this.isHeadingValid,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
