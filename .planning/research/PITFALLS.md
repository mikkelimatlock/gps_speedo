# Domain Pitfalls: Flutter GPS Speedometer Restructure

**Project:** GPS Speedometer — Monolith to Modular Restructure
**Domain:** Flutter app restructuring, Android overlay windows, GPS location tracking
**Researched:** 2026-02-09
**Confidence:** HIGH (based on Context7, official docs, recent 2025-2026 sources)

## Executive Summary

Restructuring a working Flutter GPS app from monolith to modular architecture carries high regression risk when the app has no automated tests. The critical pitfalls cluster around four areas: (1) Provider migration breaking async lifecycle patterns, (2) overlay communication becoming unreliable after modularization, (3) GPS stream subscription memory leaks, and (4) excessive battery drain from unconditional wake locks and timers. Each pitfall has early warning signs and specific prevention strategies.

## Critical Pitfalls

Mistakes that cause rewrites, regressions, or production failures.

---

### Pitfall 1: setState After Dispose During Provider Migration

**What goes wrong:**

When migrating from `setState()` to Provider's `ChangeNotifier`, async operations (Timers, Stream subscriptions, Future callbacks) that previously called `setState()` continue running after widget disposal, causing runtime crashes with "setState() called after dispose()" or "A ChangeNotifier was used after being disposed()".

**Why it happens:**

The monolithic code has multiple async patterns: GPS stream subscriptions, background heartbeat timer (5s), overlay status polling timer (1s), tap-close timer (500ms), and stale data timer (4s). These timers reference `this` or call `setState()` in callbacks. During restructuring, these get moved into ChangeNotifiers or Services without proper lifecycle management, causing disposal race conditions.

**Root cause from research:**

89% of Flutter performance issues stem from poor state management decisions made in early development phases. When migrating setState to Provider, developers often forget to check `mounted` property before calling setState or fail to cancel async operations in dispose().

**Consequences:**

- Silent failures in release mode (errors swallowed)
- Intermittent crashes during navigation/back button
- Memory leaks from uncanceled subscriptions holding references to disposed widgets
- Overlay state becoming unreliable after main app backgrounds/foregrounds

**Prevention strategies:**

1. **Audit all async patterns before restructuring:**
   ```dart
   // Current codebase has these async patterns to audit:
   // - _backgroundHeartbeatTimer (5s periodic)
   // - _overlayStatusCheckTimer (1s periodic)
   // - _tapCloseTimer (500ms one-shot)
   // - GpsDataManager._staleDataTimer (4s one-shot)
   // - _gpsSubscription (stream)
   // - _overlaySubscription (stream)
   ```

2. **Always check `mounted` before setState() during migration:**
   ```dart
   // BAD (current pattern in monolith):
   Timer.periodic(Duration(seconds: 5), (timer) {
     setState(() { /* update state */ });
   });

   // GOOD (migration-safe pattern):
   Timer.periodic(Duration(seconds: 5), (timer) {
     if (mounted) {
       setState(() { /* update state */ });
     }
   });
   ```

3. **Cancel ALL timers/subscriptions in dispose():**
   ```dart
   @override
   void dispose() {
     _gpsSubscription?.cancel();
     _overlaySubscription?.cancel();
     _backgroundHeartbeatTimer?.cancel();
     _overlayStatusCheckTimer?.cancel();
     _tapCloseTimer?.cancel();
     super.dispose(); // MUST call super.dispose()
   }
   ```

4. **For ChangeNotifier migration, override notifyListeners with disposal check:**
   ```dart
   class SafeNotifier extends ChangeNotifier {
     bool _disposed = false;

     @override
     void notifyListeners() {
       if (!_disposed) {
         super.notifyListeners();
       }
     }

     @override
     void dispose() {
       _disposed = true;
       super.dispose();
     }
   }
   ```

5. **Use ChangeNotifierProvider.value for existing instances:**
   - GpsDataManager is a singleton that survives widget rebuilds
   - Use `ChangeNotifierProvider.value(value: GpsDataManager.instance)` NOT `ChangeNotifierProvider(create:)`
   - Provider will NOT auto-dispose singletons when using `.value` constructor

**Detection (warning signs):**

- Console spam with `setState() called after dispose()` during testing
- App crashes when navigating back from speedometer screen
- Overlay stops updating after backgrounding main app
- Memory usage climbing during repeated navigation cycles
- Timers continuing to fire after screen disposal (check debug prints)

**Phase mapping:**

- **Phase 1 (Code Organization):** Low risk — just moving code, not changing lifecycle
- **Phase 2 (Provider Migration):** **CRITICAL RISK** — all async patterns must be audited
- **Phase 3 (Overlay Refactor):** High risk — overlay timers/subscriptions change
- **Phase 4 (GPS Optimization):** Medium risk — new adaptive precision logic adds async complexity

**Sources:**
- [How to Fix: SetState Called After Dispose](https://medium.com/@nehatanwar.dev/setstate-called-after-dispose-b022d6a7a4a7)
- [Understanding mounted in Flutter](https://medium.com/@athar.h1204/understanding-mounted-in-flutter-and-how-to-avoid-setstate-errors-4ddbba270e65)
- [Migrating to Provider: Flutter State Management](https://tillitsdone.com/blogs/flutter-provider-migration-guide/)
- [Flutter State Management: Going from setState to Provider](https://codewithandrea.com/videos/flutter-state-management-setstate-freezed-state-notifier-provider/)

---

### Pitfall 2: GPS Stream Subscription Memory Leaks

**What goes wrong:**

GPS stream subscriptions from geolocator package remain active after widget disposal, causing memory leaks, battery drain, and stale location requests running indefinitely in background.

**Why it happens:**

GpsDataManager creates a GPS stream subscription in `initialize()` but the subscription lifecycle is separate from widget lifecycle. Current code has `dispose()` method on GpsDataManager but **nothing calls it** — the singleton lives forever. During restructuring, if GPS subscriptions move into widget-scoped providers, forgetting to cancel them in dispose() causes leaks.

**Root cause from research:**

Disposable objects like StreamSubscriptions have a `dispose()` method. If not disposed when no longer needed, they remain in memory causing leaks because GC cannot automatically dispose them. Historical geolocator bugs on Android caused memory leaks when stopping position streams.

**Consequences:**

- Memory usage grows with each navigation cycle
- GPS hardware continues polling even when screen is off and no overlay
- Battery drain from continuous HIGH_ACCURACY location requests
- Location service icon persists in status bar even when app backgrounded
- Android vitals flags app for excessive wake lock usage (>2 hours in 24h)

**Prevention strategies:**

1. **Cancel stream subscriptions in dispose():**
   ```dart
   StreamSubscription<Position>? _gpsSubscription;

   @override
   void dispose() {
     _gpsSubscription?.cancel(); // CRITICAL
     _gpsSubscription = null;
     super.dispose();
   }
   ```

2. **Store subscriptions when creating them (initState pattern):**
   ```dart
   @override
   void initState() {
     super.initState();
     _mySubscription = myStream.listen((data) {
       // handle data
     });
   }
   ```

3. **For singleton GpsDataManager, implement proper lifecycle:**
   ```dart
   // Option A: Reference counting
   class GpsDataManager {
     int _refCount = 0;

     void addRef() {
       _refCount++;
       if (_refCount == 1) initialize();
     }

     void removeRef() {
       _refCount--;
       if (_refCount == 0) dispose();
     }
   }

   // Option B: Provider-managed lifecycle
   // Use ChangeNotifierProvider with create: (context) => GpsDataManager()
   // Provider will auto-dispose when no longer needed
   ```

4. **Stop GPS when not needed (smart background GPS):**
   ```dart
   @override
   void didChangeAppLifecycleState(AppLifecycleState state) {
     if (state == AppLifecycleState.paused && !_isOverlayActive) {
       _gpsSubscription?.pause(); // or cancel()
     } else if (state == AppLifecycleState.resumed) {
       _gpsSubscription?.resume(); // or re-subscribe
     }
   }
   ```

5. **Use Leak Tracker during development:**
   - Flutter's Leak Tracker (built-in since 2024) assists in preventing undisposed StreamSubscriptions, Timers, Controllers
   - Run app with `--track-widget-creation` flag for leak detection

**Detection (warning signs):**

- Memory profiler shows increasing Position objects over time
- GPS icon in Android status bar never disappears
- Battery usage shows high "Location" percentage
- Console logs show GPS updates continuing after screen navigation
- Android vitals dashboard flags excessive wake lock usage
- App backgrounded but location service notification persists

**Phase mapping:**

- **Phase 1 (Code Organization):** Low risk — GpsDataManager already exists and has dispose()
- **Phase 2 (Provider Migration):** **HIGH RISK** — must ensure GpsDataManager.dispose() gets called
- **Phase 3 (Overlay Refactor):** Medium risk — overlay closure should trigger GPS stop
- **Phase 4 (GPS Optimization):** **HIGH RISK** — adaptive precision adds pause/resume logic

**Sources:**
- [Geolocator Stream Subscription Memory Leak](https://github.com/Baseflow/flutter-geolocator/issues/1682)
- [Let's Talk About Memory Leaks In Dart And Flutter](https://dcm.dev/blog/2024/10/21/lets-talk-about-memory-leaks-in-dart-and-flutter/)
- [Critical Stream Subscription Management in Flutter](https://saropa-contacts.medium.com/critical-stream-subscription-management-in-flutter-with-isar-prevent-memory-leaks-and-performance-30f4847a5baa)

---

### Pitfall 3: Overlay Communication Breaking After Modularization

**What goes wrong:**

After extracting overlay logic from SpeedometerScreen into separate service/provider, overlay↔main communication becomes unreliable: data stops flowing, overlay shows stale speed, overlay ignores close commands, or overlay crashes silently.

**Why it happens:**

`flutter_overlay_window 0.5.0` has known issues with bidirectional communication — specifically, `shareData` from overlay→main is "fundamentally broken" according to project context. The overlay runs in a separate isolate with separate memory space. Current workaround uses polling (1s timer checking overlay status) instead of message-based detection. During restructuring, moving message-passing logic breaks these fragile workarounds.

**Root cause from research:**

Different engines run on different threads and cannot communicate directly — sharing data is the only way to communicate between window engines. Isolates have isolated memory and do not share state, only communicate by message passing. Data being shared must be serializable. Current implementation uses unvalidated Map data with no type safety.

**Consequences:**

- Overlay shows "0.0" speed while main app shows real speed
- Overlay ignores close button taps (HapticFeedback hangs in overlay context)
- Long-press overlay close unreliable on subsequent launches
- Main app thinks overlay is closed but it's still visible
- Theme/unit sync stops working between main↔overlay
- Silent failures with no user feedback (errors caught and swallowed)

**Prevention strategies:**

1. **Define typed message schema BEFORE refactoring:**
   ```dart
   // Replace unvalidated Map with typed messages
   class OverlayMessage {
     final String type; // 'speed_update' | 'close_request' | 'settings_sync'
     final Map<String, dynamic> payload;

     OverlayMessage(this.type, this.payload);

     Map<String, dynamic> toJson() => {'type': type, 'payload': payload};
     factory OverlayMessage.fromJson(Map<String, dynamic> json) =>
       OverlayMessage(json['type'], json['payload']);
   }
   ```

2. **Validate ALL data at boundaries:**
   ```dart
   // BAD (current pattern):
   FlutterOverlayWindow.shareData(data); // unvalidated Map

   // GOOD (migration pattern):
   void shareDataSafe(OverlayMessage message) {
     try {
       final json = message.toJson();
       FlutterOverlayWindow.shareData(json);
     } catch (e) {
       print('[Overlay] Failed to share data: $e');
       // Show user-visible error
     }
   }
   ```

3. **Surface overlay errors to user (don't swallow):**
   ```dart
   // BAD (current pattern):
   try {
     await FlutterOverlayWindow.showOverlay(...);
   } catch (e) {
     print('Error: $e'); // Silent failure
   }

   // GOOD (restructure pattern):
   try {
     await FlutterOverlayWindow.showOverlay(...);
   } catch (e) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('Overlay failed: $e'))
     );
   }
   ```

4. **Verify overlay creation succeeded before setting flags:**
   ```dart
   // BAD (current pattern):
   await FlutterOverlayWindow.showOverlay(...);
   _isOverlayActive = true; // Assumes success

   // GOOD (restructure pattern):
   final success = await FlutterOverlayWindow.showOverlay(...);
   if (success == true) {
     _isOverlayActive = true;
   } else {
     // Show error, don't set flag
   }
   ```

5. **Avoid HapticFeedback in overlay context:**
   ```dart
   // HapticFeedback.lightImpact() hangs indefinitely in overlay
   // Move haptics to main app only, or use try-timeout pattern
   ```

6. **Consider flutter_overlay_window_plus (fork with fixes):**
   - Released July 2025, addresses communication reliability issues
   - Better isolate message passing implementation
   - Still requires serializable data

**Detection (warning signs):**

- Overlay speed freezes at last value while moving
- Console shows `[Overlay] shareData called` but no corresponding receive
- Overlay close button does nothing
- Main app shows overlay closed but overlay persists on screen
- Theme changes in main app don't reflect in overlay
- Overlay relaunch shows old/cached data instead of current

**Phase mapping:**

- **Phase 1 (Code Organization):** Low risk — overlay code stays in place
- **Phase 2 (Provider Migration):** Medium risk — message passing logic moves
- **Phase 3 (Overlay Refactor):** **CRITICAL RISK** — all communication patterns change
- **Phase 4 (GPS Optimization):** Low risk — GPS data already flows through manager

**Sources:**
- [flutter_overlay_window Issues](https://github.com/X-SLAYER/flutter_overlay_window/issues)
- [I can't display my data on the overlay window](https://github.com/X-SLAYER/flutter_overlay_window/issues/115)
- [flutter_overlay_window_plus (2025 fork with fixes)](https://pub.dev/packages/flutter_overlay_window_plus)
- [Concurrency and isolates - Flutter docs](https://docs.flutter.dev/perf/isolates)

---

### Pitfall 4: Excessive Battery Drain From Unconditional Background Timers

**What goes wrong:**

Background heartbeat timer fires every 5 seconds unconditionally, overlay status polling timer fires every 1 second when overlay active, and GPS requests continuous HIGH_ACCURACY location — all causing Android vitals to flag app for excessive battery drain, potentially removing app from Play Store prominent placements.

**Why it happens:**

Current implementation starts timers/GPS without conditional logic for when they're needed:
- Heartbeat timer runs even when app in foreground with no overlay (unnecessary)
- Overlay polling runs even when overlay definitely active (workaround overkill)
- HIGH_ACCURACY GPS runs even when stationary (<1 km/h)
- Wake locks held continuously instead of only when tracking with overlay

**Root cause from research:**

Android introduced excessive partial wake locks metric in 2025, with threshold of 2+ cumulative hours in 24h period. Starting March 2026, apps exceeding 5% bad sessions may be excluded from Play Store recommendations with battery drain warning on listing. Flutter apps commonly trigger this by holding wake locks during foreground services unnecessarily.

**Consequences:**

- Android vitals flags app for excessive battery usage
- Play Store displays battery drain warning on app listing
- Users complain about battery percentage dropping rapidly
- App removed from "Editor's Choice" / "Recommended" sections
- Location service wake lock persists 24/7 even when not tracking
- Unnecessary CPU wake-ups every 1-5 seconds

**Prevention strategies:**

1. **Stop heartbeat timer when not needed:**
   ```dart
   // ONLY run heartbeat when: (backgrounded AND overlay active)
   void _updateHeartbeatTimer() {
     final needsHeartbeat = _isInBackground && _isOverlayActive;

     if (needsHeartbeat && _backgroundHeartbeatTimer == null) {
       _backgroundHeartbeatTimer = Timer.periodic(
         Duration(seconds: 5),
         _handleHeartbeat
       );
     } else if (!needsHeartbeat && _backgroundHeartbeatTimer != null) {
       _backgroundHeartbeatTimer?.cancel();
       _backgroundHeartbeatTimer = null;
     }
   }
   ```

2. **Replace overlay polling with event-based detection:**
   ```dart
   // Current pattern: 1s timer checking FlutterOverlayWindow.isActive()
   // Better pattern: Subscribe to overlay lifecycle events if available
   // Or: Accept that polling is workaround, but make it 5s not 1s
   ```

3. **Speed-adaptive GPS precision (8/12 km/h hysteresis):**
   ```dart
   void _updateGpsAccuracy(double currentSpeed) {
     final shouldUseHighAccuracy = currentSpeed > 12.0; // km/h
     final shouldUseLowAccuracy = currentSpeed < 8.0;   // hysteresis

     if (shouldUseHighAccuracy && _currentAccuracy != LocationAccuracy.best) {
       _switchToHighAccuracy();
     } else if (shouldUseLowAccuracy && _currentAccuracy != LocationAccuracy.balanced) {
       _switchToBalancedPower();
     }
   }
   ```

4. **Stop GPS completely when overlay closed:**
   ```dart
   void _handleOverlayClosed() {
     _isOverlayActive = false;
     _gpsSubscription?.pause(); // or cancel()
     WakelockPlus.disable(); // Release wake lock
     _backgroundHeartbeatTimer?.cancel();
   }
   ```

5. **Cache overlay size calculation:**
   ```dart
   // BAD (current pattern):
   Map<String, int> _getOverlaySize() {
     final window = WidgetsBinding.instance.platformDispatcher.views.first;
     // ... calculation on every call
   }

   // GOOD (restructure pattern):
   Map<String, int>? _cachedOverlaySize;
   Map<String, int> _getOverlaySize() {
     return _cachedOverlaySize ??= _calculateOverlaySize();
   }
   ```

**Detection (warning signs):**

- Android vitals dashboard shows >5% excessive wake lock sessions
- Battery historian shows continuous wake locks during screen-off
- Location service notification persists even when not actively navigating
- App consumes >5% battery in 1-hour idle period
- ADB logcat shows timer wake-ups every 1-5 seconds
- GPS icon in status bar never disappears

**Phase mapping:**

- **Phase 1 (Code Organization):** Low risk — timers stay as-is
- **Phase 2 (Provider Migration):** Low risk — timer logic doesn't change
- **Phase 3 (Overlay Refactor):** **HIGH RISK** — must add conditional timer logic
- **Phase 4 (GPS Optimization):** **CRITICAL RISK** — adaptive precision core feature

**Sources:**
- [Android Excessive Wake Lock Metric (2025)](https://android-developers.googleblog.com/2025/09/guide-to-excessive-wake-lock-usage.html)
- [Excessive partial wake locks - Android Developers](https://developer.android.com/topic/performance/vitals/excessive-wakelock)
- [Android Addressing Battery Drain with Wake Locks Metric](https://9to5google.com/2025/04/15/android-excessive-battery-drain-wake-locks/)
- [Advanced Location Tracking in Flutter: Complete 2026 Guide](https://medium.com/@ali.mohamed.hgr/advanced-location-tracking-in-flutter-the-complete-2026-guide-cce138f2d558)

---

### Pitfall 5: Singleton Thread Safety Assumptions Breaking With Isolates

**What goes wrong:**

GpsDataManager singleton uses lazy initialization (`_instance ??= GpsDataManager._internal()`) which is NOT thread-safe if accessed from multiple isolates. Overlay runs in separate isolate — if overlay tries to access singleton directly, either gets separate instance (data desync) or race condition on initialization.

**Why it happens:**

Dart's single-threaded nature makes basic singleton implementation safe for single-isolate apps. But overlay window runs in separate isolate with separate heap. Current implementation assumes single isolate but doesn't document or enforce this constraint.

**Consequences:**

- Overlay creates separate GpsDataManager instance with no GPS data
- Race condition if main + overlay both call `GpsDataManager.instance` during startup
- Data changes in main app's singleton don't reflect in overlay's separate instance
- Two GPS stream subscriptions running (one per isolate) doubling battery drain
- Confusing debug logs showing duplicate initialization

**Prevention strategies:**

1. **Document single-isolate constraint:**
   ```dart
   /// GpsDataManager singleton.
   ///
   /// WARNING: This singleton is NOT thread-safe across isolates.
   /// Each isolate gets its own instance. Do NOT access directly from
   /// overlay isolate — use message passing instead.
   class GpsDataManager { ... }
   ```

2. **If multi-isolate access needed, use synchronized package:**
   ```dart
   import 'package:synchronized/synchronized.dart';

   class GpsDataManager {
     static GpsDataManager? _instance;
     static final _lock = Lock();

     static Future<GpsDataManager> get instance async {
       return await _lock.synchronized(() {
         return _instance ??= GpsDataManager._internal();
       });
     }
   }
   ```

3. **Better: Enforce single-isolate architecture:**
   ```dart
   // GPS lives in main isolate only
   // Overlay receives GPS data via message passing
   // Overlay NEVER accesses GpsDataManager directly
   ```

4. **Add runtime isolate check:**
   ```dart
   class GpsDataManager {
     final String _isolateId = Isolate.current.debugName ?? 'main';

     GpsDataManager._internal() {
       if (_isolateId != 'main') {
         throw StateError(
           'GpsDataManager should only be created in main isolate. '
           'Current: $_isolateId'
         );
       }
     }
   }
   ```

**Detection (warning signs):**

- Console shows multiple "GPS manager initialized" logs
- Overlay shows no GPS data despite main app showing speed
- GPS battery usage doubles unexpectedly
- Two location service notifications appear
- Debug logs show different instance hashCodes

**Phase mapping:**

- **Phase 1 (Code Organization):** Low risk — singleton stays in main isolate
- **Phase 2 (Provider Migration):** Low risk — Provider enforces widget tree scope
- **Phase 3 (Overlay Refactor):** **MEDIUM RISK** — must clarify isolate boundaries
- **Phase 4 (GPS Optimization):** Low risk — GPS stays in main isolate

**Sources:**
- [Singleton Pattern in Flutter: How and When To Use It](https://medium.com/@rk0936626/singleton-pattern-in-flutter-how-and-when-to-use-it-4632aad76bef)
- [Mastering the Singleton Pattern in Dart](https://medium.com/@hpatilabhi10/mastering-the-singleton-design-pattern-in-dart-40adb7dd87ec)
- [Singletons in Flutter: How to Avoid Them](https://codewithandrea.com/articles/flutter-singletons/)

---

## Moderate Pitfalls

Mistakes that cause delays or technical debt but are fixable.

---

### Pitfall 6: ChangeNotifier Excessive Rebuilds After Provider Migration

**What goes wrong:**

After migrating to Provider, every `notifyListeners()` call rebuilds ALL Consumer widgets, even if the specific data they depend on hasn't changed. This causes UI jank, dropped frames, and poor performance — especially problematic for GPS updates at 1Hz+ refresh rate.

**Why it happens:**

ChangeNotifier broadcasts to all listeners indiscriminately. If SpeedometerProvider has speed, heading, unit, theme, overlayActive as properties, changing theme triggers rebuilds of speed display widgets unnecessarily.

**Consequences:**

- Dropped frames during GPS updates (FPS drops below 60)
- UI lag when cycling theme/unit
- Battery drain from excessive widget rebuilds
- Analog gauge animation stutters
- Poor user experience despite correct data

**Prevention strategies:**

1. **Use Selector instead of Consumer for targeted rebuilds:**
   ```dart
   // BAD: Rebuilds on ANY notifyListeners()
   Consumer<SpeedometerProvider>(
     builder: (context, provider, child) => Text('${provider.speed}')
   )

   // GOOD: Rebuilds only when speed changes
   Selector<SpeedometerProvider, double>(
     selector: (context, provider) => provider.speed,
     builder: (context, speed, child) => Text('$speed')
   )
   ```

2. **Place Consumer widgets deep in tree:**
   ```dart
   // Wrap only the Text widget that needs updates, not entire Column
   Column(
     children: [
       SomeStaticHeader(),
       Consumer<SpeedometerProvider>(
         builder: (context, provider, child) => Text('${provider.speed}')
       ),
       SomeStaticFooter(),
     ]
   )
   ```

3. **Split large ChangeNotifiers:**
   ```dart
   // Instead of one SpeedometerProvider with everything:
   class GpsDataProvider extends ChangeNotifier { /* speed, heading */ }
   class SettingsProvider extends ChangeNotifier { /* theme, unit */ }
   class OverlayProvider extends ChangeNotifier { /* overlayActive */ }
   ```

4. **Check before notifying:**
   ```dart
   void updateSpeed(double newSpeed) {
     if (_speed == newSpeed) return; // Skip notification
     _speed = newSpeed;
     notifyListeners();
   }
   ```

5. **Use child parameter for static subtrees:**
   ```dart
   Consumer<SpeedometerProvider>(
     builder: (context, provider, child) {
       return Column(
         children: [
           Text('${provider.speed}'), // Dynamic
           child!, // Static subtree never rebuilds
         ]
       );
     },
     child: ExpensiveStaticWidget(),
   )
   ```

**Detection (warning signs):**

- Flutter DevTools Performance tab shows frequent widget rebuilds
- Timeline shows jank during GPS updates
- FPS counter drops below 60 during speed changes
- Debug prints show rebuilds when unrelated state changes

**Phase mapping:**

- **Phase 2 (Provider Migration):** **HIGH RISK** — initial naive Consumer use
- **Phase 3 (Overlay Refactor):** Medium risk — overlay state changes trigger rebuilds

**Sources:**
- [Simple app state management - Flutter docs](https://docs.flutter.dev/data-and-backend/state-mgmt/simple)
- [ChangeNotifier is not selective for consumer](https://github.com/rrousselGit/provider/issues/231)
- [Flutter Performance Series: Optimizing State Management](https://medium.com/flutterdude/flutter-performance-series-optimizing-state-management-asynchronous-operations-e2eac2315ba9)

---

### Pitfall 7: Manual Regression Testing Missing Edge Cases

**What goes wrong:**

Without automated tests, restructuring relies on manual regression testing. Manual testing misses edge cases like "background app → revoke overlay permission → foreground app" or "GPS disabled → enable → race condition in subscription restart".

**Why it happens:**

App has zero unit/widget/integration tests. Project context explicitly states "no tests, regressions are manual-detection-only". Manual testing follows happy path (start app → see speed → close app) and misses error paths, lifecycle transitions, permission changes, and race conditions.

**Consequences:**

- Regressions ship to production
- User reports bugs that "never happened during testing"
- Permission errors silently swallowed
- Overlay gets stuck on screen with no close mechanism
- App crashes only on specific Android versions/devices
- Background service leaks discovered months later

**Prevention strategies:**

1. **Create manual test checklist BEFORE restructuring:**
   ```
   Functional Tests:
   - [ ] Start app with GPS disabled → enable GPS → see speed
   - [ ] Start app with location permission denied → grant → see speed
   - [ ] Start app with overlay permission denied → grant → tap nav icon
   - [ ] Open overlay → minimize app → overlay stays visible
   - [ ] Open overlay → long-press nav area → overlay closes
   - [ ] Open overlay → tap overlay close button → overlay closes
   - [ ] Change theme while overlay open → theme syncs
   - [ ] Change unit while overlay open → unit syncs
   - [ ] Open overlay → revoke overlay permission → no crash
   - [ ] GPS fix → move to indoor → stale data timeout → shows "--"
   - [ ] Stop moving → speed shows "--" (low speed threshold)
   - [ ] Rotate device → layout adjusts
   - [ ] Background app → foreground → GPS reconnects
   - [ ] Kill app → restart → settings persist (wait, they don't — out of scope)

   Performance Tests:
   - [ ] Leave app running 30 min → no memory leak
   - [ ] Leave overlay running 30 min → no battery drain warning
   - [ ] Check Android vitals → no excessive wake lock flags
   - [ ] Navigate away/back 20 times → no memory increase

   Error Tests:
   - [ ] Disable GPS during active tracking → error message
   - [ ] Revoke location permission during tracking → error message
   - [ ] Force-stop location service → graceful degradation
   ```

2. **Add defensive error surfacing:**
   ```dart
   // Catch and DISPLAY errors, don't swallow them
   void _handleError(String context, dynamic error) {
     print('[$context] Error: $error');
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('$context failed: $error'),
         duration: Duration(seconds: 5),
       )
     );
   }
   ```

3. **Use debug assertions liberally:**
   ```dart
   assert(_gpsSubscription != null, 'GPS subscription null during update');
   assert(!_disposed, 'Method called after dispose');
   ```

4. **Test on MULTIPLE devices:**
   - Different Android versions (11, 12, 13, 14, 15)
   - Different OEMs (Samsung, Xiaomi, OnePlus — aggressive battery optimization)
   - Different screen densities
   - Different GPS hardware quality

5. **Consider adding smoke test suite post-restructure:**
   ```dart
   // Even basic widget tests catch regressions
   testWidgets('Speed displays when GPS active', (tester) async {
     await tester.pumpWidget(SpeedoApp());
     expect(find.text('--'), findsOneWidget); // Initial state
     // Inject mock GPS data
     expect(find.textContaining('km/h'), findsOneWidget);
   });
   ```

**Detection (warning signs):**

- User reports bugs not seen during development
- Different behavior on physical device vs emulator
- Issues only reproducible on specific Android versions
- Crashes in release build but not debug build
- Battery drain reports after release

**Phase mapping:**

- **ALL PHASES:** Continuous risk — manual testing after each phase
- **Phase 2 (Provider Migration):** High risk — many state transitions
- **Phase 3 (Overlay Refactor):** High risk — complex lifecycle interactions

**Sources:**
- [Why Automated Regression Testing Matters For Flutter Apps](https://www.abcmoney.co.uk/2026/01/why-automated-regression-testing-matters-for-flutter-apps-in-fast-moving-industries)
- [Flutter Unit Testing: All You Need to Know in 2026](https://www.bacancytechnology.com/blog/flutter-unit-testing)
- [Regression Testing in Agile Reduces Bugs in 2026](https://www.aiotests.com/blog/regression-testing-in-agile)

---

### Pitfall 8: Permission State Changes Not Handled At Runtime

**What goes wrong:**

User grants overlay permission → opens overlay → backgrounds app → revokes overlay permission in Settings → foregrounds app → app crashes or overlay gets stuck because permission state change not handled.

**Why it happens:**

Permission checks happen once at overlay creation. App assumes permission persists for entire session. Android 11+ allows runtime permission revocation even for previously-granted permissions.

**Consequences:**

- App crashes when trying to update overlay after permission revoked
- Overlay remains visible even after permission revoked (zombie overlay)
- No user feedback explaining why overlay stopped working
- SecurityException crashes in production

**Prevention strategies:**

1. **Check permission before EVERY overlay operation:**
   ```dart
   Future<void> updateOverlay(String data) async {
     final hasPermission = await Permission.systemAlertWindow.isGranted;
     if (!hasPermission) {
       _handlePermissionRevoked();
       return;
     }

     try {
       await FlutterOverlayWindow.shareData(data);
     } catch (e) {
       if (e.toString().contains('permission')) {
         _handlePermissionRevoked();
       }
     }
   }
   ```

2. **Handle permission revocation gracefully:**
   ```dart
   void _handlePermissionRevoked() {
     setState(() {
       _isOverlayActive = false;
     });
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('Overlay permission revoked. Please re-enable in Settings.'))
     );
   }
   ```

3. **Re-check permission on app resume:**
   ```dart
   @override
   void didChangeAppLifecycleState(AppLifecycleState state) {
     if (state == AppLifecycleState.resumed && _isOverlayActive) {
       _verifyOverlayPermission();
     }
   }
   ```

4. **Wrap all overlay calls in try-catch:**
   ```dart
   try {
     await FlutterOverlayWindow.showOverlay(...);
   } on PlatformException catch (e) {
     if (e.code == 'PERMISSION_DENIED') {
       _handlePermissionRevoked();
     } else {
       rethrow;
     }
   }
   ```

**Detection (warning signs):**

- Crashes with "SecurityException: Permission Denial"
- Overlay stops updating but no error message shown
- Console shows permission errors but UI shows no feedback

**Phase mapping:**

- **Phase 3 (Overlay Refactor):** **MEDIUM RISK** — overlay service needs checks
- **Phase 4 (GPS Optimization):** Low risk — GPS permission separate concern

**Sources:**
- [Permissions updates in Android 11](https://developer.android.com/about/versions/11/privacy/permissions)
- [Resolving the PermissionHandler Error in Flutter](https://copyprogramming.com/howto/how-to-solve-permissionhandler-error-in-flutter)
- [Android 15 App Permission Changes](https://www.creolestudios.com/android-15-app-permission-changes/)

---

## Minor Pitfalls

Mistakes that cause annoyance but are easily fixable.

---

### Pitfall 9: Debug Print Statements Polluting Production Logs

**What goes wrong:**

After restructuring, excessive debug prints make production logs unreadable, hide real errors, and cause performance overhead from string formatting.

**Why it happens:**

Current codebase has heavy debug logging (every GPS update, every stream broadcast, every timer fire). During restructuring, more debug prints get added to track flow. No cleanup before release.

**Prevention:**

- Use `customDebugPrint()` helper (already exists) — only prints in debug mode
- Replace `print()` with `debugPrint()` for auto-stripping in release
- Add log levels: `[DEBUG]`, `[INFO]`, `[ERROR]`
- Remove or comment verbose logs before production build

**Detection:**

- Release build logcat flooded with messages
- Performance profiling shows time spent in print statements

**Phase mapping:**

- **All phases:** Continuous cleanup task

---

### Pitfall 10: Hardcoded Magic Numbers Scattered During Refactor

**What goes wrong:**

Timer durations (5s, 1s, 500ms, 4s), GPS thresholds (1.0 m/s, 10 km/h), overlay size percentages (45%, 60%) remain hardcoded magic numbers scattered across multiple files after modularization.

**Prevention:**

- Create constants file during Phase 1:
  ```dart
  // lib/constants.dart
  class AppConstants {
    static const heartbeatInterval = Duration(seconds: 5);
    static const overlayPollInterval = Duration(seconds: 1);
    static const staleDataTimeout = Duration(seconds: 4);
    static const speedThresholdDisplay = 1.0; // m/s
    static const speedThresholdHighAccuracy = 12.0; // km/h
    static const speedThresholdLowAccuracy = 8.0; // km/h
    static const overlayWidthPercent = 0.45;
    static const overlayAspectRatio = 0.6; // height/width
  }
  ```

**Detection:**

- During code review, spot numbers without context
- Difficulty adjusting values requires multi-file search

**Phase mapping:**

- **Phase 1 (Code Organization):** Create constants file immediately

---

## Phase-Specific Risk Matrix

| Phase | Critical Risks | Moderate Risks | Mitigation Priority |
|-------|---------------|----------------|---------------------|
| **Phase 1: Code Organization** | None | Magic numbers (#10) | Low — just moving code |
| **Phase 2: Provider Migration** | setState after dispose (#1)<br>GPS stream leaks (#2)<br>Excessive rebuilds (#6) | Manual regression gaps (#7) | **CRITICAL** — audit all async patterns first |
| **Phase 3: Overlay Refactor** | Overlay communication breaks (#3)<br>Battery drain from timers (#4) | Permission runtime changes (#8) | **HIGH** — define message schema first |
| **Phase 4: GPS Optimization** | Battery drain from adaptive GPS (#4)<br>GPS stream leaks (#2) | None | **HIGH** — test battery usage thoroughly |

---

## Confidence Assessment

| Pitfall Category | Confidence Level | Rationale |
|-----------------|------------------|-----------|
| Provider migration lifecycle | **HIGH** | Multiple 2025-2026 sources, official Flutter docs, established patterns |
| GPS stream memory leaks | **HIGH** | Geolocator package issues tracker, official Dart docs, DCM memory leak analysis |
| Overlay communication reliability | **MEDIUM** | flutter_overlay_window GitHub issues confirm problems, but solutions vary |
| Battery drain detection/prevention | **HIGH** | Android official blog posts (2025), vitals documentation, enforcement starting 2026 |
| Singleton thread safety | **MEDIUM** | Dart isolate docs clear, but app-specific isolate usage needs validation |
| Manual testing gaps | **HIGH** | Industry consensus 2026, multiple testing framework sources |
| Permission runtime changes | **MEDIUM** | Android 11+ docs confirm, but Flutter-specific handling less documented |

---

## Research Gaps

Areas where research was inconclusive or needs phase-specific investigation:

1. **flutter_overlay_window 0.5.0 specific limitations:**
   - Project context mentions "shareData fundamentally broken" but GitHub issues are vague
   - Need to test overlay→main communication thoroughly during Phase 3
   - Consider flutter_overlay_window_plus fork (2025) as alternative

2. **GpsDataManager singleton lifecycle:**
   - Currently nothing calls `dispose()` on singleton
   - Need to decide: Reference counting? Provider-managed? App-global?
   - Research needed on cleanest Provider + Singleton pattern

3. **Optimal GPS accuracy switching thresholds:**
   - Project spec says ~10 km/h with 8/12 hysteresis
   - Need field testing to validate battery vs responsiveness tradeoff
   - Android Fused Location Provider behavior varies by OEM

4. **Overlay status polling alternative:**
   - Current 1s polling is workaround for broken message-based detection
   - Is there event-based alternative? Or accept polling at 5s instead?
   - Research flutter_overlay_window_plus event support

---

## Sources Summary

**Primary sources (HIGH confidence):**
- [Android Developers Blog: Excessive Wake Lock Metric (2025)](https://android-developers.googleblog.com/2025/09/guide-to-excessive-wake-lock-usage.html)
- [Flutter Official Docs: Simple State Management](https://docs.flutter.dev/data-and-backend/state-mgmt/simple)
- [DCM: Memory Leaks in Dart and Flutter (2024)](https://dcm.dev/blog/2024/10/21/lets-talk-about-memory-leaks-in-dart-and-flutter/)
- [Advanced Location Tracking in Flutter: Complete 2026 Guide](https://medium.com/@ali.mohamed.hgr/advanced-location-tracking-in-flutter-the-complete-2026-guide-cce138f2d558)

**Secondary sources (MEDIUM confidence):**
- [flutter_overlay_window GitHub Issues](https://github.com/X-SLAYER/flutter_overlay_window/issues)
- [Geolocator GitHub Issues](https://github.com/Baseflow/flutter-geolocator/issues)
- [Medium: Singleton Pattern in Flutter (2024-2025)](https://medium.com/@rk0936626/singleton-pattern-in-flutter-how-and-when-to-use-it-4632aad76bef)

**Supplementary sources:**
- Multiple Medium articles on Provider migration best practices
- Stack Overflow discussions on setState after dispose patterns
- Flutter Community blog posts on ChangeNotifier optimization

---

*Research completed: 2026-02-09*
*Domain: Flutter restructuring, Android overlay windows, GPS location services*
*Target audience: Roadmap creator, phase planners*
