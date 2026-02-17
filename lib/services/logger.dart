import 'package:flutter/foundation.dart';

/// Logger utility for standardized debug output with color-coded severity levels.
/// All logging is guarded by kDebugMode and uses debugPrint to avoid truncation.
class Logger {
  // ANSI color codes
  static const String _red = '\x1B[31m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _gray = '\x1B[90m';
  static const String _reset = '\x1B[0m';

  /// Log error-level message (red)
  /// Used for failures, exceptions, critical issues
  static void error(String message, [String? caller]) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toUtc().toIso8601String();
      final callerTag = caller != null ? ' [$caller]' : '';
      debugPrint('$_red[ERROR] $timestamp$callerTag $message$_reset');
    }
  }

  /// Log warning-level message (yellow)
  /// Used for recoverable issues, unexpected states, deprecation warnings
  static void warn(String message, [String? caller]) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toUtc().toIso8601String();
      final callerTag = caller != null ? ' [$caller]' : '';
      debugPrint('$_yellow[WARN] $timestamp$callerTag $message$_reset');
    }
  }

  /// Log info-level message (blue)
  /// Used for lifecycle events, state transitions, user actions
  static void info(String message, [String? caller]) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toUtc().toIso8601String();
      final callerTag = caller != null ? ' [$caller]' : '';
      debugPrint('$_blue[INFO] $timestamp$callerTag $message$_reset');
    }
  }

  /// Log debug-level message (gray)
  /// Used for data flow, detailed state changes, verbose diagnostics
  static void debug(String message, [String? caller]) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toUtc().toIso8601String();
      final callerTag = caller != null ? ' [$caller]' : '';
      debugPrint('$_gray[DEBUG] $timestamp$callerTag $message$_reset');
    }
  }
}
