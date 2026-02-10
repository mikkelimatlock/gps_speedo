# Phase 2: Provider Migration - Context

**Gathered:** 2026-02-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace raw `setState()` calls with Provider pattern (ChangeNotifier/Consumer) for reactive state management. Wire all shared app state through the widget tree. Remove trip tracking feature entirely. This phase does not fix overlay reliability or GPS optimization — those are Phases 3 and 4.

</domain>

<decisions>
## Implementation Decisions

### State granularity
- **Separate providers per concern**: GpsDataManager (extends ChangeNotifier), SettingsProvider (theme + units combined), OverlayProvider
- No TripProvider — trip tracking (distance, trip time, trip reset) is being **removed entirely**
- Metrics panel UI removed entirely — no coordinates/accuracy/distance display
- GpsDataManager exposes only live GPS data: speed, heading, accuracy, position

### Singleton lifecycle
- GpsDataManager **extends ChangeNotifier directly** (not wrapped by a separate provider)
- **Singleton accessor removed** — all access goes through Provider via BuildContext
- Placed at **root of widget tree** — disposed with app shutdown, not navigation
- SettingsProvider loads eagerly from **pre-initialized SharedPreferences** in main() — no splash, no flash of defaults

### Overlay data flow
- **OverlayProvider owns all overlay messaging** — GPS data, theme, units all pushed from one place
- OverlayProvider listens to GpsDataManager stream continuously, **skips sends when overlay inactive** (if-check, not unsubscribe)
- OverlayProvider reads from SettingsProvider for theme/unit changes
- **Heartbeat/polling mechanism stripped** during migration — replaced with simple boolean flag. Phase 3 builds proper detection.

### Migration strategy
- **Big bang migration** — all providers wired in one pass, no temporary coexistence of setState and Provider
- `setState` **preserved for purely local widget state** (animation toggles, expand/collapse) — Provider for all shared/app state
- **Granular Consumer/Selector widgets** — wrap individual widgets that depend on specific state (e.g., speed text, heading text), not broad screen sections
- Trip data, metrics panel, and all related code **removed in this phase**

### Claude's Discretion
- Exact Consumer vs Selector usage per widget (performance optimization choices)
- Provider initialization order and MultiProvider arrangement
- How to handle permission state (whether it needs its own provider or stays procedural)
- Timer and stream subscription cleanup patterns in dispose

</decisions>

<specifics>
## Specific Ideas

- GpsDataManager already has broadcast streams — migration path is: add ChangeNotifier mixin, call notifyListeners() from existing stream handlers, remove singleton factory
- SettingsProvider replaces the inline theme/unit cycling logic that currently lives in SpeedometerScreen
- Overlay communication simplification: strip polling timer, keep only the shareData() push mechanism with active/inactive boolean

</specifics>

<deferred>
## Deferred Ideas

- Trip tracking / route recording — explicitly removed, could return as a future milestone feature
- Metrics panel with coordinates/accuracy — removed, could return as debug/developer mode
- Overlay reliability fixes (stale data, detection) — Phase 3
- GPS adaptive precision — Phase 4

</deferred>

---

*Phase: 02-provider-migration*
*Context gathered: 2026-02-10*
