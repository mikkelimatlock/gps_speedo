---
phase: 03-overlay-refactor
plan: 01
subsystem: overlay-infrastructure
tags: [service-layer, ipc, staleness-detection, retry-logic]

requires:
  - 02-02: Provider pattern infrastructure for overlay state management

provides:
  - OverlayService wrapper isolating all flutter_overlay_window platform calls
  - Timestamp tracking in OverlayMessage for staleness detection
  - Staleness threshold constants (3s dim, 10s dash) for UI feedback
  - GPS grace period constant (30s) for background GPS lifecycle

affects:
  - 03-02: OverlayProvider will use OverlayService instead of direct FlutterOverlayWindow calls
  - 03-02: Overlay screen will consume staleness constants for visual feedback
  - 03-02: SpeedometerScreen will use GPS_GRACE_PERIOD for background GPS management

tech-stack:
  added:
    - retry: ^3.1.2
  patterns:
    - Service wrapper pattern for platform channel isolation
    - Exponential backoff retry (3 attempts, 200ms delay factor)
    - Fire-and-forget with warn-level logging for non-critical failures
    - Timestamp-based staleness detection via millisecondsSinceEpoch serialization

key-files:
  created:
    - lib/services/overlay_service.dart
  modified:
    - lib/models/overlay_message.dart
    - lib/config/overlay_constants.dart
    - lib/config/timing_constants.dart
    - pubspec.yaml

decisions:
  - id: OVL-01
    choice: OverlayService wraps all FlutterOverlayWindow calls
    rationale: Isolate platform-specific code, centralize retry logic and error handling
    status: implemented
  - id: OVL-02
    choice: showOverlay verifies overlay opened via isActive() call
    rationale: Platform channel may succeed but overlay fail to appear - explicit verification required
    status: implemented
  - id: OVL-03
    choice: shareData is fire-and-forget with warn-level logging
    rationale: User decision - send every GPS tick, staleness detection handles drops, no retry needed
    status: implemented
  - id: OVL-04
    choice: Staleness thresholds are 3s dim, 10s dash (NOT 2s/10s)
    rationale: User specified 3 seconds for dim threshold in plan
    status: implemented
  - id: OVL-05
    choice: Timestamp auto-populated by DateTime.now() in factories
    rationale: Timestamp is metadata, not user data - automatic population prevents caller errors
    status: implemented
  - id: OVL-06
    choice: Remove const from OverlayMessage constructors
    rationale: DateTime.now() is runtime value, cannot be const - necessary for timestamp field
    status: implemented

metrics:
  duration: 4.0 minutes
  completed: 2026-02-11
---

# Phase 03 Plan 01: Overlay Foundation Infrastructure Summary

**One-liner:** OverlayService wrapper with retry logic, timestamp-enhanced OverlayMessage, and staleness constants (3s dim, 10s dash, 30s GPS grace period).

## Objective Achieved

Created the foundation building blocks for overlay refactor by:
1. Isolating all flutter_overlay_window platform calls behind OverlayService with retry logic
2. Adding timestamp tracking to OverlayMessage for staleness detection
3. Defining staleness thresholds (3s dim, 10s dash) and GPS grace period (30s) as named constants

These components provide the service layer, enhanced model, and constants that Plan 02 will integrate into OverlayProvider, overlay screen, and SpeedometerScreen.

## Tasks Completed

| Task | Description | Commit | Files Modified |
|------|-------------|--------|----------------|
| 1 | Create OverlayService and add retry dependency | 505219c | overlay_service.dart, overlay_constants.dart, timing_constants.dart, pubspec.yaml |
| 2 | Add timestamp field to OverlayMessage model | 9e3decc | overlay_message.dart |

## Implementation Details

### OverlayService Architecture

**Platform Channel Wrapper:**
- `showOverlay({width, height})` - Retry logic with post-verification via isActive()
- `closeOverlay()` - Retry logic for robust cleanup
- `shareData(Map)` - Fire-and-forget with warn-level logging (no retry)
- `isActive()` - Error-safe overlay status check
- `overlayListener` - Direct stream delegation
- `checkPermission()` - Permission status helper

**Retry Configuration:**
- 3 attempts maximum
- 200ms delay factor (exponential backoff)
- Removed unnecessary `retryIf` checks (analyzer warnings fixed)

**Error Handling Strategy:**
- showOverlay/closeOverlay: Logger.error after exhausted retries, return false
- shareData: Logger.warn on failure, no retry (staleness detection handles drops)
- isActive: Logger.error + return false on exception

### OverlayMessage Enhancements

**Timestamp Field:**
- Auto-populated via `DateTime.now()` in all factory constructors
- No manual timestamp passing required from callers
- Serialized as `millisecondsSinceEpoch` (int) in toMap()
- Deserialized with fallback to `DateTime.now()` in fromMap() for backward compatibility

**Breaking Change Mitigation:**
- Removed `const` modifiers (DateTime.now() is runtime value)
- Added timestamp to copyWith() for completeness
- All existing factory APIs unchanged (timestamp is additive metadata)

### Constants Configuration

**Staleness Thresholds (overlay_constants.dart):**
- `STALENESS_DIM_THRESHOLD`: 3 seconds (dim speed display)
- `STALENESS_DASH_THRESHOLD`: 10 seconds (show dashes instead of speed)
- `STALENESS_DIM_OPACITY`: 0.5 (dimmed state opacity)
- `STALENESS_CHECK_INTERVAL`: 1 second (check frequency)

**GPS Grace Period (timing_constants.dart):**
- `GPS_GRACE_PERIOD`: 30 seconds (continue GPS after overlay close when backgrounded)

## Verification Results

**flutter pub get:**
- retry package (^3.1.2) installed successfully
- All dependencies resolved

**flutter analyze:**
- 26 info-level warnings (SCREAMING_SNAKE constants - expected per project convention)
- 0 errors or warnings in new code
- Fixed 2 unnecessary type check warnings in OverlayService retry logic

**Code Quality:**
- OverlayService: 93 lines with comprehensive error handling
- OverlayMessage timestamp integration: 15 lines added across all methods
- All must-have requirements satisfied

## Deviations from Plan

None - plan executed exactly as written.

## Decisions Made

**OVL-01: Service Wrapper Pattern**
- All flutter_overlay_window calls isolated in OverlayService
- Benefits: Centralized retry logic, single error handling point, easier testing
- Impact: Plan 02 will migrate OverlayProvider to use OverlayService

**OVL-02: Post-Verification in showOverlay**
- Added isActive() verification after FlutterOverlayWindow.showOverlay() completes
- Addresses: Platform channel may report success but overlay fails to appear
- Prevents: False positive overlay status in OverlayProvider

**OVL-03: Fire-and-Forget shareData**
- No retry logic for data sharing (user decision: forward every tick)
- Staleness detection handles dropped messages via timestamp tracking
- Warn-level logging prevents error log noise from expected occasional failures

**OVL-04: Staleness Timing**
- 3 seconds for dim (NOT 2 seconds as in some research notes)
- 10 seconds for dashes (consistent across all references)
- User explicitly specified 3s in plan MUST_HAVES

**OVL-05: Automatic Timestamp Population**
- DateTime.now() called in factory constructors, not passed by callers
- Prevents caller errors (forgetting timestamp, using wrong time source)
- Ensures consistency (all timestamps from same clock source)

**OVL-06: Remove const Modifiers**
- Required to allow DateTime.now() runtime values
- Trade-off: Lose compile-time const optimization for timestamp functionality
- Impact: Negligible (OverlayMessage instances are short-lived IPC data)

## Technical Debt

**None identified.**

All code follows project conventions:
- SCREAMING_SNAKE for behavioral constants
- Logger with caller tags for all logging
- Error handling with graceful degradation
- Type-safe OverlayMessage serialization

## Integration Readiness

**Ready for Plan 02:**
- OverlayService provides all needed platform operations
- OverlayMessage timestamp field ready for staleness calculation
- Constants defined and accessible for UI feedback logic

**Migration Path for Plan 02:**
1. Replace FlutterOverlayWindow.showOverlay in OverlayProvider with OverlayService.showOverlay
2. Replace FlutterOverlayWindow.closeOverlay with OverlayService.closeOverlay
3. Replace FlutterOverlayWindow.shareData with OverlayService.shareData
4. Add staleness detection timer in overlay screen using STALENESS_CHECK_INTERVAL
5. Implement dim/dash logic using STALENESS_DIM_THRESHOLD and STALENESS_DASH_THRESHOLD
6. Add GPS grace period logic in SpeedometerScreen using GPS_GRACE_PERIOD

## Artifacts Generated

**Service Layer:**
- `lib/services/overlay_service.dart` (93 lines)

**Enhanced Model:**
- `lib/models/overlay_message.dart` (+18 lines, -3 lines)

**Configuration:**
- `lib/config/overlay_constants.dart` (+12 lines)
- `lib/config/timing_constants.dart` (+3 lines)

**Dependencies:**
- `pubspec.yaml` (+3 lines - retry package)

## Next Steps

Plan 02 will:
1. Integrate OverlayService into OverlayProvider
2. Add staleness detection timer and UI feedback in overlay screen
3. Implement GPS grace period logic in SpeedometerScreen
4. Replace all direct FlutterOverlayWindow calls with OverlayService methods

**Estimated complexity:** Medium (refactor existing OverlayProvider and overlay screen)

**Blockers:** None - all foundation infrastructure complete

## Commits

1. **505219c** - feat(03-01): create OverlayService and add retry dependency
   - Added retry package (^3.1.2)
   - Created OverlayService wrapper with showOverlay, closeOverlay, shareData, isActive, overlayListener, checkPermission
   - Implemented 3-attempt retry with 200ms exponential backoff
   - Added staleness constants: 3s dim, 10s dash, 0.5 opacity, 1s check interval
   - Added GPS_GRACE_PERIOD constant (30 seconds)

2. **9e3decc** - feat(03-01): add timestamp field to OverlayMessage model
   - Added timestamp field with auto-population via DateTime.now()
   - Updated all factory constructors (updateDisplay, longPressClose, overlayClosed)
   - Serialized timestamp as millisecondsSinceEpoch in toMap()
   - Deserialized with fallback to DateTime.now() in fromMap()
   - Added timestamp parameter to copyWith()
   - Removed const modifiers for runtime timestamp values
