# Phase 3: Overlay Refactor - Context

**Gathered:** 2026-02-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix overlay data staleness and communication reliability. The floating overlay must receive continuous GPS updates without going stale, surface errors to the user instead of failing silently, and manage its lifecycle cleanly with the main app. No new overlay features — this phase makes the existing overlay work reliably.

</domain>

<decisions>
## Implementation Decisions

### Staleness handling
- Two-stage staleness indication: dim the last known speed value after 3 seconds of no GPS data, switch to "--" after 10 seconds
- 3-second threshold (not 2) to tolerate brief GPS dropouts in tunnels and urban canyons
- Recovery is immediate snap-back — no fade-in animation when fresh data arrives
- Staleness applies to the overlay display independently from the main app

### Error surfacing
- Overlay creation failures shown via snackbar in the main app (non-intrusive, auto-dismissing)
- Permission errors (SYSTEM_ALERT_WINDOW) include a "Settings" action button that opens the app permission page
- Mid-session communication failures surface in both places: overlay shows stale indicators, main app gets a snackbar about degraded communication
- Auto-recovery on communication failure — attempt to re-establish automatically, notify user only if retries exhaust

### Data flow model
- Forward every GPS tick to the overlay as it arrives (no fixed-interval batching)
- Overlay displays both speed and heading (compass direction)
- Theme and unit settings sync in real-time from main app to overlay (not launch-time only)
- Use structured/typed OverlayMessage model for all data payloads — explicit fields for speed, heading, unit, theme

### Overlay lifecycle
- GPS tracking continues when app is backgrounded as long as overlay is visible (core use case)
- 30-second GPS grace period after overlay close when app is in background (avoids cold-start delay on quick reopen)
- Overlay is tied to app process — when app is killed, overlay dies with it
- Heartbeat timer stays at 5-second interval (current value works)
- Heartbeat only runs when overlay is active and app is backgrounded (existing behavior preserved)

### Claude's Discretion
- Exact auto-recovery retry count and backoff strategy
- OverlayService internal architecture (encapsulation of flutter_overlay_window calls)
- Communication channel implementation details (how to detect channel death)
- Overlay dimming opacity value for stale state
- GPS grace period implementation mechanism

</decisions>

<specifics>
## Specific Ideas

- Two-stage staleness (dim then dashes) gives a gentle-then-clear signal — user is not alarmed by brief GPS hiccups but knows when data is genuinely gone
- Overlay should feel like a reliable instrument, not a widget that might or might not be showing current data
- "Settings" action on permission snackbar follows Android platform conventions for guiding users to fix permission issues

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-overlay-refactor*
*Context gathered: 2026-02-10*
