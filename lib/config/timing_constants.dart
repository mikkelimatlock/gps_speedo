// Timer and interval constants — SCREAMING_SNAKE per project convention

/// Timing configuration for background tasks and UI interactions
abstract class TimingConfig {
  /// Interval for background heartbeat to keep GPS alive
  static const Duration HEARTBEAT_INTERVAL = Duration(seconds: 5);

  /// Interval for checking overlay window status
  static const Duration OVERLAY_STATUS_CHECK_INTERVAL = Duration(milliseconds: 1000);

  /// Delay before closing overlay after tap
  static const Duration TAP_CLOSE_DELAY = Duration(milliseconds: 500);

  /// Delay for long press gesture signal
  static const Duration LONG_PRESS_SIGNAL_DELAY = Duration(milliseconds: 50);

  /// GPS grace period - continues for 30s after overlay close when backgrounded
  /// DEPRECATED: Replaced by BACKGROUND_GRACE_PERIOD (7s) for lifecycle management
  static const Duration GPS_GRACE_PERIOD = Duration(seconds: 30);

  /// Background grace period - time before GPS stops when app backgrounded without overlay
  static const Duration BACKGROUND_GRACE_PERIOD = Duration(seconds: 7);
}
