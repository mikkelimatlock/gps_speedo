---
phase: 03-overlay-refactor
plan: 02
subsystem: overlay
tags: [flutter, overlay, staleness, error-handling, provider, permission-handler, flutter-overlay-window]

# Dependency graph
requires:
  - phase: 03-01
    provides: OverlayService wrapper with retry logic, OverlayMessage timestamp tracking, staleness constants
provides:
  - OverlayProvider delegates all platform calls to OverlayService with permission checks and verified creation
  - Error callback mechanism connects OverlayProvider to SpeedometerScreen for snackbar surfacing
  - Overlay screen detects stale GPS data (dim at 3s, dashes at 10s) with immediate snap-back on fresh data
  - Permission errors surface to user with "Settings" action button that opens app settings
  - GPS grace period timer (30s) starts on overlay close (infrastructure for Phase 4)
affects: [04-gps-optimization]

# Tech tracking
tech-stack:
  added: [permission_handler]
  patterns:
    - Error callback pattern for provider-to-screen communication without BuildContext
    - Staleness detection via timestamp comparison in build()
    - Immediate snap-back on fresh data (no animation)

key-files:
  created: []
  modified:
    - lib/providers/overlay_provider.dart
    - lib/screens/overlay_screen.dart
    - lib/screens/speedometer_screen.dart
    - lib/main.dart

key-decisions:
  - "OverlayProvider delegates ALL FlutterOverlayWindow calls to OverlayService (no direct usage)"
  - "Error callback set by SpeedometerScreen after provider available (late binding for BuildContext)"
  - "Staleness opacity applied via withValues(alpha:) to color (no AnimatedOpacity per user decision)"
  - "GPS grace period timer created but does not yet control GPS lifecycle (Phase 4 scope)"

patterns-established:
  - "OverlayError enum for typed error surfacing (permission, creationFailed, communicationDegraded)"
  - "onError callback field on OverlayProvider set by SpeedometerScreen in postFrameCallback"
  - "Staleness check timer runs every 1 second, dims at 3s, shows dashes at 10s"
  - "Permission errors show snackbar with Settings action button via openAppSettings()"

# Metrics
duration: 4.25min
completed: 2026-02-11
---

# Phase 03 Plan 02: Overlay Integration Summary

**OverlayService integration with permission checks, verified creation, staleness detection (3s dim/10s dash), and error surfacing via snackbars with Settings action**

## Performance

- **Duration:** 4.25 min
- **Started:** 2026-02-11T10:20:25Z
- **Completed:** 2026-02-11T10:24:40Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- OverlayProvider delegates all platform calls to OverlayService with permission checks before showing overlay
- Overlay creation verified via isActive() check before setting _isOverlayActive flag
- Overlay screen detects stale GPS data with two-stage visual feedback (dim at 3s, dashes at 10s)
- Permission errors surface to user via snackbar with "Settings" action button that opens app settings
- GPS grace period timer (30s) infrastructure created for Phase 4

## Task Commits

Each task was committed atomically:

1. **Task 1: Refactor OverlayProvider to use OverlayService with error callback and GPS grace period** - `66bdd35` (feat)
2. **Task 2: Add staleness detection to overlay screen and error surfacing to SpeedometerScreen** - `cc11a3d` (feat)

## Files Created/Modified

- `lib/providers/overlay_provider.dart` - Added OverlayService dependency, error callback mechanism, permission checks, verified creation, GPS grace period timer
- `lib/screens/overlay_screen.dart` - Added staleness monitoring timer, timestamp tracking, opacity-based dimming, dash display after 10s
- `lib/screens/speedometer_screen.dart` - Added error callback registration, _handleOverlayError method, snackbar surfacing with Settings action
- `lib/main.dart` - Registered OverlayService in MultiProvider, injected into OverlayProvider constructor

## Decisions Made

**OverlayProvider refactor:**
- All FlutterOverlayWindow calls replaced with OverlayService methods (showOverlay, closeOverlay, shareData, isActive, overlayListener)
- Permission check via _overlayService.checkPermission() before showing overlay
- Overlay creation success verified via _overlayService.showOverlay() return value (bool)
- _isOverlayActive only set after successful verification (prevents false positive active state)
- Error callback mechanism uses nullable function field set by SpeedometerScreen after provider available (late binding for BuildContext)
- GPS grace period timer (30s) starts on overlay close, cancelled on reopen or dispose (infrastructure only, Phase 4 will control GPS lifecycle)

**Overlay screen staleness detection:**
- _lastUpdateTime field tracks timestamp from OverlayMessage.timestamp
- Staleness check timer runs every 1 second (OverlayConfig.STALENESS_CHECK_INTERVAL)
- Timer callback shows "--" for speed after 10 seconds (OverlayConfig.STALENESS_DASH_THRESHOLD)
- Build() calculates staleness opacity (0.5 after 3s via OverlayConfig.STALENESS_DIM_THRESHOLD)
- Staleness opacity applied via color.withValues(alpha:) to speed text, unit text, heading icon, heading text
- No AnimatedOpacity used per user decision (immediate snap-back, no fade-in animation)

**SpeedometerScreen error surfacing:**
- Error callback registered in initState() postFrameCallback (after context available)
- _handleOverlayError shows snackbar with message and optional action button
- Permission error: snackbar with "Settings" action button that calls openAppSettings()
- Creation failure: snackbar with error message (no action button)
- Communication degraded: snackbar with error message (no action button)
- Error callback nulled in dispose() with try-catch (provider might already be disposed)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## Next Phase Readiness

**Phase 3 complete. Ready for Phase 4 (GPS Optimization):**
- Overlay communication is reliable with retry logic and verified creation
- Staleness detection provides visual feedback when GPS data is stale
- Error surfacing gives users actionable guidance (permission Settings button)
- GPS grace period timer infrastructure exists for Phase 4 GPS lifecycle management
- All OVRL-01 through OVRL-06 requirements satisfied

**Phase 4 blockers:**
- None

**Phase 4 dependencies satisfied:**
- GPS grace period timer exists (Phase 4 will control GPS subscription start/stop)
- Overlay active state is reliable (verified creation, status check monitoring)
- Background heartbeat only runs when overlay active AND app backgrounded (ready for GPS optimization)

---
*Phase: 03-overlay-refactor*
*Completed: 2026-02-11*
