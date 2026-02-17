# Technology Stack

**Analysis Date:** 2026-02-09

## Languages

**Primary:**
- Dart 3.9.0+ - Flutter app logic, services, UI widgets
- Kotlin - Android native bridge and plugin implementations
- Swift - iOS native bridge (untested)

**Secondary:**
- XML - Android manifest and resource files
- YAML - Flutter configuration and package management
- XML/Plist - iOS configuration

## Runtime

**Environment:**
- Flutter 3.24.0+ (SDK)
- Android Runtime (API 21+, configured via Gradle)
- iOS Runtime (optional, iOS 12.0+)

**Package Manager:**
- Pub (Dart package manager)
- Lockfile: `pubspec.lock` (present)
- Direct dependencies resolved from `pub.dev`

## Frameworks

**Core:**
- Flutter 0.0.0 - UI framework and cross-platform mobile development
- Material Design 3 - Flutter Material Design components with `useMaterial3: true`

**Testing:**
- Flutter Test SDK - Unit and widget testing framework (included in Flutter SDK)
- flutter_lints 6.0.0 - Linting rules for code quality

**Build/Dev:**
- flutter_launcher_icons 0.14.4 - Icon generation for Android and iOS
- Gradle (Kotlin DSL) - Android build system configured in `android/app/build.gradle.kts`

## Key Dependencies

**Critical:**
- geolocator 14.0.2 - GPS positioning and real-time location streaming with heading/speed data
  - Platform-specific implementations: geolocator_android, geolocator_apple, geolocator_linux, geolocator_web, geolocator_windows
  - Transitive: geolocator_platform_interface 4.2.6
- permission_handler 12.0.1 - Runtime permissions management (location, overlay window)
  - Platform-specific: permission_handler_android, permission_handler_apple, permission_handler_windows, permission_handler_html

**Infrastructure:**
- wakelock_plus 1.3.2 - Keeps device screen/CPU awake during GPS tracking
  - Transitive: wakelock_plus_platform_interface 1.2.3
- flutter_overlay_window 0.5.0 - System-level floating window overlay for GPS data display
  - Core overlay service: `flutter.overlay.window.flutter_overlay_window.OverlayService`
- bg_launcher 0.1.0 - Brings app to foreground from background or overlay state

**Utilities:**
- http 1.5.0 (transitive) - HTTP client library (included as dependency of other packages)
- package_info_plus 8.3.1 (transitive) - App version and package info
- uuid 4.5.1 (transitive) - UUID generation for identifiers
- meta 1.16.0 (transitive) - Dart language annotations

**Development Utilities:**
- archive 4.0.7 - For launcher icon generation
- image 4.5.4 - Image processing for icons
- json_annotation 4.9.0 - JSON serialization support

## Configuration

**Environment:**
- No `.env` files or environment variable configuration detected
- Configuration is hardcoded in Dart code and managed through SharedPreferences during runtime
- Key runtime settings:
  - Speed units (km/h, mph, knots) stored in app state
  - Theme selection (dark/light) managed in state
  - Location service permissions checked at runtime

**Build:**
- Android build configuration: `android/app/build.gradle.kts`
  - Namespace: `com.novoyuuparosk.speedo`
  - Min SDK: Flutter default
  - Target SDK: Flutter default
  - Source/Target Compatibility: Java 11
  - JVM Target: Java 11 (Kotlin)
- iOS build configuration: `ios/Runner/Info.plist`
  - Bundle ID: `$(PRODUCT_BUNDLE_IDENTIFIER)`
  - Supported orientations: Portrait, Landscape (Left/Right), Portrait Upside Down (iPad)

**Icon Configuration:**
- flutter_launcher_icons configuration in pubspec.yaml
  - Source image: `icon/speedo.png`
  - Generates both Android and iOS icons with adaptive icon support
  - Adaptive foreground: `icon/speedo.png`

**Fonts:**
- Custom font: DIN1451Alt
  - Asset file: `fonts/din1451alt.ttf`
  - Used for speedometer display typography

## Platform Requirements

**Development:**
- Flutter SDK 3.24.0 or later
- Dart 3.9.0 or later
- Android development environment with Gradle
- Kotlin compiler (for Android native code)
- Physical Android device or emulator with GPS simulation (recommended: physical device for accurate GPS)

**Production:**
- Android 5.0+ (API 21+) for primary platform
- iOS 12.0+ (secondary/untested platform)
- Foreground service capability (Android 12+)
- System alert window permission (for overlay functionality)
- Location services enabled on device
- Screen wake lock capability for continuous monitoring

**Permissions & Capabilities:**
- Runtime permissions:
  - `ACCESS_FINE_LOCATION` - High-precision GPS
  - `ACCESS_COARSE_LOCATION` - Network-based location fallback
  - `ACCESS_BACKGROUND_LOCATION` - Background location access (optional)
  - `SYSTEM_ALERT_WINDOW` - Floating overlay window
  - `FOREGROUND_SERVICE` - Background service requirement
  - `FOREGROUND_SERVICE_SPECIAL_USE` - Overlay service special use
  - `WAKE_LOCK` - Keep device awake
  - `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` - Battery optimization bypass

---

*Stack analysis: 2026-02-09*
