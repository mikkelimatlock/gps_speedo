# Phase 4: GPS & Power Optimization - Research

**Researched:** 2026-02-12
**Domain:** Flutter GPS lifecycle management, dynamic location accuracy, Android power optimization
**Confidence:** HIGH

## Summary

This phase implements speed-adaptive GPS precision switching and lifecycle-aware power management using Flutter's geolocator package, WidgetsBindingObserver for app state detection, and wakelock_plus for screen wake control. The core pattern involves canceling and recreating GPS position streams with different LocationSettings when speed crosses hysteresis thresholds (8-12 km/h), responding to AppLifecycleState changes for background/foreground transitions, and managing wake locks based on tracking state and overlay visibility.

**Primary recommendation:** Use stream subscription replacement (cancel old, create new with different LocationSettings) for precision switching, WidgetsBindingObserver mixin on GpsDataManager for lifecycle detection, conditional wake lock management tied to both overlay state AND main app foreground state, and extend existing staleness detection from overlay to main screen.

## User Constraints

<user_constraints>
### Locked Decisions (from CONTEXT.md)

**Background transitions:**
- When app backgrounds WITHOUT overlay visible: GPS stops after a short grace period (5-10 seconds), not immediately
- Grace period allows brief app-switching (checking a notification) without losing GPS fix
- When returning to foreground after GPS stopped: show last known speed until fresh data arrives (feels instant, briefly stale)
- When app backgrounds WITH overlay visible: full GPS precision at all times, no power-saving reduction
- User chose overlay = deliberate commitment to battery cost

**Precision change visibility:**
- GPS precision switching (high/balanced) is completely invisible to the user
- No indicators, no UI changes -- speed and heading just work
- Precision transitions logged for debug purposes only
- User-visible surface is speed (with units) and heading (with compass direction) -- nothing else
- Accuracy readout is debug-only territory

**Main app staleness:**
- Apply same staleness detection to main speed display as overlay: 3s dim, 10s dashes, immediate snap-back
- Overlay and main UI are two presentations of the same data -- same staleness rules apply to both
- This is a NEW behavior for the main app (overlay already has it from Phase 3)

**Power priority tradeoffs:**
- Near the speed threshold (8-12 km/h hysteresis zone): favor accuracy over battery
- When in doubt, stay in high precision mode rather than dropping to balanced
- Battery saver mode: respect it partially -- use balanced precision always (skip high mode), but still track
- Foreground GPS: stays on indefinitely while app is visible, no idle timeout. User closes the app when done.
- Wake lock: keep screen awake for BOTH overlay background tracking AND main app when GPS is actively tracking (dashboard use case)
- Wake lock expansion: PWR-05 requirement updated from "overlay only" to "overlay + main app foreground"

### Claude's Discretion

- Timer architecture: whether background grace period (5-10s) reuses Phase 3's existing grace period timer infrastructure or stays separate
- Exact grace period duration within the 5-10s range
- Debug logging format and verbosity for precision transitions
- How staleness detection is shared between main app and overlay (shared utility vs duplicated logic)

### Out of Scope (Deferred Ideas)

None -- discussion stayed within phase scope
</user_constraints>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| geolocator | 14.0.2 | GPS data streams with dynamic accuracy | Official Flutter Community package, used by 17k+ pub.dev projects, wraps Fused Location Provider on Android |
| wakelock_plus | 1.2.8 | Screen wake lock management | Successor to original wakelock, cross-platform, no special permissions required |
| provider | 6.1.2 | State management with ChangeNotifier | Already in use for GpsDataManager, SettingsProvider, OverlayProvider |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| permission_handler | 12.0.1 | Runtime permission requests | Already integrated - no changes needed |
| retry | 3.1.2 | Exponential backoff for platform calls | Already integrated in Phase 3 for overlay operations |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| geolocator | location package | location has 7k+ users but geolocator is more actively maintained (last update Jan 2025 vs Oct 2024) |
| wakelock_plus | screen_state | wakelock is purpose-built for wake control, screen_state is monitoring-focused |
| WidgetsBindingObserver | AppLifecycleListener | AppLifecycleListener is newer (Flutter 3.13+) but WidgetsBindingObserver is more widely documented and stable |

**Installation:**
```bash
# Already installed in pubspec.yaml:
# geolocator: ^14.0.2
# wakelock_plus: ^1.2.8
# No additional dependencies needed
```

## Architecture Patterns

### Recommended State Flow
```
AppLifecycleState Change → GpsDataManager detects via WidgetsBindingObserver
                         ↓
                    Check overlay state (via OverlayProvider reference)
                         ↓
          ┌──────────────┴──────────────┐
          ↓                             ↓
    Overlay Visible?              Overlay Hidden?
          ↓                             ↓
    Full precision GPS          Grace period timer (5-10s)
    Keep wake lock                      ↓
                              Timer expires → Stop GPS, Release wake lock
                                      ↓
                              Foreground resume → Restart GPS, show stale data
```

### Pattern 1: Dynamic GPS Precision Switching

**What:** Cancel and recreate GPS position stream with different LocationSettings when speed crosses hysteresis thresholds

**When to use:** Every GPS update - check current speed against thresholds, switch if crossing boundary

**Example:**
```dart
// Source: Based on geolocator pub.dev official docs and Flutter community patterns
class GpsDataManager extends ChangeNotifier {
  LocationAccuracy _currentAccuracy = LocationAccuracy.high;
  StreamSubscription<Position>? _gpsSubscription;

  void _onPositionUpdate(Position position) {
    final speedMps = position.speed;
    final speedKmh = speedMps * 3.6;

    // Hysteresis: up at 12 km/h, down at 8 km/h
    final targetAccuracy = _determineTargetAccuracy(speedKmh);

    if (targetAccuracy != _currentAccuracy) {
      Logger.debug('Speed ${speedKmh.toStringAsFixed(1)} km/h crossed threshold, switching to $targetAccuracy', 'GpsDataManager');
      _switchPrecision(targetAccuracy);
    }

    // Continue with normal data processing...
  }

  LocationAccuracy _determineTargetAccuracy(double speedKmh) {
    // Favor accuracy: stay high when in doubt
    if (_currentAccuracy == LocationAccuracy.high) {
      return speedKmh < 8.0 ? LocationAccuracy.medium : LocationAccuracy.high;
    } else {
      return speedKmh > 12.0 ? LocationAccuracy.high : LocationAccuracy.medium;
    }
  }

  void _switchPrecision(LocationAccuracy newAccuracy) {
    _currentAccuracy = newAccuracy;

    // Cancel existing subscription
    _gpsSubscription?.cancel();

    // Create new subscription with different settings
    _gpsSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: newAccuracy,
        distanceFilter: 0,
      ),
    ).listen(_onPositionUpdate, onError: _onGpsError);
  }
}
```

### Pattern 2: Lifecycle-Aware GPS Control

**What:** Use WidgetsBindingObserver to detect app backgrounding and conditionally stop GPS based on overlay state

**When to use:** GpsDataManager implements WidgetsBindingObserver mixin, overrides didChangeAppLifecycleState

**Example:**
```dart
// Source: Flutter official API docs - WidgetsBindingObserver
class GpsDataManager extends ChangeNotifier with WidgetsBindingObserver {
  OverlayProvider? _overlayProvider; // Set via dependency injection
  Timer? _backgroundGracePeriodTimer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Logger.debug('App lifecycle changed to: $state', 'GpsDataManager');

    if (state == AppLifecycleState.paused) {
      _handleAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      _handleAppForegrounded();
    }
  }

  void _handleAppBackgrounded() {
    final overlayActive = _overlayProvider?.isOverlayActive ?? false;

    if (overlayActive) {
      Logger.info('App backgrounded WITH overlay - maintaining full GPS', 'GpsDataManager');
      // Do nothing - keep GPS running at current precision
    } else {
      Logger.info('App backgrounded WITHOUT overlay - starting grace period', 'GpsDataManager');
      _backgroundGracePeriodTimer?.cancel();
      _backgroundGracePeriodTimer = Timer(Duration(seconds: 7), () {
        Logger.info('Grace period expired - stopping GPS', 'GpsDataManager');
        _stopGps();
      });
    }
  }

  void _handleAppForegrounded() {
    _backgroundGracePeriodTimer?.cancel();
    _backgroundGracePeriodTimer = null;

    if (_gpsSubscription == null) {
      Logger.info('App foregrounded - restarting GPS', 'GpsDataManager');
      _startGps(); // Will show last known data as stale until fresh update
    }
  }

  void _stopGps() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    // Keep last data in _currentData - UI will show it as stale after timeout
  }
}
```

### Pattern 3: Conditional Wake Lock Management

**What:** Enable wake lock when GPS is actively tracking AND (overlay visible OR main app in foreground)

**When to use:** Update wake lock state on GPS start/stop, overlay show/hide, app background/foreground

**Example:**
```dart
// Source: wakelock_plus pub.dev official docs
import 'package:wakelock_plus/wakelock_plus.dart';

class GpsDataManager extends ChangeNotifier with WidgetsBindingObserver {
  bool _isAppInForeground = true;
  bool _isGpsActive = false;

  void _updateWakeLock() {
    final overlayActive = _overlayProvider?.isOverlayActive ?? false;
    final shouldKeepAwake = _isGpsActive && (overlayActive || _isAppInForeground);

    if (shouldKeepAwake) {
      WakelockPlus.enable();
      Logger.debug('Wake lock enabled (GPS active, overlay=$overlayActive, foreground=$_isAppInForeground)', 'GpsDataManager');
    } else {
      WakelockPlus.disable();
      Logger.debug('Wake lock disabled', 'GpsDataManager');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInForeground = (state == AppLifecycleState.resumed);
    _updateWakeLock();
    // ... rest of lifecycle handling
  }

  void _startGps() {
    // ... GPS subscription creation
    _isGpsActive = true;
    _updateWakeLock();
  }

  void _stopGps() {
    // ... GPS subscription cancellation
    _isGpsActive = false;
    _updateWakeLock();
  }
}
```

### Pattern 4: Shared Staleness Detection

**What:** Apply same staleness logic (3s dim, 10s dashes) to main screen and overlay by using broadcast stream

**When to use:** Main SpeedometerScreen subscribes to GpsDataManager.dataStream, checks timestamp age in build()

**Example:**
```dart
// Source: Existing overlay_screen.dart implementation adapted for main screen
class _SpeedometerScreenState extends State<SpeedometerScreen> {
  ProcessedGpsData? _latestData;

  @override
  void initState() {
    super.initState();
    // Subscribe to GPS data stream
    context.read<GpsDataManager>().dataStream.listen((data) {
      if (mounted) {
        setState(() {
          _latestData = data;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gpsManager = context.watch<GpsDataManager>();
    final data = _latestData ?? gpsManager.currentData;

    // Calculate staleness (same logic as overlay)
    final age = DateTime.now().difference(data.timestamp);
    final isDimmed = age >= Duration(seconds: 3);
    final showDashes = age >= Duration(seconds: 10);

    final displaySpeed = showDashes ? '--' : data.displaySpeed;
    final opacity = isDimmed ? 0.5 : 1.0;

    return Text(
      displaySpeed,
      style: TextStyle(
        color: Colors.white.withOpacity(opacity),
        // ... other styling
      ),
    );
  }
}
```

### Anti-Patterns to Avoid

- **Polling for GPS state changes:** Don't use Timer.periodic to check if precision should change - react to actual GPS updates via stream
- **Switching precision on every update:** Don't cancel/recreate stream unless crossing hysteresis boundary - causes GPS fix loss
- **Disposing WidgetsBindingObserver in ChangeNotifier.dispose():** Must call WidgetsBinding.instance.removeObserver(this) before super.dispose()
- **Enabling wake lock in main():** Wake lock should be contextual to tracking state, not globally enabled
- **Forgetting to handle resume after GPS stopped:** Must restart GPS when returning to foreground, or UI shows stale data forever

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| GPS position streams | Custom native channel to Android Location API | geolocator.getPositionStream() | Handles platform differences, permission edge cases, timeout logic, Fused Location Provider integration |
| Speed unit conversion | Manual conversion logic scattered in UI | Centralized SpeedUnit enum with convert() | Already implemented in config/speed_unit.dart - single source of truth |
| Wake lock management | Custom platform channel to PowerManager | wakelock_plus | Cross-platform, handles external wake lock release, no permissions needed |
| App lifecycle detection | Manual ActivityLifecycleCallbacks via platform channel | WidgetsBindingObserver | Built into Flutter, handles iOS/Android differences, reliable state transitions |
| Threshold conversion (km/h ↔ m/s) | Inline calculations | Constants with documented conversions | 8 km/h = 2.22 m/s, 12 km/h = 3.33 m/s - define once, reference everywhere |

**Key insight:** GPS lifecycle is deceptively complex. Android's Fused Location Provider has nuances around exclusive access, battery optimization interference, and cold start timing. geolocator abstracts all of this. Custom implementations miss edge cases like GPS disabled mid-stream, permission revoked, or battery saver killing background location.

## Common Pitfalls

### Pitfall 1: Stream Subscription Memory Leak

**What goes wrong:** Canceling stream subscription doesn't always stop Android location service, causing battery drain even after app closes

**Why it happens:** Android LocationManager may keep location service running if other apps are using it, or if subscription cancel is not properly awaited

**How to avoid:**
- Always cancel subscription in dispose(): `_gpsSubscription?.cancel(); _gpsSubscription = null;`
- Remove WidgetsBindingObserver: `WidgetsBinding.instance.removeObserver(this);`
- Call super.dispose() AFTER cleanup, not before

**Warning signs:**
- GPS icon stays in status bar after app closed
- Battery draining faster than expected
- Memory profiler shows GpsDataManager not garbage collected

**Reference:** [Bug #1682: Location Service Not Stopped After Cancelling](https://github.com/Baseflow/flutter-geolocator/issues/1682)

### Pitfall 2: Precision Switching During GPS Fix Acquisition

**What goes wrong:** Switching precision while GPS is acquiring initial fix causes timeout or permanent "--" display

**Why it happens:** Canceling subscription during getCurrentPosition() or early in stream lifecycle resets the cold start process

**How to avoid:**
- Only switch precision AFTER first position received
- Add minimum dwell time (e.g., 5 seconds) before allowing first switch
- Use a boolean flag `_hasFirstFix` to gate precision switching logic

**Warning signs:**
- Speed shows "--" for extended periods outdoors
- Logger shows repeated "switching to X" messages without position updates
- GPS timeout errors in logs

### Pitfall 3: Race Condition Between Lifecycle and Overlay State

**What goes wrong:** App backgrounds while overlay is launching → grace period starts → overlay finishes launching → GPS stops despite overlay being active

**Why it happens:** didChangeAppLifecycleState fires before overlay activation completes, decision made on stale state

**How to avoid:**
- Cancel grace period timer when overlay becomes active (already implemented in Phase 3)
- Check overlay state synchronously at grace period expiration, not at start
- Log both states (overlay + lifecycle) whenever making GPS stop decision

**Warning signs:**
- Overlay shows "--" immediately after backgrounding
- Logger shows "stopping GPS" followed by "overlay active" within same second
- Inconsistent behavior when quickly switching apps

### Pitfall 4: Hysteresis Calculation Using Wrong Units

**What goes wrong:** Comparing m/s speed against km/h thresholds → precision never switches or switches at wrong speed

**Why it happens:** geolocator Position.speed is in m/s, thresholds in requirements are km/h

**How to avoid:**
- Convert to km/h immediately: `final speedKmh = position.speed * 3.6;`
- Define threshold constants in m/s: `const PRECISION_UP_THRESHOLD_MPS = 3.33;` (12 km/h)
- Add unit suffix to constant names: `_KMPH` vs `_MPS` to make unit explicit

**Warning signs:**
- Precision switches at walking speed (2-3 km/h) instead of jogging speed (12 km/h)
- Logger shows speed like "25.5" switching to high precision (would be 92 km/h if already in km/h)

### Pitfall 5: Wake Lock Persists After App Backgrounded

**What goes wrong:** Screen stays on indefinitely when app is backgrounded without overlay, draining battery

**Why it happens:** wake lock is not tied to lifecycle state, only to GPS state

**How to avoid:**
- Update wake lock in didChangeAppLifecycleState, not just in GPS start/stop
- Explicitly check: `_isGpsActive && (overlayActive || _isAppInForeground)`
- Call `WakelockPlus.disable()` in dispose() as safety net

**Warning signs:**
- Screen doesn't auto-lock after switching away from app
- Battery drain continues when app backgrounded
- `WakelockPlus.enabled` returns true when app not visible

### Pitfall 6: Staleness Detection Not Updated After GPS Restart

**What goes wrong:** GPS stops due to backgrounding, restarts on foreground resume, but timestamp from old data makes new data appear stale

**Why it happens:** ProcessedGpsData timestamp not updated when reusing last known position during GPS restart

**How to avoid:**
- Update timestamp when restarting GPS: `_currentData = _currentData.copyWith(timestamp: DateTime.now())`
- OR accept brief staleness as correct behavior (user decision: show last known speed, appears stale until fresh data)
- Log clearly: "Restarting GPS - showing last known position (will appear stale)"

**Warning signs:**
- Speed immediately dims/dashes on foreground resume despite GPS being active
- Logger shows fresh GPS updates but UI stays dimmed

## Code Examples

Verified patterns from official sources and existing codebase:

### Speed Unit Conversion for Thresholds
```dart
// Source: Existing config/speed_unit.dart pattern
// Position.speed is in m/s, thresholds are in km/h
// Conversion: km/h = m/s * 3.6

abstract class GpsThresholds {
  // User decision: 8 km/h down, 12 km/h up
  static const double PRECISION_DOWN_THRESHOLD_KMPH = 8.0;
  static const double PRECISION_UP_THRESHOLD_KMPH = 12.0;

  // Precomputed m/s for comparison
  static const double PRECISION_DOWN_THRESHOLD_MPS = 2.22; // 8 / 3.6
  static const double PRECISION_UP_THRESHOLD_MPS = 3.33;   // 12 / 3.6
}

// Usage:
final speedMps = position.speed;
if (speedMps > GpsThresholds.PRECISION_UP_THRESHOLD_MPS) {
  // Switch to high precision
}
```

### LocationSettings Configuration
```dart
// Source: geolocator pub.dev official documentation
// https://pub.dev/packages/geolocator

// High precision (above threshold)
final highPrecisionSettings = LocationSettings(
  accuracy: LocationAccuracy.high, // Android: high priority, iOS: kCLLocationAccuracyBest
  distanceFilter: 0, // Report all updates, no minimum distance
);

// Balanced precision (below threshold)
final balancedPrecisionSettings = LocationSettings(
  accuracy: LocationAccuracy.medium, // Android: balanced power, iOS: kCLLocationAccuracyHundredMeters
  distanceFilter: 0,
);

// Android-specific override (optional, for battery saver detection)
final androidSettings = AndroidSettings(
  accuracy: LocationAccuracy.medium,
  distanceFilter: 0,
  forceLocationManager: false, // Use Fused Location Provider
  intervalDuration: Duration(seconds: 1),
);
```

### WidgetsBindingObserver Registration
```dart
// Source: Flutter official API docs - WidgetsBindingObserver
// https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html

class GpsDataManager extends ChangeNotifier with WidgetsBindingObserver {
  Future<void> initialize() async {
    // ... GPS initialization

    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    Logger.debug('Registered lifecycle observer', 'GpsDataManager');
  }

  @override
  void dispose() {
    // CRITICAL: Remove observer BEFORE calling super.dispose()
    WidgetsBinding.instance.removeObserver(this);

    _gpsSubscription?.cancel();
    _backgroundGracePeriodTimer?.cancel();
    WakelockPlus.disable(); // Safety net

    super.dispose();
  }
}
```

### ProcessedGpsData Timestamp Addition
```dart
// Source: Existing models/overlay_message.dart pattern from Phase 3
// ProcessedGpsData needs timestamp field for staleness detection

class ProcessedGpsData {
  final double speed;
  final double heading;
  final String displaySpeed;
  final String displayHeading;
  final bool isSpeedValid;
  final bool isHeadingValid;
  final DateTime timestamp; // NEW: Add this field

  const ProcessedGpsData({
    required this.speed,
    required this.heading,
    required this.displaySpeed,
    required this.displayHeading,
    required this.isSpeedValid,
    required this.isHeadingValid,
    required this.timestamp, // NEW: Required parameter
  });

  ProcessedGpsData copyWith({
    double? speed,
    double? heading,
    String? displaySpeed,
    String? displayHeading,
    bool? isSpeedValid,
    bool? isHeadingValid,
    DateTime? timestamp, // NEW: Add to copyWith
  }) {
    return ProcessedGpsData(
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      displaySpeed: displaySpeed ?? this.displaySpeed,
      displayHeading: displayHeading ?? this.displayHeading,
      isSpeedValid: isSpeedValid ?? this.isSpeedValid,
      isHeadingValid: isHeadingValid ?? this.isHeadingValid,
      timestamp: timestamp ?? this.timestamp, // NEW
    );
  }
}

// Usage in GpsDataManager:
void _onPositionUpdate(Position position) {
  final processedData = ProcessedGpsData(
    speed: speed,
    heading: heading,
    displaySpeed: displaySpeed,
    displayHeading: displayHeading,
    isSpeedValid: speedValid,
    isHeadingValid: headingValid,
    timestamp: DateTime.now(), // NEW: Capture update time
  );

  _updateData(processedData);
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single LocationAccuracy for entire session | Dynamic switching based on speed/context | geolocator 7.0.0+ (2021) with LocationSettings | Better battery life without sacrificing accuracy when needed |
| WidgetsBindingObserver only | AppLifecycleListener alternative | Flutter 3.13 (Aug 2023) | More granular lifecycle callbacks, but WidgetsBindingObserver still standard |
| wakelock (deprecated) | wakelock_plus | 2023 migration | Active maintenance, null safety, better platform support |
| Exclusive GPS access assumptions | Fused Location Provider awareness | Android 8.0+ default | Multiple apps can access location simultaneously |
| Manual permission checks | Automatic geolocator permission handling | geolocator 9.0.0+ (2022) | Less boilerplate, but still need permission_handler for SYSTEM_ALERT_WINDOW |

**Deprecated/outdated:**
- `Geolocator.getPositionStream(desiredAccuracy: ...)` → Use `getPositionStream(locationSettings: LocationSettings(...))`
- `LocationAccuracy.bestForNavigation` on Android → Maps to same as `high` (iOS only distinction)
- Calling `WakelockPlus.enable()` once in `main()` → Contextual enable/disable based on tracking state
- Assuming stream cancel stops location service → May continue if other apps using it (not a bug, by design)

## Open Questions

### 1. Battery Saver Mode Detection
**What we know:** Android BatteryManager can detect power save mode via platform channels, battery_optimization_helper package exists

**What's unclear:** Whether detection complexity is worth it for this phase - user decision was "respect partially, use balanced always" but no requirement to detect it automatically

**Recommendation:** DEFER to future phase. Implement manual mode toggle or skip entirely. Detection requires platform channel, testing on multiple Android versions, and handling OEM variations (Xiaomi, Samsung, etc.). Balanced precision by default may be sufficient for battery-conscious users.

### 2. Grace Period Reuse vs New Timer
**What we know:** Phase 3 created `_gracePeriodTimer` in OverlayProvider (30s, currently unused). User decision allows 5-10s grace period for background GPS.

**What's unclear:** Whether to reuse Phase 3's 30s timer infrastructure or create separate 5-10s timer in GpsDataManager

**Recommendation:** Create SEPARATE timer in GpsDataManager. Different purpose (GPS lifecycle vs overlay closing), different duration (5-10s vs 30s), different trigger (app lifecycle vs overlay close). Keeps concerns separated. Phase 3 timer can be removed as unused infrastructure.

### 3. Staleness Detection Code Sharing
**What we know:** Overlay has staleness logic (3s dim, 10s dash) in overlay_screen.dart. Main app needs identical logic.

**What's unclear:** Whether to extract to shared utility function or duplicate in SpeedometerScreen

**Recommendation:** INLINE in SpeedometerScreen. Logic is 4 lines (calculate age, check thresholds, set opacity/text). Shared utility adds indirection for minimal reuse benefit. Both screens independently check `DateTime.now().difference(data.timestamp)` against OverlayConfig constants. Simple, readable, maintainable.

## Sources

### Primary (HIGH confidence)
- [geolocator package documentation](https://pub.dev/packages/geolocator) - LocationSettings API, accuracy levels, stream management
- [wakelock_plus package documentation](https://pub.dev/packages/wakelock_plus) - Wake lock enable/disable patterns, background behavior
- [Flutter WidgetsBindingObserver API](https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html) - Lifecycle state detection
- [Flutter AppLifecycleState enum](https://api.flutter.dev/flutter/dart-ui/AppLifecycleState.html) - State definitions (paused, resumed)
- Existing codebase:
  - `lib/services/gps_data_manager.dart` - Current GPS subscription pattern
  - `lib/providers/overlay_provider.dart` - Grace period timer infrastructure
  - `lib/screens/overlay_screen.dart` - Staleness detection implementation
  - `lib/config/speed_unit.dart` - Speed conversion pattern
  - `lib/config/timing_constants.dart` - Grace period constant location

### Secondary (MEDIUM confidence)
- [Understanding Flutter Streams - LogRocket Blog](https://blog.logrocket.com/understanding-flutter-streams/) - Stream subscription lifecycle best practices
- [Understanding WidgetsBindingObserver - Medium](https://medium.com/@bhupenrathore11/understanding-widgetsbindingobserver-in-flutter-8327fa6c75a3) - Lifecycle observer patterns
- [Flutter Sensors Tutorial - MantraIdeas](https://mantraideas.com/build-sensor-apps-flutter-examples/) - GPS sensor integration patterns
- [Fused Location Provider API - Google Developers](https://developers.google.com/location-context/fused-location-provider) - Android non-exclusive GPS behavior
- [Memory Leaks in Flutter - Medium](https://medium.com/@prathamesh.dev004/memory-leaks-in-flutter-common-pitfalls-how-to-avoid-them-7d8d67b6934e) - StreamSubscription disposal patterns

### Tertiary (LOW confidence)
- [battery_optimization_helper package](https://pub.dev/packages/battery_optimization_helper) - Battery saver detection (not yet verified for Android version compatibility)
- [Geolocator Issue #1682](https://github.com/Baseflow/flutter-geolocator/issues/1682) - Location service not stopping after cancel (known issue, workaround unclear)
- [Speed conversion calculators](https://coolconversion.com/speed/8-km/h-to-m/s) - 8 km/h = 2.22 m/s, 12 km/h = 3.33 m/s (verified against multiple sources)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All packages already integrated, official Flutter Community packages with extensive usage
- Architecture: HIGH - Patterns verified in official docs and existing codebase (Phase 3 staleness, Provider pattern)
- Pitfalls: MEDIUM-HIGH - Stream disposal and lifecycle issues well-documented, precision switching pitfalls inferred from GPS behavior
- Code examples: HIGH - Based on official API docs and working Phase 3 implementations

**Research date:** 2026-02-12
**Valid until:** 2026-03-14 (30 days - stable ecosystem, no major Flutter/Android releases expected)
