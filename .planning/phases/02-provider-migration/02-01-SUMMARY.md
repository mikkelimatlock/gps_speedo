---
phase: 02-provider-migration
plan: 01
subsystem: state-management
tags: [provider, changenotifier, dependency-injection, settings-persistence, overlay-management]

requires:
  - phase: 01
    outputs: [Logger, ProcessedGpsData, OverlayMessage, config constants, modular file structure]

provides:
  infrastructure:
    - GpsDataManager as ChangeNotifier (reactive GPS data)
    - SettingsProvider (theme + unit persistence)
    - OverlayProvider (centralized overlay lifecycle)
    - provider ^6.1.2 and shared_preferences ^2.3.4 packages

affects:
  - phase: 02
    plan: 02
    why: Plan 02-02 will wire these providers via MultiProvider and migrate SpeedometerScreen

tech-stack:
  added:
    - provider: ^6.1.2
    - shared_preferences: ^2.3.4
  patterns:
    - ChangeNotifier for reactive state
    - _isDisposed guards for async safety
    - Constructor injection for SharedPreferences
    - Stream + ChangeNotifier dual access pattern

key-files:
  created:
    - lib/providers/settings_provider.dart
    - lib/providers/overlay_provider.dart
  modified:
    - lib/services/gps_data_manager.dart
    - pubspec.yaml

decisions:
  - decision: GpsDataManager singleton removed, replaced with public constructor
    rationale: Provider manages lifecycle via dependency injection
    impact: All GpsDataManager.instance calls must migrate to context.read/watch
    alternatives: Keep singleton, wrap with separate provider class
    confidence: HIGH

  - decision: SettingsProvider combines theme + units in single provider
    rationale: Settings always change together in user flow, no performance benefit to splitting
    impact: Single provider subscription for all settings UI
    alternatives: Separate ThemeProvider and UnitProvider
    confidence: MEDIUM

  - decision: OverlayProvider listens to GPS stream continuously, skips sends when inactive
    rationale: Simpler than subscribe/unsubscribe on activate/deactivate, avoids subscription lifecycle bugs
    impact: GPS stream always has one listener even when overlay closed
    alternatives: Subscribe on activate, unsubscribe on deactivate
    confidence: MEDIUM

  - decision: SharedPreferences loaded eagerly in constructor, not async
    rationale: Pre-initialization in main() before runApp() eliminates flash of defaults
    impact: main() must be async and call SharedPreferences.getInstance() before MultiProvider
    alternatives: FutureProvider with async loading, show splash during load
    confidence: HIGH

metrics:
  duration: 7.7 min
  completed: 2026-02-10
---

# Phase 02 Plan 01: Provider Infrastructure Summary

**One-liner:** Provider pattern foundation with ChangeNotifier-based GpsDataManager, SettingsProvider (theme+units), and OverlayProvider (lifecycle+messaging)

## What Was Built

Created the three core Provider classes that will replace all setState() calls in SpeedometerScreen:

### 1. GpsDataManager Refactored (Task 1)
- **Removed singleton pattern** — deleted `static _instance` and `static get instance`
- **Changed to public constructor** — `GpsDataManager._internal()` → `GpsDataManager()`
- **Extended ChangeNotifier** — added `import 'package:flutter/foundation.dart'`
- **Added reactive notifications** — `notifyListeners()` called in `_updateData()` after stream emission
- **Async safety via _isDisposed guard** — prevents "ChangeNotifier after dispose" errors
  - Guard added to: `_updateData()`, `_onGpsError()`, `_handleStaleDataTimeout()`
- **Proper disposal** — `@override dispose()` sets `_isDisposed = true`, cleans up subscriptions/timers, calls `super.dispose()` last
- **Dual access pattern** — Stream (for OverlayProvider) + ChangeNotifier (for UI widgets) coexist

### 2. SettingsProvider Created (Task 2)
- **Combines theme + speed unit** — single provider for all user settings
- **Constructor injection** — accepts pre-initialized `SharedPreferences` instance
- **Synchronous load** — `_loadSettings()` reads from SharedPreferences in constructor
  - No `notifyListeners()` in constructor (runs before first build)
- **Persistence on change** — `cycleTheme()` and `cycleUnit()` both:
  - Trigger haptic feedback via `HapticFeedback.lightImpact()`
  - Persist to SharedPreferences via `_prefs.setInt()`
  - Call `notifyListeners()` for reactive UI updates
- **Computed getter** — `currentTheme` delegates to `ColorThemes.getTheme(_currentThemeIndex)`

### 3. OverlayProvider Created (Task 3)
- **Centralizes ALL overlay operations** — show, close, toggle, status polling, IPC messaging
- **Dependency injection via updateDependencies()** — called by `ChangeNotifierProxyProvider2`
  - Accepts `GpsDataManager`, `SpeedUnit`, `int themeIndex`
  - Subscribes to GPS stream on first call (persists for lifetime)
  - Pushes updated settings to overlay when active
- **Conditional messaging** — `if (_isOverlayActive && !_isDisposed)` guards overlay sends
- **Stream subscription lifecycle** — GPS stream subscribed once, never unsubscribed (just skip sends)
- **Overlay lifecycle management:**
  - `showOverlay()` — calculates size, sends initial data with dimensions, launches overlay
  - `closeOverlay()` — closes overlay window via platform API
  - `toggleOverlay()` — convenience wrapper
  - `_handleOverlayClose()` — cleanup, optional bring-to-front
- **IPC handling** — `_startListeningToOverlayMessages()` processes overlay→main messages
- **Status polling** — 1-second timer checks `FlutterOverlayWindow.isActive()` for close detection
- **Public interface** — `pushCurrentData()` for background heartbeat usage
- **Async safety** — `_isDisposed` guards on all methods, disposes 4 subscriptions/timers

### 4. Dependencies Added
- **provider: ^6.1.2** — state management via ChangeNotifier/Consumer/Selector
- **shared_preferences: ^2.3.4** — persistent settings storage

## Commits

| Hash    | Type  | Message                                                         |
|---------|-------|-----------------------------------------------------------------|
| f458b62 | chore | add provider dependencies and refactor GpsDataManager           |
| 1961651 | feat  | create SettingsProvider for theme and unit state                |
| 6b8bba8 | feat  | create OverlayProvider for overlay lifecycle and messaging      |

## Deviations from Plan

None — plan executed exactly as written.

All three providers created with proper ChangeNotifier implementation, _isDisposed guards, and super.dispose() calls. Dependencies installed successfully.

## Key Decisions Made

### GpsDataManager Singleton Removal
**Decision:** Remove singleton pattern entirely, use Provider-managed lifecycle

**Why:** Provider's dependency injection handles instance lifecycle, disposal, and testing overrides automatically. Singleton creates hidden global state that bypasses Provider's benefits.

**Implementation:**
- Deleted `static GpsDataManager? _instance;`
- Deleted `static GpsDataManager get instance => _instance ??= GpsDataManager._internal();`
- Changed `GpsDataManager._internal()` to public `GpsDataManager()`
- Provider creates instance via `ChangeNotifierProvider(create: (_) => GpsDataManager())`

**Impact:** All existing `GpsDataManager.instance` calls in SpeedometerScreen will error — must migrate to `context.read<GpsDataManager>()` in Plan 02-02.

**Verification:** `grep -E "static.*instance" lib/services/gps_data_manager.dart` returns empty (singleton removed)

### Settings Provider Consolidation
**Decision:** Combine theme and speed unit into single SettingsProvider

**Why:**
1. Settings always change together in user flow (theme button, unit button side-by-side)
2. No performance benefit to splitting — both are low-frequency updates
3. Simpler dependency graph — one provider instead of two

**Alternatives considered:**
- Separate ThemeProvider and UnitProvider — rejected due to unnecessary complexity
- Single AppStateProvider for all state — rejected per context decision (granular providers)

**Impact:** UI widgets subscribe to one provider for both theme and unit data.

### Overlay Stream Subscription Strategy
**Decision:** Subscribe to GPS stream once in updateDependencies(), skip sends when inactive via if-check

**Why:**
1. Simpler lifecycle — no subscribe/unsubscribe dance
2. Avoids "bad state: stream already listened to" errors
3. Negligible performance impact (if-check vs subscription churn)

**Alternatives considered:**
- Subscribe on activate, unsubscribe on deactivate — rejected due to async subscription timing bugs
- Pause/resume stream subscription — rejected as StreamSubscription.pause() doesn't exist for broadcast streams

**Implementation:**
```dart
void updateDependencies({...}) {
  if (_gpsManager == null) {
    _gpsManager = gpsManager;
    _gpsSubscription = gpsManager.dataStream.listen((data) {
      if (_isOverlayActive && !_isDisposed) {  // Skip sends when inactive
        _pushDataToOverlay(data);
      }
    });
  }
}
```

### SharedPreferences Pre-Initialization
**Decision:** Load SharedPreferences in main() before runApp(), inject into SettingsProvider constructor

**Why:**
1. Eliminates "flash of defaults" on first app launch
2. Makes SettingsProvider constructor synchronous (no async create callback)
3. Matches Flutter best practice per provider research

**Implementation pattern:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: prefs),
        ChangeNotifierProvider(create: (ctx) => SettingsProvider(ctx.read<SharedPreferences>())),
      ],
      child: SpeedoApp(),
    ),
  );
}
```

**Impact:** Plan 02-02 must implement this async main() pattern.

## Testing Notes

### Verification Performed
1. ✅ `flutter pub get` — dependencies resolve without conflicts
2. ✅ `flutter analyze` — no errors in provider files (only expected SpeedometerScreen errors from removed singleton)
3. ✅ GpsDataManager extends ChangeNotifier — verified via grep
4. ✅ GpsDataManager calls notifyListeners() in _updateData() — verified via code inspection
5. ✅ No singleton pattern in GpsDataManager — verified via grep (no static instance)
6. ✅ SettingsProvider loads from SharedPreferences — constructor calls _loadSettings()
7. ✅ SettingsProvider persists on change — cycleTheme/cycleUnit call _prefs.setInt()
8. ✅ OverlayProvider has updateDependencies() — verified via grep
9. ✅ OverlayProvider skips sends when inactive — `if (_isOverlayActive && !_isDisposed)` guards
10. ✅ All providers have proper dispose() — @override, _isDisposed guard, super.dispose() last

### Expected Errors (Will Fix in Plan 02-02)
```
error - The getter 'instance' isn't defined for the type 'GpsDataManager'
  lib\screens\speedometer_screen.dart:302:28
  lib\screens\speedometer_screen.dart:307:45
  lib\screens\speedometer_screen.dart:354:38
  lib\screens\speedometer_screen.dart:398:40
```

These are intentional — singleton removal breaks old code. Plan 02-02 will migrate all references to Provider-based access.

### Manual Testing Required (Deferred to Plan 02-02)
- [ ] App compiles after MultiProvider wiring
- [ ] GPS data updates trigger UI rebuilds via Consumer/Selector
- [ ] Theme/unit cycling persists across app restarts
- [ ] Overlay launches and receives GPS data
- [ ] No "ChangeNotifier after dispose" errors on hot reload
- [ ] No "setState after dispose" errors on navigation

## Integration Points

### For Plan 02-02 (Screen Migration)
**What's ready:**
- Three ChangeNotifier providers ready for MultiProvider wiring
- GpsDataManager replaces direct GPS stream subscription
- SettingsProvider replaces setState for theme/unit
- OverlayProvider replaces inline overlay management code

**What Plan 02-02 must do:**
1. Implement async main() with SharedPreferences.getInstance()
2. Wire MultiProvider with dependency order:
   - Provider.value(prefs)
   - ChangeNotifierProvider(SettingsProvider)
   - ChangeNotifierProvider(GpsDataManager)
   - ChangeNotifierProxyProvider2(OverlayProvider) — depends on GPS + Settings
3. Replace all `GpsDataManager.instance` calls with `context.read/watch`
4. Replace setState for theme/unit with `context.read<SettingsProvider>().cycleTheme/Unit()`
5. Replace inline overlay code with `context.read<OverlayProvider>().showOverlay/closeOverlay()`
6. Wrap speed display with `Selector<GpsDataManager, String>` for granular rebuilds
7. Wrap theme controls with `Consumer<SettingsProvider>` for reactive updates
8. Call `context.read<GpsDataManager>().initialize()` in screen initState

**Expected file changes in Plan 02-02:**
- lib/main.dart — async main(), MultiProvider setup
- lib/screens/speedometer_screen.dart — remove setState, add Consumer/Selector, remove inline overlay code

## Architecture Notes

### ChangeNotifier Lifecycle Pattern
All three providers follow the same disposal pattern:

```dart
@override
void dispose() {
  _isDisposed = true;  // FIRST: Set guard flag
  // ... cancel all async operations (streams, timers, listeners)
  super.dispose();     // LAST: Call ChangeNotifier cleanup
}
```

**Why _isDisposed guard:** Async operations (GPS stream, overlay listeners, timers) may complete after dispose() called. Guard prevents "ChangeNotifier after dispose" assertion by short-circuiting methods that call notifyListeners().

### Dual Access Pattern (GpsDataManager)
GpsDataManager provides two access patterns:

1. **Stream-based** — `dataStream` getter for OverlayProvider's continuous subscription
2. **ChangeNotifier-based** — `currentData` getter + `notifyListeners()` for UI widgets

**Why both:** OverlayProvider needs stream subscription to push data to overlay isolate. UI widgets prefer ChangeNotifier for reactive rebuilds. Both patterns share the same `_currentData` state and update simultaneously in `_updateData()`.

### Provider Dependency Graph
```
SharedPreferences (pre-initialized)
  └─> SettingsProvider (theme + unit)

GpsDataManager (independent, no deps)

OverlayProvider
  ├─> GpsDataManager (GPS data stream)
  └─> SettingsProvider (theme + unit for overlay)
```

Plan 02-02 will wire this via ChangeNotifierProxyProvider2 for OverlayProvider.

## Next Phase Readiness

### Blockers: NONE
All deliverables complete. Plan 02-02 can proceed immediately.

### Concerns: LOW
**Async main() timing:** SharedPreferences.getInstance() adds ~50-100ms startup delay. Acceptable per research (eliminates flash of defaults).

**Overlay stream persistence:** GPS stream stays subscribed even when overlay closed. Negligible performance impact (if-check is O(1), subscription churn avoided).

### Preparation for Plan 02-02
- [x] Provider classes created and verified
- [x] Dependencies installed and resolving
- [x] No circular dependencies between providers
- [x] All providers have proper dispose() implementations
- [x] _isDisposed guards prevent async disposal errors

**Ready for execution:** Plan 02-02 can wire providers and migrate screen without blockers.

---

**Plan 02-01 complete.** Three ChangeNotifier providers created with proper lifecycle management, async safety guards, and reactive notifications. Dependencies installed. Ready for MultiProvider wiring in Plan 02-02.
