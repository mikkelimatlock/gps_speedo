/// Typed message class for overlay IPC communication
/// Replaces unvalidated Map data with type-safe serialization
class OverlayMessage {
  final String action;
  final String? speedText;
  final String? unitText;
  final String? headingText;
  final double? heading;
  final int? unitIndex;
  final int? themeIndex;
  final double? overlayWidth;
  final double? overlayHeight;

  const OverlayMessage({
    required this.action,
    this.speedText,
    this.unitText,
    this.headingText,
    this.heading,
    this.unitIndex,
    this.themeIndex,
    this.overlayWidth,
    this.overlayHeight,
  });

  /// Factory constructor for display update messages
  factory OverlayMessage.updateDisplay({
    required String speedText,
    required String unitText,
    required String headingText,
    required double heading,
    required int unitIndex,
    required int themeIndex,
    double? overlayWidth,
    double? overlayHeight,
  }) {
    return OverlayMessage(
      action: 'updateDisplay',
      speedText: speedText,
      unitText: unitText,
      headingText: headingText,
      heading: heading,
      unitIndex: unitIndex,
      themeIndex: themeIndex,
      overlayWidth: overlayWidth,
      overlayHeight: overlayHeight,
    );
  }

  /// Factory constructor for long press close signal
  factory OverlayMessage.longPressClose() {
    return const OverlayMessage(action: 'longPressClose');
  }

  /// Factory constructor for overlay closed notification
  factory OverlayMessage.overlayClosed() {
    return const OverlayMessage(action: 'overlayClosed');
  }

  /// Serialize to Map for overlay IPC
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'action': action};
    if (speedText != null) map['speedText'] = speedText;
    if (unitText != null) map['unitText'] = unitText;
    if (headingText != null) map['headingText'] = headingText;
    if (heading != null) map['heading'] = heading;
    if (unitIndex != null) map['unitIndex'] = unitIndex;
    if (themeIndex != null) map['themeIndex'] = themeIndex;
    if (overlayWidth != null) map['overlayWidth'] = overlayWidth;
    if (overlayHeight != null) map['overlayHeight'] = overlayHeight;
    return map;
  }

  /// Deserialize from Map received via overlay IPC
  factory OverlayMessage.fromMap(Map<dynamic, dynamic> map) {
    return OverlayMessage(
      action: map['action'] as String? ?? 'unknown',
      speedText: map['speedText'] as String?,
      unitText: map['unitText'] as String?,
      headingText: map['headingText'] as String?,
      heading: (map['heading'] as num?)?.toDouble(),
      unitIndex: map['unitIndex'] as int?,
      themeIndex: map['themeIndex'] as int?,
      overlayWidth: (map['overlayWidth'] as num?)?.toDouble(),
      overlayHeight: (map['overlayHeight'] as num?)?.toDouble(),
    );
  }

  /// Create a copy with updated fields
  OverlayMessage copyWith({
    String? action,
    String? speedText,
    String? unitText,
    String? headingText,
    double? heading,
    int? unitIndex,
    int? themeIndex,
    double? overlayWidth,
    double? overlayHeight,
  }) {
    return OverlayMessage(
      action: action ?? this.action,
      speedText: speedText ?? this.speedText,
      unitText: unitText ?? this.unitText,
      headingText: headingText ?? this.headingText,
      heading: heading ?? this.heading,
      unitIndex: unitIndex ?? this.unitIndex,
      themeIndex: themeIndex ?? this.themeIndex,
      overlayWidth: overlayWidth ?? this.overlayWidth,
      overlayHeight: overlayHeight ?? this.overlayHeight,
    );
  }
}
