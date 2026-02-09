# External Integrations

**Analysis Date:** 2026-02-09

## APIs & External Services

**Location Services:**
- Geolocator API (geolocator 14.0.2)
  - What it's used for: Real-time GPS positioning, speed, heading, and location tracking
  - SDK/Client: `package:geolocator` (Dart wrapper around native location APIs)
  - Implementation: `lib/gps_service.dart` provides stream-based position updates
  - Native integration: Android (geolocator_android 5.0.2), iOS (geolocator_apple 2.3.13), Linux, Web, Windows
  - Stream Configuration: LocationSettings with `LocationAccuracy.bestForNavigation` and `distanceFilter: 0` for continuous GPS updates

**System Overlay:**
- Flutter Overlay Window (flutter_overlay_window 0.5.0)
  - What it's used for: Creates floating window overlay for displaying GPS speed while app is in background
  - Implementation: `lib/main.dart` with `overlayMain()` entry point
  - Service: Android service `flutter.overlay.window.flutter_overlay_window.OverlayService`
  - Requires: `SYSTEM_ALERT_WINDOW` permission and Android API 29+

**App Launcher:**
- bg_launcher 0.1.0
  - What it's used for: Brings main app to foreground from background or overlay state
  - Implementation: Used in `lib/main.dart` for overlay interaction handling

## Data Storage

**Databases:**
- None detected - Application uses client-side state only

**File Storage:**
- SharedPreferences (Android native, not explicitly in pubspec.yaml but referenced in backup version history)
  - Location: Android internal app data directory
  - Used for: Persisting user settings (speed units, theme preferences)
  - Implementation: Handled at runtime through Provider/State management
  - Note: Direct SharedPreferences not found in current active code, settings managed through in-app state

**Caching:**
- In-memory state management via Dart
  - GPS data cached in `lib/services/gps_data_manager.dart` ProcessedGpsData class
  - Heading caching in `lib/gps_service.dart` with `_lastValidHeading` static variable

## Authentication & Identity

**Auth Provider:**
- None - Application is fully offline and requires no user authentication
- Permissions are handled via OS-level runtime permission requests
- Implementation: `lib/gps_service.dart` with `requestPermissions()` using permission_handler

**Permission Management:**
- permission_handler 12.0.1
  - Location permission request: `Permission.locationWhenInUse.request()`
  - Platforms: Android (13.0.1), iOS (9.4.7), Windows (0.2.1), HTML (0.1.3+5)

## Monitoring & Observability

**Error Tracking:**
- None detected - No external error tracking service integrated

**Logs:**
- Console logging via Dart's `print()` function
  - Debug mode conditional logging: `if (kDebugMode)` check in `customDebugPrint()` function
  - Logging in: `lib/main.dart`, `lib/services/gps_data_manager.dart`
  - Format: Prefixed messages with emoji indicators (e.g., '[Overlay] 🚀', '[GpsDataManager] ⚠️')

## CI/CD & Deployment

**Hosting:**
- Not configured - Deployment is manual
- Target: Google Play Store (intended) or sideload APK distribution
- Build output: Flutter generates APK files via `flutter build apk`

**CI Pipeline:**
- None detected - No GitHub Actions, GitLab CI, or other CI/CD configuration present
- Manual build process:
  - `flutter run` for development
  - `flutter build apk` for release builds
  - Signing configured in Gradle (currently uses debug keys for release, see TODO in `android/app/build.gradle.kts`)

## Environment Configuration

**Required env vars:**
- None - Application requires no environment variables
- All configuration is hardcoded or managed through app state at runtime

**Secrets location:**
- None - No API keys, tokens, or secrets integrated
- Android signing keys: Located in Android default keystore (debug only currently)

## Webhooks & Callbacks

**Incoming:**
- None - Application is fully self-contained with no webhook endpoints

**Outgoing:**
- None - No external API calls or webhook notifications
- All data remains local to device

## Native Platform Integrations

**Android:**
- Geolocator Android Plugin (geolocator_android 5.0.2) - FusedLocationProviderClient integration
- Permission Handler Android (permission_handler_android 13.0.1) - Runtime permission requests
- Flutter Overlay Window - System alert window overlay
- Waklock Plus Android integration - CPU/screen wake lock via WakeLock API
- Configured permissions in AndroidManifest.xml:
  - `android.permission.ACCESS_FINE_LOCATION`
  - `android.permission.ACCESS_COARSE_LOCATION`
  - `android.permission.ACCESS_BACKGROUND_LOCATION`
  - `android.permission.SYSTEM_ALERT_WINDOW`
  - `android.permission.FOREGROUND_SERVICE`
  - `android.permission.FOREGROUND_SERVICE_SPECIAL_USE`
  - `android.permission.WAKE_LOCK`
  - `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`

**iOS:**
- Geolocator Apple Plugin (geolocator_apple 2.3.13) - CoreLocation integration
- Permission Handler Apple (permission_handler_apple 9.4.7) - iOS runtime permission handling
- Wakelock Plus (requires iOS implementation)
- Note: iOS functionality is included but untested

## Data Flow & Synchronization

**GPS Data Flow:**
1. Hardware GPS → `geolocator.getPositionStream()` streams Position objects
2. Position objects captured in `lib/services/gps_data_manager.dart`
3. Processed into ProcessedGpsData with speed, heading, and display strings
4. Broadcast via `StreamController<ProcessedGpsData>` for UI consumption
5. Optional: Sent to overlay window via flutter_overlay_window messaging

**Settings Synchronization:**
- Current unit (km/h, mph, knots) synchronized between main app and overlay
- Current theme synchronized between main app and overlay
- Synchronization method: Direct state transmission (not persistent between app restarts)

## External Dependencies Summary

**Direct Dependencies:** 6 packages
- geolocator 14.0.2
- permission_handler 12.0.1
- wakelock_plus 1.3.2 (recently updated to 1.3.2)
- flutter_overlay_window 0.5.0
- bg_launcher 0.1.0
- flutter (SDK)

**Dev Dependencies:** 3 packages
- flutter_test (SDK)
- flutter_lints 6.0.0
- flutter_launcher_icons 0.14.4

**Transitive Dependencies:** 40+ packages (most are Flutter/Dart core utilities)

**No External Cloud Services:**
- No Firebase, Supabase, AWS, or other backend services
- No REST API integrations
- No database synchronization
- No analytics or tracking services
- No third-party payment or subscription services

---

*Integration audit: 2026-02-09*
