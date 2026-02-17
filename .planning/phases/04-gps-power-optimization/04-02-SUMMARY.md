---
phase: 04-gps-power-optimization
plan: 02
subsystem: ui
tags: [staleness, lifecycle, overlay, provider-wiring]

requires:
  - phase: 04-gps-power-optimization
    provides: Lifecycle-aware GpsDataManager, ProcessedGpsData with timestamp
provides:
  - Main app staleness detection matching overlay (3s dim, 10s dashes)
  - Centralized wake lock (removed from SpeedometerScreen)
  - Centralized lifecycle management (removed from SpeedometerScreen)
  - Clean OverlayProvider without Phase 3 placeholder
  - GpsDataManager overlay reference wiring
affects: []

tech-stack:
  added: []
  patterns: [staleness detection via timestamp, centralized lifecycle in manager]

key-files:
  created: []
  modified:
    - lib/screens/speedometer_screen.dart
    - lib/providers/overlay_provider.dart

key-decisions:
  - "Staleness detection uses same thresholds as overlay for consistency (3s dim, 10s dash)"
  - "Background heartbeat simplified to check only overlay state (removed _isInBackground)"
  - "Haptic feedback added to theme/unit cycling for better tactile response"
  - "GPS_GRACE_PERIOD kept in TimingConfig as deprecated (unused but documented)"

duration: 3.35min
completed: 2026-02-12
---

# Phase 4 Plan 02: UI Integration Summary

**Main app staleness detection, centralized lifecycle management, and clean provider architecture**

## Performance

- **Duration:** 3.35 minutes
- **Start:** 2026-02-12 08:33:41 UTC
- **End:** 2026-02-12 08:37:02 UTC
- **Tasks completed:** 2
- **Files modified:** 2
- **Commits:** 2

## Accomplishments

Successfully integrated the lifecycle-aware GPS engine into the UI layer and cleaned up architectural responsibilities:

1. **Staleness Detection in Main App**
   - Added staleness check timer (1s interval) to SpeedometerScreen
   - Speed/heading displays dim at 3s, show dashes at 10s (identical to overlay)
   - Staleness calculated from `ProcessedGpsData.timestamp` field
   - Applied to both speed and heading displays in portrait and landscape layouts
   - Timer properly canceled in dispose()

2. **Wake Lock Management Centralized**
   - Removed `wakelock_plus` import from SpeedometerScreen
   - Removed `_enableWakelock()` method entirely
   - Removed `WakelockPlus.disable()` from dispose()
   - Wake lock now exclusively managed by GpsDataManager (Task 04-01)

3. **Lifecycle Management Centralized**
   - Removed `WidgetsBindingObserver` mixin from SpeedometerScreen
   - Removed `didChangeAppLifecycleState()` override
   - Removed `_isInBackground` field and `_handleBackgroundTransition()` method
   - Removed `_requestBatteryOptimizationExemption()` stub
   - Lifecycle awareness now exclusively in GpsDataManager (Task 04-01)

4. **Simplified Background Heartbeat**
   - Removed `_isInBackground` check from heartbeat logic
   - Heartbeat now simply checks `overlay.isOverlayActive` and pushes data
   - Cleaner logic without redundant state tracking

5. **Provider Wiring Completed**
   - Added `gpsDataManager.setOverlayProvider(overlayProvider)` call in initState
   - Enables GpsDataManager to check overlay state for background GPS decisions
   - No circular dependencies (wired after both providers available)

6. **OverlayProvider Cleanup**
   - Removed `_gracePeriodTimer` field
   - Removed all grace period logic from `showOverlay()` and `_handleOverlayClose()`
   - Removed grace period cancel from dispose()
   - Grace period management now handled by GpsDataManager's background lifecycle

7. **Enhanced User Experience**
   - Added haptic feedback to theme cycling (speed display tap)
   - Added haptic feedback to unit cycling (unit label tap)
   - Consistent tactile response across all main UI interactions

8. **Speed Display Opacity Support**
   - Updated `_buildSpeedDisplay()` to accept opacity parameter
   - Applied staleness opacity to integral and decimal parts
   - Applied staleness opacity to dash display ("--")

9. **TimingConfig Status**
   - `GPS_GRACE_PERIOD` (30s) remains in TimingConfig with deprecation comment
   - No longer referenced anywhere (verified via grep)
   - Kept for documentation of architectural evolution

## Task Commits

| Task | Name                                                  | Commit  | Files Modified |
| ---- | ----------------------------------------------------- | ------- | -------------- |
| 1    | Add staleness detection to main speed display        | 1dcfe60 | 1 file         |
| 2    | Remove grace period placeholder from OverlayProvider | 75d58c0 | 1 file         |

## Files Created/Modified

**Modified:**
- `lib/screens/speedometer_screen.dart` — Added staleness detection, removed wake lock/lifecycle, simplified heartbeat
- `lib/providers/overlay_provider.dart` — Removed grace period placeholder infrastructure

## Decisions Made

1. **Consistent Staleness Thresholds:** Used OverlayConfig constants for both main app and overlay (3s dim, 10s dash)
2. **Background Heartbeat Simplification:** Removed `_isInBackground` check since GpsDataManager now manages lifecycle
3. **Haptic Feedback Enhancement:** Added to theme/unit cycling for better user experience consistency
4. **GPS_GRACE_PERIOD Retention:** Kept constant as deprecated for documentation (shows architectural evolution)

## Deviations from Plan

None. Plan executed exactly as written. All requirements met without issues.

## Issues Encountered

None. Clean execution with no blockers or unexpected complications.

## Next Phase Readiness

**Phase 4 Complete:**
- ✅ Core GPS engine with lifecycle awareness (Plan 01)
- ✅ UI integration with staleness detection (Plan 02)
- ✅ Centralized wake lock and lifecycle management
- ✅ Consistent staleness behavior (main app + overlay)
- ✅ Clean provider architecture with proper wiring
- ✅ All timers properly canceled in dispose()
- ✅ Flutter analyze passes (only expected SCREAMING_SNAKE warnings)

**Architecture State:**
- GpsDataManager: GPS engine, lifecycle observer, wake lock manager, precision switcher
- OverlayProvider: Overlay lifecycle, GPS stream consumer, settings consumer
- SpeedometerScreen: UI only (no lifecycle/wake lock/GPS management)
- Staleness detection: Identical in main app and overlay (3s/10s thresholds)

**Testing Recommendations:**
- Field test staleness behavior (3s dim, 10s dash) during GPS signal loss
- Verify wake lock behavior across app states (foreground/background/overlay)
- Test precision switching at 8/12 km/h boundaries
- Validate background GPS stop after 7s grace period without overlay
- Test haptic feedback on theme/unit cycling

**Integration Complete:**
Phase 4 successfully connected the lifecycle-aware GPS engine to the user-visible surfaces. Main app and overlay now behave identically with consistent staleness rules, centralized power management, and clean architectural separation.

## Self-Check: PASSED

**Files exist:**
```
FOUND: lib/screens/speedometer_screen.dart
FOUND: lib/providers/overlay_provider.dart
```

**Commits exist:**
```
FOUND: 1dcfe60
FOUND: 75d58c0
```

**Verification checks:**
- ✅ No WakelockPlus references in SpeedometerScreen
- ✅ No WidgetsBindingObserver in SpeedometerScreen
- ✅ No grace period timer in OverlayProvider
- ✅ Staleness timer started and canceled properly
- ✅ GpsDataManager.setOverlayProvider() called in initState
- ✅ Flutter analyze passes (30 expected info warnings)

All claims verified. Plan execution complete.
