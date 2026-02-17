import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:retry/retry.dart';
import 'logger.dart';

/// Service wrapper for FlutterOverlayWindow platform calls with retry logic
/// Encapsulates all overlay operations with error handling and verification
class OverlayService {
  /// Retry configuration for platform operations
  static final RetryOptions _retryOptions = RetryOptions(
    maxAttempts: 3,
    delayFactor: const Duration(milliseconds: 200),
  );

  /// Show overlay window with retry logic and verification
  /// Returns true if overlay successfully opened and verified active
  Future<bool> showOverlay({
    required int width,
    required int height,
  }) async {
    try {
      await _retryOptions.retry(
        () async {
          await FlutterOverlayWindow.showOverlay(
            enableDrag: true,
            overlayTitle: "Speedometer",
            overlayContent: 'Speedo overlay active',
            flag: OverlayFlag.defaultFlag,
            visibility: NotificationVisibility.visibilityPublic,
            positionGravity: PositionGravity.none,
            width: width,
            height: height,
          );
        },
      );

      // Verify overlay actually opened
      final isActive = await FlutterOverlayWindow.isActive();
      if (!isActive) {
        Logger.error('Overlay showOverlay succeeded but isActive returned false', 'OverlayService');
        return false;
      }

      return true;
    } catch (e) {
      Logger.error('Failed to show overlay after retries: $e', 'OverlayService');
      return false;
    }
  }

  /// Close overlay window with retry logic
  /// Returns true on success, false on failure after retries
  Future<bool> closeOverlay() async {
    try {
      await _retryOptions.retry(
        () async {
          await FlutterOverlayWindow.closeOverlay();
        },
      );
      return true;
    } catch (e) {
      Logger.error('Failed to close overlay after retries: $e', 'OverlayService');
      return false;
    }
  }

  /// Share data with overlay window (fire-and-forget)
  /// Does NOT retry - data loss is expected and handled by staleness detection
  Future<void> shareData(Map<String, dynamic> data) async {
    try {
      await FlutterOverlayWindow.shareData(data);
    } catch (e) {
      Logger.warn('Failed to share data with overlay: $e', 'OverlayService');
    }
  }

  /// Check if overlay window is currently active
  /// Returns false on error
  Future<bool> isActive() async {
    try {
      return await FlutterOverlayWindow.isActive();
    } catch (e) {
      Logger.error('Failed to check overlay active status: $e', 'OverlayService');
      return false;
    }
  }

  /// Stream of messages from overlay window
  /// Direct delegation to platform channel
  Stream<dynamic> get overlayListener => FlutterOverlayWindow.overlayListener;

  /// Check if system alert window permission is granted
  Future<bool> checkPermission() async {
    return await Permission.systemAlertWindow.isGranted;
  }
}
