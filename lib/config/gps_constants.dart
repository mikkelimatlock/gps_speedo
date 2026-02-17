// GPS behavioral constants — SCREAMING_SNAKE per project convention

/// GPS configuration constants for data validation and timeouts
abstract class GpsConfig {
  /// Time threshold after which GPS data is considered stale
  static const Duration STALE_DATA_THRESHOLD = Duration(seconds: 4);

  /// Timeout for initial GPS fix acquisition (outdoor/cold start)
  static const Duration INITIAL_FIX_TIMEOUT = Duration(seconds: 20);

  /// Timeout for ongoing GPS updates (indoor/signal loss detection)
  static const Duration UPDATE_TIMEOUT = Duration(seconds: 2);

  /// Minimum valid heading value in degrees
  static const double VALID_HEADING_MIN = 0.0;

  /// Maximum valid heading value in degrees
  static const double VALID_HEADING_MAX = 360.0;

  /// Speed threshold below which heading is considered unreliable (m/s)
  static const double LOW_SPEED_THRESHOLD = 1.0;

  /// Speed threshold for switching to HIGH precision (m/s) - 12 km/h
  static const double PRECISION_UP_THRESHOLD_MPS = 3.33;

  /// Speed threshold for switching to BALANCED precision (m/s) - 8 km/h
  static const double PRECISION_DOWN_THRESHOLD_MPS = 2.22;

  /// Minimum time after first fix before precision switching starts
  static const Duration PRECISION_SWITCH_FIRST_FIX_DELAY = Duration(seconds: 5);
}
