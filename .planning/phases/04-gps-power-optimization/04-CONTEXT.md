# Phase 4: GPS & Power Optimization - Context

**Gathered:** 2026-02-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement speed-adaptive GPS precision and lifecycle-aware power management. The app should use resources proportionally to what the user is doing -- high precision at speed, relaxed when slow, off when not needed. Overlay and main UI are two views of the same data set; behavior (staleness, precision, data source) should be consistent across both.

</domain>

<decisions>
## Implementation Decisions

### Background transitions
- When app backgrounds WITHOUT overlay visible: GPS stops after a short grace period (5-10 seconds), not immediately
- Grace period allows brief app-switching (checking a notification) without losing GPS fix
- When returning to foreground after GPS stopped: show last known speed until fresh data arrives (feels instant, briefly stale)
- When app backgrounds WITH overlay visible: full GPS precision at all times, no power-saving reduction
- User chose overlay = deliberate commitment to battery cost

### Precision change visibility
- GPS precision switching (high/balanced) is completely invisible to the user
- No indicators, no UI changes -- speed and heading just work
- Precision transitions logged for debug purposes only
- User-visible surface is speed (with units) and heading (with compass direction) -- nothing else
- Accuracy readout is debug-only territory

### Main app staleness
- Apply same staleness detection to main speed display as overlay: 3s dim, 10s dashes, immediate snap-back
- Overlay and main UI are two presentations of the same data -- same staleness rules apply to both
- This is a NEW behavior for the main app (overlay already has it from Phase 3)

### Power priority tradeoffs
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

</decisions>

<specifics>
## Specific Ideas

- "Overlay and main UI are two ways of displaying the same data set" -- high-level architectural principle. Same data source, same staleness, same behavior rules.
- Dashboard mounting use case: wake lock keeps screen on while actively tracking, whether using main app or overlay
- Battery saver as a soft constraint, not a hard override: the app still functions, just at reduced precision

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 04-gps-power-optimization*
*Context gathered: 2026-02-12*
