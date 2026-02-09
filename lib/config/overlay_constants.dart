// Overlay sizing and display constants — SCREAMING_SNAKE per project convention

/// Overlay window configuration for proportional sizing and appearance
abstract class OverlayConfig {
  /// Overlay width as percentage of screen width
  static const double WIDTH_PERCENTAGE = 0.45;

  /// Overlay height aspect ratio relative to width
  static const double ASPECT_RATIO = 0.6;

  /// Background color opacity
  static const double BACKGROUND_OPACITY = 0.85;

  /// Border color opacity
  static const double BORDER_OPACITY = 0.3;

  /// Speed text font size as ratio of overlay width
  static const double FONT_SIZE_RATIO = 0.2;

  /// Unit text font size as ratio of speed font size
  static const double UNIT_FONT_RATIO = 0.6;

  /// Navigation icon size as ratio of overlay width
  static const double ICON_SIZE_RATIO = 0.72;

  /// Heading text font size as ratio of speed font size
  static const double HEADING_FONT_RATIO = 0.4;

  /// Default screen width for calculations when actual width unavailable
  static const double DEFAULT_SCREEN_WIDTH = 400.0;

  /// Default overlay width for calculations
  static const double DEFAULT_OVERLAY_WIDTH = 280.0;

  /// Default overlay height for calculations
  static const double DEFAULT_OVERLAY_HEIGHT = 140.0;
}
