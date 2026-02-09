# Feature Landscape: Flutter GPS Speedometer Restructure

**Domain:** Flutter GPS/Speedometer App Architecture
**Researched:** 2026-02-09
**Confidence:** HIGH (verified with official Flutter docs + Android developer guides)

## Executive Summary

This research focuses on **HOW** features should be structured in a well-architected Flutter GPS speedometer app, not what new features to add. The current app suffers from monolithic architecture (1,133-line main.dart with raw setState), buggy overlay data synchronization, and aggressive power usage. Research reveals that modern 2026 Flutter architecture emphasizes MVVM/feature-first organization, proper state management with Provider (or migration to Riverpod), and adaptive GPS precision strategies.

---

## Table Stakes

Features/patterns users expect from a well-structured GPS speedometer app. Missing = restructure is pointless.

| Pattern | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **MVVM Layer Separation** | Standard 2026 Flutter architecture - UI/Logic/Data layers must be distinct | Medium | View ↔ ViewModel ↔ Repository ↔ Service. Official Flutter recommendation. Prevents spaghetti code. |
| **Feature-First Folder Structure** | Scales better than layer-first for multi-feature apps | Low | `lib/features/speedometer/`, `lib/features/overlay/`, `lib/core/`. Each feature self-contained. |
| **Repository Pattern** | Single source of truth for GPS data - prevents state drift | Medium | GpsDataManager → Repository → Service pattern. Already partially implemented. |
| **Provider Integration** | Move from raw setState to proper reactive state management | Medium | Consumer widgets + ChangeNotifier. Current app has Provider in dependencies but doesn't fully use it. |
| **Speed-Adaptive GPS Precision** | Critical for battery life - high accuracy only when moving fast | High | Switch PRIORITY_HIGH_ACCURACY ↔ PRIORITY_BALANCED_POWER_ACCURACY based on speed thresholds (e.g., <5 km/h = balanced, >5 km/h = high). |
| **Isolate-Aware Overlay Communication** | Overlay runs in separate isolate - needs proper message protocol | High | Use `FlutterOverlayWindow.shareData()` with structured messages. Current stale data issue stems from one-time sync instead of continuous updates. |
| **Unidirectional Data Flow** | State flows downward: Data Layer → Logic Layer → UI Layer | Medium | Prevents circular dependencies. Events flow upward via commands/callbacks. |
| **Service Layer Isolation** | GPS hardware access isolated to service layer only | Low | Already have `gps_service.dart`. Must ensure ViewModels never call Geolocator directly. |
| **Lifecycle-Aware State Management** | Properly handle app backgrounding, overlay launch/close, GPS stream lifecycle | Medium | Use WidgetsBindingObserver + StreamSubscription cleanup. Partially implemented but needs formalization. |

---

## Differentiators

Patterns that make the architecture notably better than standard implementations.

| Pattern | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Hybrid GPS Strategy** | Better battery life than continuous HIGH_ACCURACY - adaptively switches precision based on movement context | High | Combine speed threshold + WiFi connection state + motion sensors. Example: stationary + WiFi connected = PASSIVE mode, slow movement = BALANCED, fast movement = HIGH_ACCURACY. |
| **Message Queue for Overlay Sync** | Prevents data staleness - overlay receives continuous updates via message stream | Medium | Implement periodic broadcast (e.g., every 500ms) with debouncing. Queue messages if overlay isn't ready. Better than current one-shot messaging. |
| **WorkManager Background Tasks** | Modern alternative to wake locks - system handles power management | Medium | Use WorkManager for periodic location checks when app backgrounded. Replaces current aggressive wake lock + heartbeat timer pattern. Reduces Google Play Store policy violations. |
| **ViewModel Command Pattern** | Cleaner event handling - views call commands, ViewModels never expose widgets | Low | `viewModel.onThemeToggle()` instead of callbacks. Makes testing easier and separates concerns. |
| **Multi-Repository ViewModel** | Speedometer feature needs GPS + Settings + Overlay state - composing multiple repositories prevents monolithic ViewModels | Medium | SpeedometerViewModel depends on GpsRepository + SettingsRepository + OverlayRepository. Each repository focused on single domain. |
| **Duty-Cycle Awareness** | Android 9+ duty-cycles GNSS hardware - app should detect and adapt update frequency expectations | Medium | Monitor GPS timestamp deltas. If duty-cycling detected (irregular intervals), adjust UI update strategy to interpolate between readings. |
| **Scoped Provider Instances** | Overlay and main app have separate Provider scopes - prevents state collision | Medium | Each isolate (main app vs overlay) has its own Provider tree. Use message passing for synchronization, not shared state. Critical for fixing current stale data bug. |
| **Foreground Service Architecture** | Proper Android foreground service with notification for GPS tracking - prevents system kill | Low | Already have SYSTEM_ALERT_WINDOW permission. Add `android:foregroundServiceType="location"` and show persistent notification while tracking active. |

---

## Anti-Features

Things to deliberately NOT do during restructuring. Common mistakes in this domain.

| Anti-Pattern | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Monolithic ViewModel/Widget** | Current 1,133-line main.dart is technical debt. Difficult to test, reason about, or modify. | Split into feature-specific ViewModels: `SpeedometerViewModel`, `OverlayViewModel`, `SettingsViewModel`. Each <200 lines. |
| **Shared State Between Isolates** | Flutter overlay runs in separate isolate - cannot share memory. Current stale data bug stems from assuming shared state. | Use message passing only. Send serialized GPS data via `shareData()`. No global singletons accessible from both isolates. |
| **Continuous HIGH_ACCURACY GPS** | Current app uses HIGH_ACCURACY + wake locks continuously. Drains 7-12% battery per hour. Violates 2026 Google Play Store excessive wake lock policy. | Implement speed-adaptive precision. Switch to BALANCED_POWER_ACCURACY when stationary or slow (<5 km/h). Use PASSIVE mode when WiFi connected + stationary. |
| **Wake Lock Without Justification** | Current permanent wake lock prevents system power management. Google penalizes apps exceeding 2 hours wake lock in 24 hours. | Replace with WorkManager for background operation. Only use wake lock during active navigation/overlay display. Release wake lock when app backgrounded without overlay. |
| **setState for Cross-Widget State** | Using setState in main.dart forces entire screen rebuilds. Doesn't scale to overlay sync. | Migrate to Provider pattern fully. Use `Consumer` widgets at leaf nodes. Only rebuild widgets that depend on changed state. |
| **Synchronous Overlay Data Push** | Current "push once on overlay launch" approach causes stale data. Overlay has no way to request updates. | Implement continuous broadcast stream. Overlay subscribes to message stream and updates reactively. Debounce to 2-4 updates/second max. |
| **Ignoring Duty-Cycling** | Android duty-cycles GPS after Android 9 to save battery. Expecting continuous updates leads to UI jank when updates arrive in bursts. | Buffer GPS readings and interpolate between updates for smooth UI. Accept that <1s update frequency may not be achievable on battery-optimized devices. |
| **Repository Coupling** | Having GpsDataManager directly call overlay messaging violates separation of concerns. | GpsRepository emits data streams. Separate OverlayService subscribes to GPS stream and handles messaging. Repositories unaware of each other. |
| **Missing Error State Handling** | Current error messages displayed directly in UI. No way to recover from GPS permission denial or service disabled. | ViewModels expose error state objects. Views render error UI with action buttons (e.g., "Enable GPS" button opens system settings via SettingsClient). |
| **Over-Engineering with BLoC** | For this app's complexity, BLoC would add boilerplate without benefit. Current team already using Provider. | Stick with Provider + MVVM. Riverpod migration optional but not required. BLoC overkill for single-developer GPS app. |

---

## Feature Dependencies

Patterns have ordering dependencies - some must be implemented before others.

```
Foundation Layer (implement first):
├── Feature-First Folder Structure
├── Service Layer Isolation (GPS, Settings, Overlay)
└── Repository Pattern (single source of truth)
    ↓
State Management Layer (depends on repositories):
├── Provider Integration (ChangeNotifier ViewModels)
├── Unidirectional Data Flow
└── Lifecycle-Aware State Management
    ↓
GPS Optimization Layer (depends on state management):
├── Speed-Adaptive GPS Precision
├── Duty-Cycle Awareness
└── WorkManager Background Tasks (replaces wake locks)
    ↓
Overlay Communication Layer (depends on all above):
├── Isolate-Aware Messaging Protocol
├── Message Queue for Continuous Sync
└── Scoped Provider Instances (separate isolate contexts)
```

**Critical path**: Cannot fix overlay stale data issue until Provider properly integrated + message queue implemented + scoped instances established.

---

## MVP Recommendation

For restructure MVP, prioritize these patterns (in order):

### Phase 1: Foundation (Must Have)
1. **Feature-First Folder Structure** - Extract features from monolithic main.dart
2. **MVVM Layer Separation** - Create View/ViewModel/Repository/Service layers
3. **Provider Integration** - Replace setState with ChangeNotifier + Consumer

**Rationale**: These establish architectural foundation. Without these, remaining patterns cannot be properly implemented.

### Phase 2: GPS Optimization (Should Have)
4. **Speed-Adaptive GPS Precision** - Implement BALANCED ↔ HIGH_ACCURACY switching
5. **Repository Pattern** - Formalize GpsDataManager as proper Repository
6. **WorkManager Background Tasks** - Replace aggressive wake lock usage

**Rationale**: Addresses current battery drain and Google Play Store policy compliance. Can be implemented once foundation exists.

### Phase 3: Overlay Fix (Must Have for Feature Parity)
7. **Isolate-Aware Overlay Communication** - Implement proper message protocol
8. **Message Queue for Continuous Sync** - Fix stale data bug with stream-based updates
9. **Scoped Provider Instances** - Separate state management per isolate

**Rationale**: Fixes critical overlay bug. Blocked by Phase 1 Provider integration.

### Defer to Post-Restructure:

- **Duty-Cycle Awareness**: Nice-to-have optimization, not critical for functionality
- **Multi-Repository ViewModel**: Current app simple enough for single GPS repository
- **Hybrid GPS Strategy**: Advanced optimization - basic speed-adaptive sufficient for MVP
- **Foreground Service Architecture**: Already working, no immediate need to refactor

---

## Architecture Pattern Examples

### Current Problematic Pattern

```dart
// main.dart - 1,133 lines, monolithic
class _SpeedometerScreenState extends State<SpeedometerScreen> {
  SpeedUnit _currentUnit = SpeedUnit.kmh;           // Settings state
  int _currentThemeIndex = 0;                        // Theme state
  ProcessedGpsData _currentGpsData = ...;            // GPS state
  bool _isOverlayActive = false;                     // Overlay state
  Timer? _backgroundHeartbeatTimer;                  // Background state

  // All business logic mixed with UI logic
  void _startGPS() { ... }
  void _updateOverlay() { ... }
  Widget build(BuildContext context) { /* 800+ lines */ }
}
```

**Problems:**
- Single file responsible for 5+ concerns
- No testability (widget tests required for business logic)
- setState forces entire screen rebuild
- Overlay state coupled to main screen state

### Recommended Pattern: Feature-First MVVM

```
lib/
├── features/
│   ├── speedometer/
│   │   ├── presentation/
│   │   │   ├── speedometer_screen.dart          // View (UI only)
│   │   │   └── widgets/
│   │   │       ├── digital_display.dart
│   │   │       └── analog_gauge.dart
│   │   ├── viewmodels/
│   │   │   └── speedometer_viewmodel.dart       // ViewModel (UI logic)
│   │   └── data/
│   │       └── repositories/
│   │           └── gps_repository.dart          // Repository (data logic)
│   │
│   ├── overlay/
│   │   ├── presentation/
│   │   │   └── overlay_screen.dart              // Separate isolate UI
│   │   ├── viewmodels/
│   │   │   └── overlay_viewmodel.dart           // Overlay-specific logic
│   │   └── services/
│   │       └── overlay_messaging_service.dart   // Message protocol
│   │
│   └── settings/
│       ├── presentation/
│       │   └── settings_screen.dart
│       ├── viewmodels/
│       │   └── settings_viewmodel.dart
│       └── data/
│           └── repositories/
│               └── settings_repository.dart     // SharedPreferences wrapper
│
├── core/
│   ├── services/
│   │   ├── gps_service.dart                     // Hardware abstraction
│   │   └── permission_service.dart
│   └── models/
│       ├── processed_gps_data.dart
│       └── speed_unit.dart
│
└── main.dart                                    // App entry point only
```

**Benefits:**
- Each feature self-contained
- Business logic testable without Flutter
- Clear responsibility boundaries
- Easy to locate code by feature

### Recommended Pattern: ViewModel with Provider

```dart
// speedometer_viewmodel.dart
class SpeedometerViewModel extends ChangeNotifier {
  final GpsRepository _gpsRepository;
  final SettingsRepository _settingsRepository;

  // UI State (derived from repositories)
  ProcessedGpsData? _currentGpsData;
  bool _isLoading = true;
  String? _errorMessage;

  SpeedometerViewModel({
    required GpsRepository gpsRepository,
    required SettingsRepository settingsRepository,
  }) : _gpsRepository = gpsRepository,
       _settingsRepository = settingsRepository {
    _initialize();
  }

  // Getters (read-only state for views)
  ProcessedGpsData? get gpsData => _currentGpsData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  SpeedUnit get currentUnit => _settingsRepository.speedUnit;

  // Commands (view actions)
  Future<void> refreshGPS() async {
    // Business logic here
    notifyListeners();
  }

  void toggleSpeedUnit() {
    _settingsRepository.toggleSpeedUnit();
    notifyListeners();
  }

  void _initialize() {
    // Subscribe to GPS stream
    _gpsRepository.gpsStream.listen(
      (data) {
        _currentGpsData = data;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    // Cleanup subscriptions
    super.dispose();
  }
}
```

**Benefits:**
- Testable without widgets (mock repositories)
- Clear command pattern (toggleSpeedUnit vs callbacks)
- State changes trigger only necessary rebuilds
- Repository dependencies injected (testable, swappable)

### Recommended Pattern: Consumer Widget Usage

```dart
// speedometer_screen.dart (View only)
class SpeedometerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Only rebuild speed display when GPS data changes
          Consumer<SpeedometerViewModel>(
            builder: (context, viewModel, child) {
              if (viewModel.isLoading) {
                return CircularProgressIndicator();
              }

              if (viewModel.errorMessage != null) {
                return ErrorWidget(
                  message: viewModel.errorMessage!,
                  onRetry: viewModel.refreshGPS,
                );
              }

              return DigitalSpeedDisplay(
                speed: viewModel.gpsData?.displaySpeed ?? '--',
                unit: viewModel.currentUnit,
              );
            },
          ),

          // Static child (doesn't rebuild on every GPS update)
          Consumer<SpeedometerViewModel>(
            builder: (context, viewModel, child) {
              return SpeedUnitToggle(
                currentUnit: viewModel.currentUnit,
                onToggle: viewModel.toggleSpeedUnit,
              );
            },
          ),
        ],
      ),
    );
  }
}
```

**Benefits:**
- View is "dumb" - no business logic
- Consumer scoped to minimize rebuilds
- Clear separation: view renders, viewModel decides what to render
- Testable: mock ViewModel, verify UI rendering

### Recommended Pattern: Speed-Adaptive GPS Precision

```dart
// gps_repository.dart
class GpsRepository {
  static const double STATIONARY_THRESHOLD_MPS = 1.4; // ~5 km/h
  static const double MOVING_THRESHOLD_MPS = 8.3;     // ~30 km/h

  LocationAccuracy _currentAccuracy = LocationAccuracy.balanced;
  double _lastSpeed = 0.0;

  void _updateAccuracyBasedOnSpeed(double speedMps) {
    final previousAccuracy = _currentAccuracy;

    // State machine for accuracy switching
    if (speedMps < STATIONARY_THRESHOLD_MPS) {
      _currentAccuracy = LocationAccuracy.low; // PRIORITY_BALANCED_POWER_ACCURACY
    } else if (speedMps > MOVING_THRESHOLD_MPS) {
      _currentAccuracy = LocationAccuracy.best; // PRIORITY_HIGH_ACCURACY
    }
    // Hysteresis: stay in current mode if between thresholds

    // Only reconfigure GPS if accuracy changed
    if (previousAccuracy != _currentAccuracy) {
      _reconfigureGpsStream(_currentAccuracy);
      debugPrint('GPS accuracy changed: $previousAccuracy → $_currentAccuracy');
    }

    _lastSpeed = speedMps;
  }

  void _reconfigureGpsStream(LocationAccuracy accuracy) {
    // Cancel existing stream
    _gpsSubscription?.cancel();

    // Create new stream with updated accuracy
    final locationSettings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: accuracy == LocationAccuracy.best ? 5 : 50,
    );

    _gpsSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_handleGpsUpdate);
  }
}
```

**Benefits:**
- Automatic switching based on movement
- Hysteresis prevents rapid toggling
- Clear thresholds (can be tuned)
- Logs accuracy changes for debugging

### Recommended Pattern: Overlay Message Protocol

```dart
// overlay_messaging_service.dart
class OverlayMessagingService {
  static const Duration UPDATE_INTERVAL = Duration(milliseconds: 500);
  Timer? _broadcastTimer;

  void startBroadcasting(Stream<ProcessedGpsData> gpsStream) {
    // Debounced broadcast to prevent message flooding
    _broadcastTimer = Timer.periodic(UPDATE_INTERVAL, (_) async {
      final latestData = _latestGpsData;
      if (latestData != null) {
        await _sendToOverlay(latestData);
      }
    });

    // Subscribe to GPS stream
    gpsStream.listen((data) {
      _latestGpsData = data;
    });
  }

  Future<void> _sendToOverlay(ProcessedGpsData data) async {
    // Structured message format
    final message = jsonEncode({
      'type': 'gps_update',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': {
        'displaySpeed': data.displaySpeed,
        'displayHeading': data.displayHeading,
        'isSpeedValid': data.isSpeedValid,
        'isHeadingValid': data.isHeadingValid,
      },
    });

    try {
      await FlutterOverlayWindow.shareData(message);
    } catch (e) {
      debugPrint('Failed to send overlay message: $e');
      // Don't crash main app if overlay messaging fails
    }
  }

  void stopBroadcasting() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
  }
}
```

**Benefits:**
- Continuous updates (fixes stale data bug)
- Debounced to prevent message flooding (500ms = 2 updates/second)
- Structured JSON messages (extensible)
- Graceful failure handling (overlay may not be active)
- Timestamp allows overlay to detect stale messages

### Recommended Pattern: Overlay Scoped Provider

```dart
// overlay_main.dart (separate entry point)
@pragma("vm:entry-point")
void overlayMain() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => OverlayViewModel(), // Separate instance from main app
        ),
      ],
      child: MaterialApp(
        home: OverlayScreen(),
      ),
    ),
  );
}

// overlay_viewmodel.dart
class OverlayViewModel extends ChangeNotifier {
  ProcessedGpsData? _currentGpsData;
  DateTime? _lastUpdate;

  OverlayViewModel() {
    _startListening();
  }

  void _startListening() {
    // Listen for messages from main app
    FlutterOverlayWindow.overlayListener.listen((rawMessage) {
      try {
        final message = jsonDecode(rawMessage);

        if (message['type'] == 'gps_update') {
          _currentGpsData = ProcessedGpsData.fromJson(message['data']);
          _lastUpdate = DateTime.fromMillisecondsSinceEpoch(
            message['timestamp'],
          );
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Failed to parse overlay message: $e');
      }
    });
  }

  // Check if data is stale (no updates for 2+ seconds)
  bool get isDataStale {
    if (_lastUpdate == null) return true;
    return DateTime.now().difference(_lastUpdate!) > Duration(seconds: 2);
  }

  ProcessedGpsData? get gpsData => isDataStale ? null : _currentGpsData;
}
```

**Benefits:**
- Overlay has its own Provider scope (separate isolate)
- Reactive updates via overlayListener
- Stale data detection (shows "--" if no recent updates)
- No shared state between main app and overlay

---

## Complexity Assessment

| Pattern Category | Overall Complexity | Implementation Time | Risk |
|------------------|-------------------|---------------------|------|
| **MVVM Layer Separation** | Medium | 8-12 hours | Low - well-documented pattern |
| **Feature-First Structure** | Low | 4-6 hours | Low - file reorganization |
| **Provider Integration** | Medium | 6-8 hours | Medium - requires careful migration from setState |
| **Speed-Adaptive GPS** | High | 12-16 hours | Medium - requires testing on real devices |
| **Overlay Communication** | High | 16-20 hours | High - isolate debugging difficult |
| **WorkManager Background** | Medium | 6-8 hours | Medium - Android platform-specific |

**Total restructure estimate**: 52-70 hours (1.5-2 weeks full-time)

**Highest risk areas**:
1. Overlay communication - isolates cannot be debugged easily, requires extensive physical device testing
2. Speed-adaptive GPS - thresholds need real-world tuning, different Android versions behave differently
3. Provider migration - easy to miss setState calls, requires thorough testing

---

## Testing Strategy Implications

Well-structured architecture enables better testing:

### Unit Tests (Business Logic)
```dart
// Test ViewModel without Flutter framework
test('SpeedometerViewModel toggles speed unit', () {
  final mockGpsRepo = MockGpsRepository();
  final mockSettingsRepo = MockSettingsRepository();

  final viewModel = SpeedometerViewModel(
    gpsRepository: mockGpsRepo,
    settingsRepository: mockSettingsRepo,
  );

  viewModel.toggleSpeedUnit();

  verify(mockSettingsRepo.toggleSpeedUnit()).called(1);
});
```

### Widget Tests (UI)
```dart
// Test View rendering without business logic
testWidgets('SpeedometerScreen displays speed from ViewModel', (tester) async {
  final mockViewModel = MockSpeedometerViewModel();
  when(mockViewModel.gpsData).thenReturn(
    ProcessedGpsData(displaySpeed: '120', ...),
  );

  await tester.pumpWidget(
    ChangeNotifierProvider<SpeedometerViewModel>.value(
      value: mockViewModel,
      child: SpeedometerScreen(),
    ),
  );

  expect(find.text('120'), findsOneWidget);
});
```

### Integration Tests (End-to-End)
```dart
// Test GPS → ViewModel → View flow
testWidgets('GPS updates trigger UI updates', (tester) async {
  final realGpsRepo = GpsRepository(gpsService: FakeGpsService());

  await tester.pumpWidget(MyApp(gpsRepository: realGpsRepo));

  // Simulate GPS update
  realGpsRepo.injectFakePosition(speed: 50.0);
  await tester.pump();

  expect(find.text('50'), findsOneWidget);
});
```

**Current app**: Cannot unit test business logic (requires widget tests for everything). Cannot mock GPS (tightly coupled to hardware).

**Restructured app**: Business logic testable in isolation. Views testable with mocked ViewModels. Integration tests verify end-to-end flow.

---

## Conclusion

The restructure focuses on architectural patterns (HOW to structure), not new features (WHAT to build). Priority order:

1. **Foundation** (Feature-first + MVVM + Provider) - enables everything else
2. **GPS Optimization** (Speed-adaptive + WorkManager) - addresses battery drain
3. **Overlay Fix** (Message queue + Scoped providers) - resolves stale data bug

The current 1,133-line monolithic main.dart with raw setState and aggressive wake locks represents 2018-era Flutter development. The 2026 standard is MVVM with Provider/Riverpod, feature-first organization, adaptive GPS precision, and proper Android lifecycle management.

Key success metric: Main screen logic reduced from 1,133 lines to <200 lines per ViewModel. Business logic testable without Flutter framework. Overlay data stays fresh within 500ms of main app.

---

## Sources

### Flutter Architecture
- [Guide to app architecture - Flutter](https://docs.flutter.dev/app-architecture/guide)
- [Architecture design patterns - Flutter](https://docs.flutter.dev/app-architecture/design-patterns)
- [Modern Flutter Architecture Patterns - Medium](https://medium.com/@sharmapraveen91/modern-flutter-architecture-patterns-ed6882a11b7c)
- [Flutter Project Structure: Feature-first or Layer-first?](https://codewithandrea.com/articles/flutter-project-structure/)
- [Flutter App Architecture: The Repository Pattern](https://codewithandrea.com/articles/flutter-repository-pattern/)

### State Management
- [Best Flutter State Management Libraries 2026](https://foresightmobile.com/blog/best-flutter-state-management)
- [The Ultimate Guide to Flutter State Management in 2026](https://medium.com/@satishparmarparmar486/the-ultimate-guide-to-flutter-state-management-in-2026-from-setstate-to-bloc-riverpod-561192c31e1c)
- [State Management in Flutter: Provider vs Riverpod vs Bloc](https://ms3byoussef.medium.com/state-management-in-flutter-provider-vs-riverpod-vs-bloc-333795f0df22)
- [Flutter ChangeNotifier for Simplified State Management](https://www.dhiwise.com/post/fluidstate-management-with-flutter-changenotifier)

### Android Overlay Windows
- [flutter_overlay_window | Flutter package](https://pub.dev/packages/flutter_overlay_window)
- [system_alert_window | Flutter package](https://pub.dev/packages/system_alert_window)
- [Concurrency and isolates - Flutter](https://docs.flutter.dev/perf/isolates)

### GPS & Location Services
- [Change location settings - Android Developers](https://developer.android.com/develop/sensors-and-location/location/change-location-settings)
- [About background location and battery life - Android Developers](https://developer.android.com/develop/sensors-and-location/location/battery)
- [How to Implement Geolocation Without Draining Battery](https://metova.com/how-to-implement-geolocation-without-draining-your-users-battery/)
- [Improving urban GPS accuracy for your app - Android Developers Blog](https://android-developers.googleblog.com/2020/12/improving-urban-gps-accuracy-for-your.html)

### Background Work & Battery Optimization
- [Optimize your app battery using Android vitals wake lock metric](https://android-developers.googleblog.com/2025/09/guide-to-excessive-wake-lock-usage.html)
- [JobScheduler vs WorkManager - Medium](https://medium.com/@vaibhav.shakya786/jobscheduler-vs-workmanager-the-battle-for-androids-background-work-fcceec5cd6ff)
- [Replace Android Foreground Services with WorkManager](https://medium.com/@manish_bannur/replace-android-foreground-services-with-workmanager-a739f7c8ff76)

### Flutter Best Practices 2026
- [Best Practices to implement for Flutter App Development in 2026](https://www.manektech.com/blog/flutter-development-best-practices)
- [Flutter App Development in 2026: 8 Best Practices](https://otfcoder.com/flutter-app-development-best-practices-for-scalable-apps/)
- [Stop Doing These Flutter Performance Mistakes (2026 Edition)](https://medium.com/@tiger.chirag/stop-doing-these-flutter-performance-mistakes-2026-edition-79cae09d5f22)
