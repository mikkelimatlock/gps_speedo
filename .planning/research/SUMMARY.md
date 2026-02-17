# Project Research Summary

**Project:** GPS Speedometer - Monolith to Modular Architecture Restructure
**Domain:** Flutter mobile application restructuring
**Researched:** 2026-02-09
**Confidence:** HIGH

## Executive Summary

The GPS Speedometer app requires restructuring from a 1,133-line monolithic main.dart with raw setState into a modern 2026 Flutter architecture using Provider state management, MVVM layer separation, and feature-based organization. Research reveals that the current approach is 2018-era Flutter that suffers from untestable business logic, memory leaks from uncanceled subscriptions, and aggressive battery drain from continuous HIGH_ACCURACY GPS and wake locks. The recommended path forward prioritizes architectural foundation first (Provider migration, widget extraction, service layer), then GPS optimization (adaptive precision, lifecycle-aware tracking), and finally overlay communication fixes (message protocol, isolate-aware state management).

The critical insight is that this is fundamentally a restructuring project, not a feature-addition project. The restructure must preserve all existing functionality while enabling future maintainability. The highest risks cluster around Provider migration breaking async lifecycle patterns (setState after dispose, stream subscription leaks), and overlay communication becoming unreliable due to isolate boundaries and fragile message passing. Both have clear prevention strategies: audit all async patterns before migration, use typed message schemas, and implement defensive error handling throughout.

Success requires disciplined manual regression testing (no automated tests exist), careful attention to Android lifecycle management (backgrounding, permission revocation, GPS duty-cycling), and battery optimization to avoid Google Play Store penalties for excessive wake lock usage (new enforcement starting 2026). The restructure is estimated at 52-70 hours with Phase 2 (Provider Migration) and Phase 3 (Overlay Refactor) carrying the highest regression risk.

## Key Findings

### Recommended Stack

The restructure requires NO new major dependencies beyond adding `provider: ^6.1.0` which is already in pubspec.yaml but not fully utilized. The existing stack (Flutter 3.24+, geolocator 14.0.2, flutter_overlay_window 0.5.0, wakelock_plus 1.2.8) is adequate but used incorrectly. The focus is leveraging existing packages properly rather than introducing new ones.

**Core technologies:**
- **Provider 6.1.x**: UI state management — Official Flutter recommendation for simple-to-moderate state. Already in dependencies but unused. Replaces raw setState with ChangeNotifier pattern for reactive UI updates. Sufficient for app's complexity (Riverpod migration would be scope creep despite community preference in 2026).
- **Geolocator 14.0.2**: GPS position stream — Already integrated with Android 14+ FOREGROUND_SERVICE_LOCATION support. Critical feature: LocationSettings for adaptive precision control (HIGH_ACCURACY when moving fast, BALANCED_POWER_ACCURACY when stationary). Must use AndroidSettings.intervalDuration pattern (old desiredAccuracy deprecated).
- **flutter_overlay_window 0.5.0**: System-level overlay — Already integrated but PROBLEMATIC. Known reliability issues with bidirectional communication, data staleness, and Android version inconsistency. Keep package but isolate with architectural patterns: one-way message flow, typed schemas, defensive error handling. Do NOT replace (alternatives have same limitations).
- **MVVM Architecture Pattern**: Layer separation — Official Flutter 2026 architecture guide. View → ViewModel → Repository → Service. No domain layer needed (single-screen app). Layer-first directory structure appropriate (feature-first overkill for limited features).

**Critical stack decision:** Use Provider with existing packages, not BLoC (overkill) or Riverpod (scope creep). Isolate overlay communication issues architecturally (typed messages, one-way flow) rather than switching packages.

### Expected Features

This is a restructuring project focused on HOW features are structured, not WHAT features to add. The goal is preserving existing functionality while enabling maintainability, testability, and battery optimization.

**Must have (table stakes - preserve existing):**
- MVVM layer separation — View/ViewModel/Repository/Service distinct responsibilities
- Provider integration — Replace setState with ChangeNotifier + Consumer pattern
- Repository pattern — GpsDataManager as single source of truth for GPS data
- Unidirectional data flow — Data flows down (Service → Repository → ViewModel → View), events flow up
- Lifecycle-aware state management — Handle app backgrounding, overlay launch/close, GPS stream lifecycle properly
- Isolate-aware overlay communication — Structured message protocol for main ↔ overlay isolate
- Service layer isolation — GPS hardware access only through service layer

**Should have (competitive - new optimizations):**
- Speed-adaptive GPS precision — Switch HIGH_ACCURACY ↔ BALANCED_POWER_ACCURACY based on movement (e.g., >12 km/h = HIGH, <8 km/h = BALANCED with hysteresis). Critical for battery life.
- WorkManager background tasks — Modern alternative to aggressive wake locks for system-managed power
- Message queue for overlay sync — Continuous broadcast stream to overlay (debounced 2-4 updates/sec) to fix stale data bug
- Scoped Provider instances — Separate Provider tree per isolate (main app vs overlay) to prevent state collision
- Foreground service architecture — Proper Android foreground service with notification (prevents system kill)
- Multi-repository ViewModel — SpeedometerViewModel composes GpsRepository + SettingsRepository + OverlayRepository

**Defer (v2+ - not essential for restructure):**
- Duty-cycle awareness — Buffer GPS readings for smooth UI when Android duty-cycles hardware
- Hybrid GPS strategy — Combine speed threshold + WiFi state + motion sensors for advanced optimization
- Over-engineering with BLoC — Current team using Provider, BLoC adds boilerplate without benefit

**Anti-patterns to avoid:**
- Monolithic ViewModel/Widget — Current 1,133-line main.dart must be split into feature-specific ViewModels (<200 lines each)
- Shared state between isolates — Overlay cannot access main app memory, use message passing only
- Continuous HIGH_ACCURACY GPS — Current battery drain (7-12%/hour) violates Google Play policy
- Wake lock without justification — Permanent wake lock triggers Google Play penalties (>2 hours in 24h threshold)
- setState for cross-widget state — Forces entire screen rebuilds, doesn't scale to overlay sync

### Architecture Approach

Flutter GPS speedometer apps require clean separation between UI, state management, GPS data processing, and overlay communication. The recommended architecture follows Flutter's MVVM pattern with Provider state management, modular widget extraction by responsibility, and a dedicated overlay service for reliable system-level window communication.

**Layer structure:**
1. **UI Layer (Views)** — screens/ and widgets/, StatelessWidgets using Consumer, no business logic
2. **State Management (ViewModels)** — providers/ with ChangeNotifier, subscribe to services, transform data for UI, expose commands
3. **Services (Data/Logic)** — services/ wrapping external APIs (GPS, overlay, settings), provide streams/futures, handle lifecycle
4. **Models (Domain)** — models/ with immutable data classes, copyWith/toJson/fromJson, no business logic
5. **Configuration** — config/ with constants, enums, themes

**Data flow pattern (unidirectional):**
```
GPS Hardware → GpsDataManager (Singleton) → SpeedometerProvider (ChangeNotifier)
→ Consumer Widgets → OverlayProvider → OverlayService → Overlay Window (Separate Isolate)
```

**Major components:**
1. **GpsDataManager (Service)** — Singleton managing GPS stream subscription, processes raw Position into ProcessedGpsData, broadcasts via Stream, handles staleness detection. KEEP AS-IS (already correctly implemented).
2. **SpeedometerProvider (ViewModel)** — ChangeNotifier subscribing to GpsDataManager.dataStream, transforms data to UI-ready strings (displaySpeed, displayHeading), manages trip stats, coordinates overlay updates, calls notifyListeners() on changes.
3. **OverlayService (Service)** — Encapsulates flutter_overlay_window platform channel calls, manages lifecycle (show/close), status stream for reactive state, graceful error handling, heartbeat for status polling (overlay in separate isolate).
4. **Widget Extraction** — SpeedometerScreen broken into leaf widgets (SpeedDisplay, HeadingCompass, UnitSelector, MetricsPanel) with internal Consumers for granular rebuilds.
5. **Typed Overlay Messages** — OverlayMessage class with factory constructors (speedUpdate, themeUpdate, close) for type-safe message passing between isolates.

**Key architectural decisions:**
- Provider at top level (app-wide singletons for services)
- Services before providers (dependency order)
- Consumer optimization (place deep in widget tree, use Selector for targeted rebuilds)
- Overlay message debouncing (5 Hz instead of GPS rate to prevent channel flooding)
- No shared state between main/overlay isolates (message passing only)

### Critical Pitfalls

The top 5 pitfalls that cause rewrites, regressions, or production failures:

1. **setState After Dispose During Provider Migration** — Async operations (Timers, Stream subscriptions, Future callbacks) continue running after widget disposal, causing "setState() called after dispose()" or "ChangeNotifier used after being disposed()" crashes. Current code has 5+ async patterns (background heartbeat, overlay status poll, tap-close timer, stale data timer, GPS subscription). Prevention: Audit all async patterns before migration, always check `mounted` before setState, cancel ALL timers/subscriptions in dispose(), override notifyListeners with disposal check, use ChangeNotifierProvider.value for singletons.

2. **GPS Stream Subscription Memory Leaks** — GPS stream subscriptions remain active after widget disposal causing memory leaks, battery drain, and indefinite background location requests. GpsDataManager singleton has dispose() but nothing calls it. Prevention: Cancel stream subscriptions in dispose(), store subscriptions when created, implement reference counting or Provider-managed lifecycle for singleton, stop GPS when app backgrounded without overlay active, use Flutter's Leak Tracker during development.

3. **Overlay Communication Breaking After Modularization** — flutter_overlay_window 0.5.0 has known bidirectional communication issues. After extracting overlay logic to separate service/provider, data stops flowing, overlay shows stale speed, close commands ignored. Root cause: separate isolates with isolated memory, only message passing works, current unvalidated Map data. Prevention: Define typed message schema BEFORE refactoring, validate ALL data at isolate boundaries, surface overlay errors to user (don't swallow), verify overlay creation succeeded before setting flags, avoid HapticFeedback in overlay context (hangs).

4. **Excessive Battery Drain From Unconditional Background Timers** — Background heartbeat (5s), overlay polling (1s), continuous HIGH_ACCURACY GPS cause Android vitals to flag app for excessive battery drain. Google Play Store enforcement starting March 2026 (>2 hours wake lock in 24h = bad sessions, >5% bad sessions = recommendation exclusion). Prevention: Stop heartbeat when not needed (only run when backgrounded AND overlay active), replace 1s polling with event-based detection or 5s interval, speed-adaptive GPS precision (8/12 km/h hysteresis), stop GPS completely when overlay closed, cache overlay size calculation.

5. **Singleton Thread Safety Assumptions Breaking With Isolates** — GpsDataManager singleton uses lazy initialization which is NOT thread-safe across isolates. Overlay runs in separate isolate — if it tries accessing singleton directly, creates separate instance (data desync) or race condition. Prevention: Document single-isolate constraint in code comments, use synchronized package if multi-isolate access truly needed (it's not), enforce single-isolate architecture (GPS in main only, overlay receives via messages), add runtime isolate check throwing error if created in wrong isolate.

**Additional moderate pitfalls:**
- ChangeNotifier excessive rebuilds — Every notifyListeners() rebuilds ALL Consumers. Use Selector for targeted rebuilds, place Consumer deep in tree, split large ChangeNotifiers.
- Manual regression testing missing edge cases — Zero automated tests means manual testing follows happy path, misses permission revocation, GPS disable/enable races, lifecycle transitions. Create checklist BEFORE restructuring, test on multiple devices/Android versions.
- Permission state changes not handled at runtime — User can revoke overlay permission while app running (Android 11+). Check permission before EVERY overlay operation, handle revocation gracefully with user feedback, re-check on app resume.

## Implications for Roadmap

Based on research, suggested 4-phase structure with clear dependency chain:

### Phase 1: Foundation (Code Organization)
**Rationale:** Establish architectural foundation without changing behavior. Low regression risk since it's primarily file reorganization and constant extraction. Enables all subsequent phases by creating clear component boundaries.

**Delivers:**
- Layer-first directory structure (screens/, widgets/, providers/, services/, models/, config/)
- Extracted models (ProcessedGpsData, OverlayMessage, TripStats, SpeedometerSettings)
- Centralized constants file (timer durations, GPS thresholds, overlay dimensions)
- Moved existing config (speed_units.dart, color_themes.dart to config/)

**Addresses Features:**
- Foundation for MVVM layer separation (table stakes)
- Preparation for service layer isolation (table stakes)

**Avoids Pitfalls:**
- Hardcoded magic numbers scattered during refactor (minor pitfall #10)

**Research Flags:** None — standard Flutter project organization, well-documented patterns.

### Phase 2: Provider Migration (State Management)
**Rationale:** Replace setState with Provider pattern. CRITICAL RISK phase due to async lifecycle complexity. Must come after Phase 1 (needs directory structure) and before Phase 3 (overlay refactor depends on Provider scoping). This is the make-or-break phase.

**Delivers:**
- SpeedometerProvider (ChangeNotifier managing GPS data, trip stats, unit/theme)
- ThemeProvider (ChangeNotifier for theme state)
- OverlayProvider (ChangeNotifier wrapping OverlayService)
- MultiProvider setup in main.dart
- Consumer widgets with optimization (Selector, deep placement)
- Proper disposal of all async patterns

**Addresses Features:**
- Provider integration (table stakes)
- Unidirectional data flow (table stakes)
- Lifecycle-aware state management (table stakes)

**Avoids Pitfalls:**
- setState after dispose during Provider migration (CRITICAL #1)
- GPS stream subscription memory leaks (CRITICAL #2)
- ChangeNotifier excessive rebuilds (MODERATE #6)
- Manual regression testing gaps (MODERATE #7)

**Research Flags:** HIGH RISK — Requires thorough async pattern audit, manual regression testing with checklist, memory profiling. Use template checklist from PITFALLS.md.

### Phase 3: Overlay Refactor (Isolate Communication)
**Rationale:** Fix overlay data staleness and reliability issues. CRITICAL RISK due to isolate complexity. Must come after Phase 2 (needs Provider scoping) but before Phase 4 (GPS optimization can proceed independently).

**Delivers:**
- OverlayService extracted from SpeedometerScreen
- Typed OverlayMessage schema (speedUpdate, themeUpdate, close)
- Scoped Provider instances (separate main/overlay trees)
- Message queue with debouncing (5 Hz updates)
- Status stream for overlay lifecycle tracking
- Heartbeat conditional logic (only when backgrounded + overlay active)
- Graceful error handling (don't swallow, surface to user)

**Addresses Features:**
- Isolate-aware overlay communication (table stakes)
- Message queue for overlay sync (competitive)
- Scoped Provider instances (competitive)

**Avoids Pitfalls:**
- Overlay communication breaking after modularization (CRITICAL #3)
- Excessive battery drain from timers (CRITICAL #4)
- Permission runtime changes not handled (MODERATE #8)

**Research Flags:** MEDIUM RISK — flutter_overlay_window 0.5.0 has known issues. Define message schema first, validate on multiple Android versions. Consider flutter_overlay_window_plus fork if communication unreliable.

### Phase 4: GPS Optimization (Battery & Performance)
**Rationale:** Implement adaptive GPS precision to address battery drain and Google Play policy compliance. Can proceed independently after Provider migration establishes lifecycle management. Less risky than overlay refactor but requires field testing.

**Delivers:**
- Speed-adaptive GPS precision (HIGH_ACCURACY >12 km/h, BALANCED <8 km/h with hysteresis)
- Lifecycle-aware GPS control (stop when backgrounded without overlay)
- Wake lock conditional logic (only when tracking with overlay)
- WorkManager background tasks (replaces aggressive timers)
- Optimized LocationSettings (intervalDuration, distanceFilter, foregroundNotificationConfig)
- Battery usage monitoring integration

**Addresses Features:**
- Speed-adaptive GPS precision (competitive)
- WorkManager background tasks (competitive)

**Avoids Pitfalls:**
- Excessive battery drain from GPS (CRITICAL #4)
- GPS stream subscription leaks (CRITICAL #2)

**Research Flags:** MEDIUM RISK — Requires physical device testing for threshold tuning, Android OEM behavior varies (Samsung, Xiaomi have aggressive battery optimization). Test on Android 11-15 range.

### Phase Ordering Rationale

**Dependency chain:**
1. Phase 1 (Foundation) → Phase 2 (Provider) — Directory structure needed for organized migration
2. Phase 2 (Provider) → Phase 3 (Overlay) — Scoped Provider instances require Provider setup
3. Phase 2 (Provider) → Phase 4 (GPS) — Lifecycle-aware GPS needs ViewModel hooks
4. Phase 3 (Overlay) and Phase 4 (GPS) are independent — Can be done in parallel or swapped

**Why this grouping:**
- Phase 1 is pure organization, minimal behavior change (low risk warm-up)
- Phase 2 is highest risk, requires full async audit (do while fresh)
- Phase 3 and 4 are independent optimizations (can be prioritized by business need)

**How this avoids pitfalls:**
- Audit async patterns BEFORE Phase 2 migration (prevents dispose crashes)
- Define message schema BEFORE Phase 3 refactor (prevents overlay communication breaks)
- Conditional timer logic IN Phase 3 (prevents battery drain violations)
- Speed-adaptive GPS IN Phase 4 (addresses Google Play compliance deadline March 2026)

### Research Flags

**Phases likely needing deeper research:**
- **Phase 3 (Overlay Refactor):** flutter_overlay_window 0.5.0 reliability issues documented but solutions vary. May need platform-specific testing, consider flutter_overlay_window_plus fork (July 2025) if communication fails. Test message serialization edge cases, Android version inconsistencies (11+ notification bubbles vs overlays).
- **Phase 4 (GPS Optimization):** Optimal speed thresholds need field testing (suggested 8/12 km/h hysteresis may need tuning). Android Fused Location Provider duty-cycling behavior varies by OEM. Research WorkManager setup for background location (Play Store policy nuances).

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Foundation):** Well-documented Flutter project structure patterns, official guides available
- **Phase 2 (Provider Migration):** Established Provider patterns, official Flutter docs cover ChangeNotifier lifecycle

**Open research questions for phase planning:**
1. Is there event-based alternative to overlay status polling? Or accept polling at 5s instead of 1s?
2. Should GpsDataManager singleton use reference counting or Provider-managed lifecycle?
3. What's cleanest pattern for Provider + Singleton (ChangeNotifierProvider.value vs custom dispose logic)?

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Existing packages verified with official docs, no new dependencies needed, Provider is official Flutter recommendation |
| Features | HIGH | Clear restructure goals from project context, MVVM patterns well-documented for 2026 Flutter |
| Architecture | HIGH | Official Flutter architecture guide 2026, layer structure matches single-screen app complexity |
| Pitfalls | HIGH | Multiple 2025-2026 sources confirm async lifecycle issues, battery drain enforcement documented by Google |
| Overlay Communication | MEDIUM | flutter_overlay_window 0.5.0 issues confirmed on GitHub, but solutions vary — needs testing |
| GPS Optimization | MEDIUM | Speed thresholds need field validation, Android OEM behavior varies |

**Overall confidence:** HIGH for architectural approach, MEDIUM for overlay/GPS implementation details

### Gaps to Address

**Research gaps needing validation during implementation:**

1. **flutter_overlay_window 0.5.0 specific limitations** — Project context mentions "shareData fundamentally broken" but GitHub issues are vague. Need to test overlay→main communication thoroughly during Phase 3. Consider flutter_overlay_window_plus fork (2025) if message passing fails. May need workarounds like accepting 5s polling instead of 1s, or one-way communication only.

2. **GpsDataManager singleton lifecycle** — Currently nothing calls dispose() on singleton. Need to decide during Phase 2: Reference counting pattern? Provider-managed disposal? App-global persistence? Research needed on cleanest Provider + Singleton pattern in Flutter 2026.

3. **Optimal GPS accuracy switching thresholds** — Project spec suggests ~10 km/h with 8/12 hysteresis. Need field testing during Phase 4 to validate battery vs responsiveness tradeoff. Android Fused Location Provider behavior varies by OEM (Samsung, Xiaomi, OnePlus have different duty-cycling). Test on multiple devices.

4. **Overlay status polling alternative** — Current 1s polling is workaround for broken message-based detection. Research during Phase 3: Is there event-based alternative via flutter_overlay_window_plus? Or accept polling at 5s instead of 1s as reasonable compromise?

5. **Manual testing coverage** — Zero automated tests means regression testing is manual-only. Create comprehensive test checklist during Phase 1. Consider adding basic smoke tests post-restructure to catch future regressions (even minimal widget tests help).

6. **Android lifecycle edge cases** — Permission revocation while app running, GPS disabled mid-tracking, overlay permission removed externally, duty-cycling on different Android versions. These need dedicated test scenarios during Phases 2-3.

## Sources

### Primary (HIGH confidence)
- [Flutter Official: Guide to App Architecture](https://docs.flutter.dev/app-architecture/guide) — MVVM pattern, layer separation, 2026 best practices
- [Flutter Official: Simple State Management (Provider)](https://docs.flutter.dev/data-and-backend/state-mgmt/simple) — Provider patterns, ChangeNotifier lifecycle
- [Android Developers Blog: Excessive Wake Lock Metric (2025)](https://android-developers.googleblog.com/2025/09/guide-to-excessive-wake-lock-usage.html) — Battery drain enforcement, March 2026 deadline, thresholds
- [Android Official: Location Request Updates](https://developer.android.com/develop/sensors-and-location/location/request-updates) — LocationSettings API, accuracy mapping
- [Android Official: Location Battery Optimization](https://developer.android.com/develop/sensors-and-location/location/battery) — GPS power best practices, duty-cycling
- [Geolocator Package Docs](https://pub.dev/packages/geolocator) — LocationSettings usage, Android 14+ compatibility
- [Provider Package Docs](https://pub.dev/packages/provider) — Consumer optimization, Selector patterns, disposal

### Secondary (MEDIUM confidence)
- [flutter_overlay_window GitHub Issues](https://github.com/X-SLAYER/flutter_overlay_window/issues) — Known reliability problems, communication failures
- [flutter_overlay_window Issue #115](https://github.com/X-SLAYER/flutter_overlay_window/issues/115) — "Can't display data on overlay" matches project bug
- [Geolocator Issue #1682](https://github.com/Baseflow/flutter-geolocator/issues/1682) — Stream subscription memory leak
- [DCM: Memory Leaks in Dart and Flutter (2024)](https://dcm.dev/blog/2024/10/21/lets-talk-about-memory-leaks-in-dart-and-flutter/) — Disposal patterns, StreamSubscription leaks
- [Advanced Location Tracking in Flutter: 2026 Guide](https://medium.com/@ali.mohamed.hgr/advanced-location-tracking-in-flutter-the-complete-2026-guide-cce138f2d558) — GPS architecture patterns
- [Best Flutter State Management Libraries 2026](https://foresightmobile.com/blog/best-flutter-state-management) — Provider vs Riverpod comparison
- [Flutter Project Structure: Feature-first or Layer-first?](https://codewithandrea.com/articles/flutter-project-structure/) — Directory organization guidance

### Tertiary (LOW confidence, needs validation)
- [flutter_overlay_window_plus](https://pub.dev/packages/flutter_overlay_window_plus) — July 2025 fork claiming fixes, untested
- Various Medium articles on Provider migration best practices (2024-2025)
- Stack Overflow discussions on setState after dispose patterns
- Community blog posts on ChangeNotifier optimization

---
**Research completed:** 2026-02-09
**Ready for roadmap:** Yes
**Estimated restructure effort:** 52-70 hours (1.5-2 weeks full-time)
**Highest risk phases:** Phase 2 (Provider Migration), Phase 3 (Overlay Refactor)
