# Technology Stack: Flutter GPS Speedometer Restructure

**Project:** GPS Speedometer App Modularization
**Researched:** 2026-02-09
**Milestone Context:** Restructuring existing monolithic app into modular architecture with Provider state management and Android GPS/overlay improvements

---

## Core Principle: No New Major Dependencies

This restructure focuses on leveraging existing dependencies properly rather than introducing new packages. The stack remains deliberately minimal.

---

## Recommended Stack

### Core Framework
| Technology | Version | Purpose | Rationale |
|------------|---------|---------|-----------|
| Flutter SDK | 3.24+ | Cross-platform framework | Current stable, Material 3 support |
| Dart SDK | 3.9+ | Programming language | Already in pubspec, async/null safety features |

**Confidence:** HIGH (Existing project versions)

### State Management
| Technology | Version | Purpose | Rationale |
|------------|---------|---------|-----------|
| **Provider** | 6.1.x | UI state management | Already in dependencies but unused. Official Flutter recommendation for simple-to-moderate state. Mature, well-documented, low boilerplate. Adequate for GPS data streaming + UI preferences. |

**Why Provider over alternatives:**
- **NOT Riverpod:** While Riverpod 3.0 is the 2026 community favorite and fixes Provider's BuildContext limitations, migration adds scope creep. Provider is sufficient for this app's complexity.
- **NOT BLoC:** Overkill for a single-screen app with straightforward GPS data flow.
- **NOT setState alone:** Current 1,075-line monolithic main.dart proves setState doesn't scale.

**Confidence:** HIGH (Based on [Flutter official docs](https://docs.flutter.dev/data-and-backend/state-mgmt/simple) and [2026 state management surveys](https://foresightmobile.com/blog/best-flutter-state-management))

### Location Services
| Technology | Version | Purpose | Rationale |
|------------|---------|---------|-----------|
| geolocator | 14.0.2 | GPS position stream | Already integrated. Supports LocationSettings for adaptive precision control. Android 14+ compatible with FOREGROUND_SERVICE_LOCATION. |
| permission_handler | 12.0.1 | Runtime permissions | Already integrated. Handles Android location permission flows. |

**Key API Pattern for Adaptive GPS Precision:**

```dart
// Speed-adaptive GPS configuration
LocationSettings _getAdaptiveLocationSettings(double currentSpeed) {
  // Use HIGH_ACCURACY above ~10 km/h, BALANCED below with hysteresis
  final bool useHighAccuracy = currentSpeed > 3.0; // ~10.8 km/h threshold

  return AndroidSettings(
    accuracy: useHighAccuracy
        ? LocationAccuracy.high         // PRIORITY_HIGH_ACCURACY (0-100m)
        : LocationAccuracy.medium,      // PRIORITY_BALANCED_POWER_ACCURACY (~100m)
    intervalDuration: Duration(seconds: 1),
    distanceFilter: useHighAccuracy ? 0 : 5, // Filter noise when slow
    foregroundNotificationConfig: ForegroundNotificationConfig(
      notificationText: "GPS Speedometer is tracking your location",
      notificationTitle: "GPS Active",
      enableWakeLock: true,
    ),
  );
}
```

**LocationAccuracy → Android Priority Mapping:**
| Flutter Enum | Android Native | Accuracy | Power | Use Case |
|--------------|----------------|----------|-------|----------|
| `LocationAccuracy.bestForNavigation` | `PRIORITY_HIGH_ACCURACY` | 0-100m | HIGH | Real-time driving (your HIGH state) |
| `LocationAccuracy.high` | `PRIORITY_HIGH_ACCURACY` | 0-100m | HIGH | Real-time driving (your HIGH state) |
| `LocationAccuracy.medium` | `PRIORITY_BALANCED_POWER_ACCURACY` | ~100m | MEDIUM | Low-speed / stationary (your BALANCED state) |
| `LocationAccuracy.low` | `PRIORITY_LOW_POWER` | 100-500m | LOW | Background tracking (not needed) |
| `LocationAccuracy.lowest` | `PRIORITY_PASSIVE` | 500m+ | MINIMAL | Piggyback only (not needed) |

**Important:** Use `AndroidSettings.intervalDuration` to control update frequency. The deprecated `getCurrentPosition()` parameters (`desiredAccuracy`, `timeLimit`) were replaced with `LocationSettings` in geolocator 6.0+.

**Confidence:** HIGH (Official [geolocator docs](https://pub.dev/packages/geolocator) and [Android LocationRequest API](https://developer.android.com/develop/sensors-and-location/location/request-updates))

### Android Overlay Window
| Technology | Version | Purpose | Rationale | Status |
|------------|---------|---------|-----------|--------|
| flutter_overlay_window | 0.5.0 | System-level overlay | Already integrated. **Known reliability issues:** bidirectional communication unstable, overlay positioning poor, performance impact on main app. | PROBLEMATIC |

**Critical Finding: Overlay Communication is Fundamentally Flawed**

The existing `flutter_overlay_window` implementation has documented reliability problems:

1. **Data Sync Issues:** [GitHub issue #115](https://github.com/X-SLAYER/flutter_overlay_window/issues/115) documents "can't display my data on the overlay window" - matches project's "seriously buggy" assessment.
2. **Hardware Rendering Glitches:** Flutter 3.27+ causes graphic glitches with overlays on Samsung devices, requiring "Disable HW Overlays" workaround.
3. **Android Version Inconsistency:** Android 11+ shows notification bubbles instead of overlays on some configurations.

**Recommended Strategy: Isolate and Stabilize, Not Replace**

**WHY NOT switch packages:**
- **system_alert_window:** Same underlying Android limitations, different API. No reliability gain.
- **flutter_overlay_window_plus:** "Improved API" but no evidence of fixing fundamental IPC issues.
- **Native Android implementation:** Massive scope creep, requires platform channel expertise.

**INSTEAD: Architectural Isolation Pattern**

```
Main App (Foreground)
  ├── GPS Hardware ← Single source of truth
  ├── GpsDataManager (Singleton) ← Processes data
  ├── UI Widgets (Consumer) ← Display main UI
  └── Overlay Messaging (Fire-and-forget) ← One-way updates only

Overlay Window (Background isolate)
  ├── Receives messages via FlutterOverlayWindow.overlayListener
  ├── Displays last-received GPS data (read-only)
  └── Close button → Sends termination signal
```

**Key Pattern: One-Way Data Flow with Defensive Fallbacks**

```dart
// In main app: Fire-and-forget messaging
void _sendGpsDataToOverlay(ProcessedGpsData data) {
  if (_isOverlayActive) {
    try {
      FlutterOverlayWindow.shareData({
        'speed': data.displaySpeed,
        'unit': _currentUnit.symbol,
        'heading': data.displayHeading,
      });
    } catch (e) {
      // Fail silently - overlay updates are nice-to-have
      debugPrint('Overlay message failed: $e');
    }
  }
}

// In overlay: Defensive data handling
@override
Widget build(BuildContext context) {
  return StreamBuilder<dynamic>(
    stream: FlutterOverlayWindow.overlayListener,
    initialData: {'speed': '--', 'unit': 'km/h', 'heading': 'N/A'},
    builder: (context, snapshot) {
      final data = snapshot.data ?? {};
      return Text('${data['speed'] ?? '--'} ${data['unit'] ?? ''}');
    },
  );
}
```

**What NOT to do:**
- ❌ Bidirectional communication (overlay → main app requests)
- ❌ Shared mutable state between isolates
- ❌ Complex UI in overlay (keep it minimal: speed + close button)
- ❌ Rely on overlay for critical functionality

**Confidence:** MEDIUM (Based on [GitHub issues](https://github.com/X-SLAYER/flutter_overlay_window/issues) and [pub.dev package page](https://pub.dev/packages/flutter_overlay_window))

### Power Management
| Technology | Version | Purpose | Rationale |
|------------|---------|---------|-----------|
| wakelock_plus | 1.2.8 | Keep screen on | Already integrated. Prevents screen sleep during active navigation. |

**Power Optimization Pattern for Mixed-Use (Car + Battery):**

```dart
// Conditional GPS tracking based on overlay visibility
void _handleOverlayStateChange(bool overlayVisible) {
  if (overlayVisible) {
    // Start background GPS with BALANCED accuracy
    _gpsManager.startBackgroundTracking(LocationAccuracy.medium);
    WakelockPlus.enable(); // Prevent sleep
  } else {
    // Stop GPS when overlay hidden + app backgrounded
    if (_appLifecycleState == AppLifecycleState.paused) {
      _gpsManager.stopTracking();
      WakelockPlus.disable();
    }
  }
}
```

**Android GPS Power Best Practices:**
1. **Use FusedLocationProvider:** Intelligently combines GPS, Wi-Fi, cell towers. geolocator uses this by default.
2. **Maximize intervalDuration:** Pass largest possible interval value for foreground use cases (1-2 seconds acceptable).
3. **Batch updates:** Use `AndroidSettings.maxUpdateDelayMillis()` to batch multiple location updates (delay 3-5x the interval).
4. **Switch to BALANCED_POWER_ACCURACY when stationary:** Reserve HIGH_ACCURACY for movement.
5. **Stop updates when unnecessary:** Remove location listeners in `onPause()`, restore in `onResume()`.

**Why this matters for GPS speedometer:**
- Car use: Plugged in, no battery concern → HIGH_ACCURACY always acceptable
- Battery cycling (parking → driving): Must stop GPS when parked, restart on movement
- Overlay visible = user expects real-time data = justify GPS power drain

**Confidence:** HIGH (Based on [Android battery optimization docs](https://developer.android.com/develop/sensors-and-location/location/battery) and [Google Maps SDK power guide](https://developers.google.com/maps/documentation/navigation/android-sdk/optimize-power))

---

## Architecture Stack

### Recommended Pattern: MVVM (Simplified)

**Based on [Flutter official architecture guide](https://docs.flutter.dev/app-architecture/guide):**

```
UI Layer:
  ├── Views (Widgets) ← Minimal logic, display only
  └── View Models (ChangeNotifier) ← UI state + user interaction commands

Data Layer:
  ├── Repositories ← Data source of truth (GPS, settings)
  └── Services ← External API wrappers (Geolocator, SharedPreferences)
```

**No Domain Layer Needed:** Use-cases/interactors are overkill for single-screen GPS app. Only add domain layer if merging multiple complex repositories.

**Component Boundaries:**

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **SpeedometerScreen** (View) | Widget tree, user input handling | SpeedometerViewModel only |
| **SpeedometerViewModel** (ChangeNotifier) | UI state (theme, unit, display mode), user commands | GpsRepository, SettingsRepository |
| **GpsRepository** | GPS data stream, speed/heading processing | GpsService, ProcessedGpsData model |
| **SettingsRepository** | Persistent settings (theme, unit) | SettingsService (SharedPreferences) |
| **GpsService** | Geolocator API wrapper, permission handling | Android GPS hardware |
| **OverlayMessenger** (Optional service) | One-way data to overlay isolate | flutter_overlay_window |

**Critical: Existing GpsDataManager Must Be Refactored**

Current implementation mixes responsibilities:
- ✅ **Correct:** Singleton pattern, broadcast stream, stale data detection
- ❌ **Wrong:** Directly processes UI display logic (`displaySpeed`, `displayHeading`)
- ❌ **Wrong:** Hardcoded m/s → display conversion (should be repository concern)

**Refactor Strategy:**

```dart
// BEFORE (Current GpsDataManager) - Service with UI logic
class GpsDataManager {
  ProcessedGpsData _currentData; // Contains displaySpeed, displayHeading
  String getFormattedSpeed(SpeedUnit unit) { /* UI formatting */ }
}

// AFTER (Clean Architecture)
// 1. GpsService (Pure data layer) - Just wraps Geolocator
class GpsService {
  Stream<Position> get positionStream => Geolocator.getPositionStream(...);
  static Future<bool> requestPermissions() => ...;
}

// 2. GpsRepository (Data processing) - Converts Position → domain model
class GpsRepository {
  Stream<GpsData> get dataStream => _gpsService.positionStream
      .map((position) => GpsData(
            speedMps: position.speed,
            headingDegrees: position.heading,
            isValid: position.speed.isFinite,
          ));
}

// 3. SpeedometerViewModel (UI logic) - Formats for display
class SpeedometerViewModel extends ChangeNotifier {
  String get displaySpeed {
    final data = _gpsRepository.currentData;
    if (!data.isValid || data.speedMps < 0.3) return '--';
    return _currentUnit.convert(data.speedMps).toStringAsFixed(1);
  }
}
```

**Confidence:** HIGH (Official Flutter architecture guide)

---

## Directory Structure: Layer-First (Recommended for This Project)

**Feature-first vs Layer-first decision:**

| Approach | Best For | This Project? |
|----------|----------|---------------|
| **Feature-first** | Multi-feature apps (e.g., e-commerce: cart, checkout, profile) | ❌ No - Single-screen GPS app |
| **Layer-first** | Apps with few features but complex layers | ✅ Yes - One feature, multiple concerns (GPS, overlay, settings) |

**Recommended Structure:**

```
lib/
├── main.dart                    # App entry point + overlay entry point
├── screens/                     # UI Layer - Views only
│   ├── speedometer_screen.dart  # Main screen widget tree
│   └── overlay_screen.dart      # Overlay isolate UI (if separated)
├── viewmodels/                  # UI Layer - View models (ChangeNotifier)
│   └── speedometer_viewmodel.dart
├── widgets/                     # Reusable UI components
│   ├── speed_display.dart       # Digital display widget
│   ├── gauge_widget.dart        # Analog gauge widget
│   └── metrics_panel.dart       # Optional metrics display
├── repositories/                # Data Layer - Data processing
│   ├── gps_repository.dart      # GPS data stream + processing
│   └── settings_repository.dart # Persistent settings (theme, unit)
├── services/                    # Data Layer - External API wrappers
│   ├── gps_service.dart         # Geolocator wrapper
│   ├── settings_service.dart    # SharedPreferences wrapper
│   └── overlay_messenger.dart   # One-way overlay communication (optional)
├── models/                      # Data models (pure data classes)
│   ├── gps_data.dart            # Domain model for GPS data
│   └── app_settings.dart        # Domain model for settings
├── utils/                       # Pure functions, constants
│   ├── speed_units.dart         # SpeedUnit enum + conversion logic
│   └── color_themes.dart        # Theme definitions
└── constants/                   # App-wide constants
    └── app_constants.dart       # Timeouts, thresholds, etc.
```

**Migration Path from Current Monolith:**

1. **Phase 1:** Extract models (`gps_data.dart`, `app_settings.dart`)
2. **Phase 2:** Create services (wrap existing `GpsService`, create `SettingsService`)
3. **Phase 3:** Create repositories (move business logic from `GpsDataManager`)
4. **Phase 4:** Create viewmodel (extract state from `_SpeedometerScreenState`)
5. **Phase 5:** Refactor screen to pure widget (remove setState, use Consumer)

**What NOT to do:**
- ❌ Create `helpers/` or `utils/` catch-all folders for business logic
- ❌ Mix UI and business logic in viewmodels
- ❌ Put repositories in `providers/` folder (use `repositories/`)
- ❌ Create deep feature hierarchies (`features/speedometer/screens/main/widgets/...`)

**Confidence:** HIGH (Based on [Flutter project structure guide](https://codewithandrea.com/articles/flutter-project-structure/) and [official architecture docs](https://docs.flutter.dev/app-architecture/guide))

---

## Provider Patterns: Performance Best Practices

### ChangeNotifier Usage

**Core Pattern:**

```dart
class SpeedometerViewModel extends ChangeNotifier {
  final GpsRepository _gpsRepository;
  final SettingsRepository _settingsRepository;
  StreamSubscription<GpsData>? _gpsSubscription;

  SpeedometerViewModel(this._gpsRepository, this._settingsRepository) {
    _gpsSubscription = _gpsRepository.dataStream.listen(_onGpsUpdate);
    _loadSettings();
  }

  void _onGpsUpdate(GpsData data) {
    // Update internal state
    _currentGpsData = data;
    notifyListeners(); // Trigger UI rebuild
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    super.dispose();
  }
}
```

**Critical Performance Rules:**

1. **Place Consumer deep in widget tree:**
   ```dart
   // ❌ BAD - Rebuilds entire screen
   return Consumer<SpeedometerViewModel>(
     builder: (context, vm, child) => Scaffold(...),
   );

   // ✅ GOOD - Rebuilds only speed text
   return Scaffold(
     body: Column(
       children: [
         StaticHeader(),
         Consumer<SpeedometerViewModel>(
           builder: (context, vm, child) => Text(vm.displaySpeed),
         ),
       ],
     ),
   );
   ```

2. **Use `listen: false` when not subscribing:**
   ```dart
   // ✅ In event handlers (button presses)
   void _onThemeButtonPressed() {
     final vm = Provider.of<SpeedometerViewModel>(context, listen: false);
     vm.nextTheme(); // Just calling a command, not listening to changes
   }

   // Or use context.read (same thing)
   void _onThemeButtonPressed() {
     context.read<SpeedometerViewModel>().nextTheme();
   }
   ```

3. **Use `child` parameter for static subtrees:**
   ```dart
   Consumer<SpeedometerViewModel>(
     child: ExpensiveStaticWidget(), // Built once, passed to builder
     builder: (context, vm, staticChild) => Column(
       children: [
         Text(vm.displaySpeed), // Rebuilds
         staticChild!,          // Never rebuilds
       ],
     ),
   );
   ```

4. **Use Selector for granular rebuilds:**
   ```dart
   // Only rebuilds when displaySpeed changes, not on theme/unit changes
   Selector<SpeedometerViewModel, String>(
     selector: (context, vm) => vm.displaySpeed,
     builder: (context, displaySpeed, child) => Text(displaySpeed),
   );
   ```

5. **Always call `notifyListeners()` after state changes:**
   ```dart
   void setUnit(SpeedUnit unit) {
     _currentUnit = unit;
     notifyListeners(); // Critical - UI won't update without this
   }
   ```

6. **NEVER use `context.read()` inside build():**
   ```dart
   // ❌ BAD - Won't rebuild on changes
   @override
   Widget build(BuildContext context) {
     final vm = context.read<SpeedometerViewModel>();
     return Text(vm.displaySpeed); // Stale data!
   }

   // ✅ GOOD - Subscribes to changes
   @override
   Widget build(BuildContext context) {
     final vm = context.watch<SpeedometerViewModel>();
     return Text(vm.displaySpeed);
   }
   ```

**Provider Setup in main.dart:**

```dart
void main() {
  runApp(
    MultiProvider(
      providers: [
        // Services (no state, just API wrappers)
        Provider(create: (_) => GpsService()),
        Provider(create: (_) => SettingsService()),

        // Repositories (depend on services)
        ProxyProvider<GpsService, GpsRepository>(
          update: (_, gpsService, __) => GpsRepository(gpsService),
        ),
        ProxyProvider<SettingsService, SettingsRepository>(
          update: (_, settingsService, __) => SettingsRepository(settingsService),
        ),

        // ViewModels (depend on repositories)
        ChangeNotifierProxyProvider2<GpsRepository, SettingsRepository, SpeedometerViewModel>(
          create: (_) => SpeedometerViewModel(
            Provider.of<GpsRepository>(_, listen: false),
            Provider.of<SettingsRepository>(_, listen: false),
          ),
          update: (_, gpsRepo, settingsRepo, vm) =>
              vm ?? SpeedometerViewModel(gpsRepo, settingsRepo),
        ),
      ],
      child: const SpeedoApp(),
    ),
  );
}
```

**Confidence:** HIGH (Based on [official Flutter Provider docs](https://docs.flutter.dev/data-and-backend/state-mgmt/simple) and [Provider performance guide](https://www.dhiwise.com/post/achieving-optimal-performance-with-flutter-provider-state-management))

---

## Installation & Dependency Changes

**No new packages needed.** All dependencies already in pubspec.yaml.

### Current Dependencies (Keep As-Is)
```yaml
dependencies:
  flutter:
    sdk: flutter
  geolocator: ^14.0.2          # Already integrated
  permission_handler: ^12.0.1   # Already integrated
  wakelock_plus: ^1.2.8         # Already integrated
  flutter_overlay_window: ^0.5.0 # Already integrated (problematic but keep)
  bg_launcher: ^0.1.0           # Already integrated
  # provider: ^6.1.x            # MISSING - Add this line
```

### Required Addition
```bash
flutter pub add provider
```

### Dev Dependencies (Keep As-Is)
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  flutter_launcher_icons: "^0.14.4"
```

**What NOT to add:**
- ❌ Riverpod (scope creep, Provider is sufficient)
- ❌ get_it (dependency injection - Provider handles this)
- ❌ freezed (immutable models - overkill for simple data classes)
- ❌ Alternative overlay packages (same limitations as current)

---

## Anti-Patterns: What NOT to Do

### 1. Don't Over-Abstract
```dart
// ❌ BAD - Premature abstraction
abstract class LocationDataSource {
  Stream<Position> getPositionStream();
}
class GeolocatorDataSource implements LocationDataSource { ... }

// ✅ GOOD - Direct service wrapper
class GpsService {
  Stream<Position> get positionStream => Geolocator.getPositionStream(...);
}
```

**Why:** You're not swapping out Geolocator. YAGNI principle applies.

### 2. Don't Mix UI Logic in Repositories
```dart
// ❌ BAD - Repository formats for UI
class GpsRepository {
  String get displaySpeed => _formatForUi(_currentSpeed);
}

// ✅ GOOD - Repository provides domain data
class GpsRepository {
  double get speedMps => _currentSpeed;
}
class SpeedometerViewModel {
  String get displaySpeed => _formatForUi(_gpsRepository.speedMps);
}
```

**Why:** Repositories are reusable across features. UI formatting is view-specific.

### 3. Don't Create God ViewModels
```dart
// ❌ BAD - Single viewmodel manages everything
class AppViewModel extends ChangeNotifier {
  GpsData gpsData;
  AppSettings settings;
  bool isOverlayActive;
  // ... 50 more properties
}

// ✅ GOOD - Separate concerns
class SpeedometerViewModel extends ChangeNotifier { /* GPS + UI state */ }
class SettingsViewModel extends ChangeNotifier { /* Settings only */ }
```

**Why:** For single-screen app, one viewmodel is OK. But separate GPS from settings concerns.

### 4. Don't Use Dynamic Accuracy Switching Without Hysteresis
```dart
// ❌ BAD - Constantly switches accuracy as speed fluctuates
LocationSettings _getSettings(double speed) {
  return AndroidSettings(
    accuracy: speed > 3.0
        ? LocationAccuracy.high    // 10.8 km/h
        : LocationAccuracy.medium,
  );
}

// ✅ GOOD - Hysteresis prevents thrashing
LocationSettings _getSettings(double speed, bool currentlyHighAccuracy) {
  final threshold = currentlyHighAccuracy ? 2.5 : 3.5; // 9-12.6 km/h range
  return AndroidSettings(
    accuracy: speed > threshold
        ? LocationAccuracy.high
        : LocationAccuracy.medium,
  );
}
```

**Why:** GPS speed fluctuates ±0.5 m/s. Without hysteresis, you'll rapidly switch accuracy modes, wasting battery and causing UI jank.

### 5. Don't Rely on Overlay for Critical Features
```dart
// ❌ BAD - Overlay failure breaks app
void _sendGpsUpdate(GpsData data) {
  if (_isOverlayActive) {
    FlutterOverlayWindow.shareData(data.toJson()); // May throw
  } else {
    throw Exception('Overlay not active!'); // App crashes
  }
}

// ✅ GOOD - Overlay is optional enhancement
void _sendGpsUpdate(GpsData data) {
  if (_isOverlayActive) {
    try {
      FlutterOverlayWindow.shareData(data.toJson());
    } catch (e) {
      debugPrint('Overlay update failed, continuing: $e');
    }
  }
  // Main app always works, overlay is bonus
}
```

**Why:** Overlay communication is unreliable. Main app must function perfectly without it.

---

## Testing Strategy

### Unit Test Priorities

1. **Speed unit conversions** (`speed_units.dart`) - Pure functions, easy to test
2. **GPS data processing** (`GpsRepository`) - Mock Position stream
3. **Settings persistence** (`SettingsRepository`) - Mock SharedPreferences
4. **ViewModel commands** (`SpeedometerViewModel`) - Mock repositories

### Widget Test Priorities

1. **Speed display updates** - Verify Consumer rebuilds on GPS changes
2. **Theme switching** - Verify UI updates on theme change
3. **Unit switching** - Verify speed conversion displayed correctly

### Integration Test Priorities

1. **GPS permission flow** - Verify permission request → GPS stream start
2. **Overlay launch/close** - Verify overlay lifecycle doesn't crash main app

**What NOT to test:**
- ❌ Geolocator library internals (trust the library)
- ❌ Overlay message delivery (too unreliable, mock it)
- ❌ Android system behaviors (permission dialogs, etc.)

---

## Sources

### Official Documentation
- [Flutter App Architecture Guide](https://docs.flutter.dev/app-architecture/guide) - MVVM, layer separation
- [Flutter State Management: Simple (Provider)](https://docs.flutter.dev/data-and-backend/state-mgmt/simple) - Official Provider guidance
- [Geolocator Flutter Package](https://pub.dev/packages/geolocator) - GPS API documentation
- [Android Location Request Updates](https://developer.android.com/develop/sensors-and-location/location/request-updates) - Native Android GPS API
- [Android Location Battery Optimization](https://developer.android.com/develop/sensors-and-location/location/battery) - Power consumption best practices

### Community Resources
- [Flutter Project Structure: Feature-first or Layer-first?](https://codewithandrea.com/articles/flutter-project-structure/) - Directory structure guidance
- [Best Flutter State Management Libraries 2026](https://foresightmobile.com/blog/best-flutter-state-management) - Provider vs Riverpod comparison
- [Flutter Provider State Management for Optimal Performance](https://www.dhiwise.com/post/achieving-optimal-performance-with-flutter-provider-state-management) - Performance patterns

### Package Documentation
- [flutter_overlay_window pub.dev](https://pub.dev/packages/flutter_overlay_window) - Overlay API reference
- [flutter_overlay_window GitHub Issues](https://github.com/X-SLAYER/flutter_overlay_window/issues) - Known reliability problems
- [LocationAccuracy enum API](https://pub.dev/documentation/geolocator_platform_interface/latest/geolocator_platform_interface/LocationAccuracy.html) - Android mapping table

### Architecture References
- [Architecture recommendations and resources](https://docs.flutter.dev/app-architecture/recommendations) - Flutter team's architectural guidance
- [Common architecture concepts](https://docs.flutter.dev/app-architecture/concepts) - Layer definitions

---

## Confidence Assessment

| Area | Confidence | Rationale |
|------|------------|-----------|
| **Provider patterns** | HIGH | Official Flutter docs, mature package (6.1.x), well-documented |
| **MVVM architecture** | HIGH | Official Flutter architecture guide 2026 |
| **Geolocator adaptive GPS** | HIGH | Official Android docs + geolocator 14.0.2 API verified |
| **Android power optimization** | HIGH | Official Android developer docs for 2026 |
| **Overlay reliability** | MEDIUM | GitHub issues + community reports confirm problems, but no authoritative solution found |
| **Directory structure** | HIGH | Layer-first appropriate for single-screen app per community best practices |

---

## Open Questions / Phase-Specific Research Needed

1. **Overlay Performance Impact:** Quantify actual battery/CPU impact of running overlay isolate on various Android versions. May need device-specific testing.

2. **GPS Accuracy Hysteresis Tuning:** Optimal speed thresholds for HIGH ↔ BALANCED transitions depend on real-world testing. Starting recommendation: 2.5-3.5 m/s (~9-12.6 km/h) with 1.0 m/s deadband.

3. **Android 14+ Foreground Service Policies:** Verify FOREGROUND_SERVICE_LOCATION permission behavior on Android 14+ devices. May require additional AndroidManifest.xml configuration beyond current setup.

4. **Provider Memory Leaks:** Verify ChangeNotifier disposal in overlay isolate. Isolates don't share memory, so dispose() semantics may differ. Test with DevTools memory profiler.

---

**Next Steps:** Feed this STACK.md into roadmap creation to structure phases around:
1. Provider migration (extract viewmodels)
2. Repository pattern implementation (GpsRepository, SettingsRepository)
3. Adaptive GPS precision (speed-based LocationSettings)
4. Overlay isolation (one-way messaging, defensive error handling)
5. Power optimization (lifecycle-aware GPS control)
