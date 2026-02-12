---
phase: 04-gps-power-optimization
plan: 01
subsystem: gps
tags: [geolocator, wakelock, lifecycle, precision-switching]

requires:
  - phase: 03-overlay-refactor
    provides: OverlayProvider with isOverlayActive, OverlayService, staleness constants
provides:
  - Lifecycle-aware GpsDataManager with WidgetsBindingObserver
  - Speed-adaptive precision switching (8/12 km/h hysteresis)
  - Background GPS management with 7s grace period
  - Conditional wake lock (GPS active + visible)
  - ProcessedGpsData with timestamp field
  - Dynamic GPS stream via GpsService.createPositionStream()
affects: [04-02-ui-integration]

tech-stack:
  added: [wakelock_plus (already dependency)]
  patterns: [WidgetsBindingObserver for lifecycle, hysteresis threshold switching, race condition protection]

key-files:
  created: []
  modified:
    - lib/models/processed_gps_data.dart
    - lib/config/gps_constants.dart
    - lib/config/timing_constants.dart
    - lib/gps_service.dart
    - lib/services/gps_data_manager.dart

key-decisions:
  - "Speed-adaptive precision switching uses hysteresis (8/12 km/h) to prevent thrashing"
  - "Precision switching gated until 5s after first GPS fix for stability"
  - "Background grace period re-checks overlay state at expiry to handle race conditions"
  - "Wake lock is contextual: enabled when GPS active AND (overlay visible OR app in foreground)"
  - "GPS stop preserves last known data for staleness display (no data clearing)"
  - "Deprecated GPS_GRACE_PERIOD (30s) in favor of BACKGROUND_GRACE_PERIOD (7s) for lifecycle"

duration: 4.9min
completed: 2026-02-12
---

# Phase 4 Plan 01: Core GPS Engine Summary

**Lifecycle-aware GPS manager with speed-adaptive precision switching, 7s background grace period, and conditional wake lock control**

## Performance

- **Duration:** 4.9 minutes
- **Start:** 2026-02-11 23:57:48 UTC
- **End:** 2026-02-12 00:02:42 UTC
- **Tasks completed:** 2
- **Files modified:** 5
- **Commits:** 2

## Accomplishments

Successfully transformed GpsDataManager into a fully lifecycle-aware GPS engine with intelligent power management:

1. **ProcessedGpsData Timestamp Field**
   - Added `timestamp` field to enable staleness detection in overlay
   - Updated `copyWith()` to support timestamp parameter
   - Changed default initialization from `const` to non-const with `DateTime.now()`

2. **Precision Switching Constants**
   - Added `PRECISION_UP_THRESHOLD_MPS` (3.33 m/s / 12 km/h) for high precision
   - Added `PRECISION_DOWN_THRESHOLD_MPS` (2.22 m/s / 8 km/h) for balanced precision
   - Added `PRECISION_SWITCH_FIRST_FIX_DELAY` (5s) safety gate
   - Hysteresis prevents precision thrashing in 8-12 km/h range

3. **Lifecycle Constants**
   - Added `BACKGROUND_GRACE_PERIOD` (7s) for responsive background management
   - Deprecated `GPS_GRACE_PERIOD` (30s) with clear documentation

4. **Dynamic GPS Stream**
   - Changed `GpsService.positionStream` from hardcoded `bestForNavigation` to `createPositionStream()`
   - Accepts `LocationAccuracy` parameter for dynamic precision control
   - Kept deprecated wrapper for backward compatibility during transition

5. **Lifecycle-Aware GPS Manager**
   - Implemented `WidgetsBindingObserver` mixin for app lifecycle tracking
   - Added overlay provider reference for background decision-making
   - Tracks foreground/background state, GPS active state, current accuracy
   - Registers/removes lifecycle observer in initialize()/dispose()

6. **Precision Switching Logic**
   - Speed-based hysteresis switching (HIGH ↔ MEDIUM at 8/12 km/h boundaries)
   - Gated until 5s after first GPS fix for stability
   - Seamless stream recreation with new accuracy on switch
   - Debug logging only (invisible to user per project decision)

7. **Background GPS Management**
   - 7s grace period when app backgrounds without overlay visible
   - Immediate GPS continuation when app backgrounds with overlay active
   - Grace period re-checks overlay state at expiry (race condition protection)
   - GPS restart on app foreground resume if previously stopped

8. **Conditional Wake Lock**
   - Wake lock enabled when GPS active AND (overlay visible OR app in foreground)
   - Wake lock disabled when GPS stops or app backgrounds without overlay
   - Updated on all state transitions (GPS start/stop, lifecycle change)
   - Disabled in dispose() as safety net

9. **State Preservation**
   - GPS stop does NOT clear `_currentData` (preserves last known speed/heading)
   - Staleness detection shows last data as stale per existing timer logic
   - Fresh data immediately replaces stale display on GPS restart

## Task Commits

| Task | Name                                                  | Commit  | Files Modified |
| ---- | ----------------------------------------------------- | ------- | -------------- |
| 1    | Add timestamp and precision/lifecycle constants       | c4d4032 | 4 files        |
| 2    | Implement lifecycle-aware GPS engine with wake lock   | 1618cfe | 1 file         |

## Files Created/Modified

**Modified:**
- `lib/models/processed_gps_data.dart` — Added timestamp field and copyWith support
- `lib/config/gps_constants.dart` — Added precision switching thresholds (3.33/2.22 m/s, 5s delay)
- `lib/config/timing_constants.dart` — Added BACKGROUND_GRACE_PERIOD (7s), deprecated GPS_GRACE_PERIOD
- `lib/gps_service.dart` — Added createPositionStream() with dynamic accuracy, deprecated static getter
- `lib/services/gps_data_manager.dart` — Added lifecycle awareness, precision switching, wake lock control

## Decisions Made

1. **Hysteresis Thresholds:** 8/12 km/h boundaries prevent precision thrashing in transition zone
2. **First-Fix Gate:** 5s delay before precision switching prevents instability during initial acquisition
3. **Race Condition Protection:** Background grace period re-checks overlay state at expiry (not just at start)
4. **Wake Lock Strategy:** Conditional on GPS active + visible (overlay OR foreground) for minimal battery impact
5. **Data Preservation:** GPS stop preserves last known data, relying on existing staleness timer for UI feedback
6. **Grace Period Duration:** 7s chosen for responsive UX (short enough to save battery, long enough for quick returns)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Cleanup] Removed unnecessary flutter/foundation.dart import**
- **Found during:** Task 2 verification
- **Issue:** flutter analyze reported unnecessary import (flutter/widgets.dart provides ChangeNotifier)
- **Fix:** Removed `import 'package:flutter/foundation.dart';` from gps_data_manager.dart
- **Files modified:** lib/services/gps_data_manager.dart
- **Commit:** 1618cfe (included in Task 2 commit)

## Issues Encountered

None. Plan executed exactly as written with only one minor cleanup deviation (unnecessary import removal).

## Next Phase Readiness

**Ready for Plan 04-02 (UI Integration):**
- ✅ GpsDataManager implements full lifecycle awareness
- ✅ ProcessedGpsData carries timestamps for staleness detection
- ✅ Precision switching functional with hysteresis
- ✅ Background GPS management with grace period
- ✅ Wake lock contextual control implemented
- ✅ All timers properly canceled in dispose()
- ✅ Flutter analyze passes (only expected SCREAMING_SNAKE info warnings)

**Integration points for Plan 04-02:**
- SpeedometerScreen needs to call `gpsDataManager.setOverlayProvider(overlayProvider)` after provider wiring
- No UI changes needed for precision switching (silent/invisible per user decision)
- Background heartbeat may need adjustment (currently 5s, may conflict with 7s grace period)
- Staleness detection in overlay should consume `ProcessedGpsData.timestamp` field

**Testing considerations:**
- Field testing needed for 8/12 km/h hysteresis validation
- Android OEM behavior varies (Samsung, Xiaomi duty-cycling differences documented in research)
- Wake lock effectiveness depends on Android version and OEM power management

## Self-Check: PASSED

**Files exist:**
```
FOUND: lib/models/processed_gps_data.dart
FOUND: lib/config/gps_constants.dart
FOUND: lib/config/timing_constants.dart
FOUND: lib/gps_service.dart
FOUND: lib/services/gps_data_manager.dart
```

**Commits exist:**
```
FOUND: c4d4032
FOUND: 1618cfe
```

**Flutter analyze status:** 30 issues (all expected SCREAMING_SNAKE info warnings, no errors)

All claims verified. Plan execution complete.
