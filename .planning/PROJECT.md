# GPS Speedometer — Restructure & Android QoL

## What this is

A restructure of the existing Flutter GPS speedometer app, splitting a 1,075-line monolithic `main.dart` into a modular architecture with proper state management, and improving Android quality of life — particularly the floating window overlay reliability, GPS response latency, and power behavior. This is not a feature expansion. It is a foundation rebuild for the same app.

## Core value

Reliable, lag-free GPS speed display that coexists politely with other Android apps.

## Requirements

### Validated

These exist and work in the current codebase.

- ✓ Real-time GPS speed tracking with accuracy monitoring — existing
- ✓ Speed units (km/h, mph, knots) with quick selector — existing
- ✓ Dual display styles: digital speedometer + analog gauge — existing
- ✓ Dark/light theme support with cycling — existing
- ✓ Optional metrics panel: coordinates, distance, trip time, accuracy — existing
- ✓ Trip reset functionality — existing
- ✓ Portrait/landscape orientation support — existing
- ✓ Android permissions handling (FINE_LOCATION, COARSE_LOCATION, SYSTEM_ALERT_WINDOW) — existing
- ✓ Floating window overlay showing speed + heading — existing (buggy)
- ✓ GpsDataManager singleton for centralized GPS processing — existing
- ✓ Haptic feedback on main UI interactions — existing
- ✓ Heading display with compass bearing — existing

### Active

Architecture:

- [ ] Modularize code into `screens/`, `widgets/`, `services/`, `providers/`, `models/` directories
- [ ] Replace raw `setState()` with proper Provider pattern (ChangeNotifier/Consumer)
- [ ] Extract overlay management from SpeedometerScreen into dedicated controller/service
- [ ] Define typed message schema for main↔overlay communication (replace unvalidated Maps)
- [ ] Replace unconditional `print()` calls with conditional debug logging (`customDebugPrint`)

Overlay reliability:

- [ ] Fix overlay data pipeline — data stops updating after running for a while
- [ ] Surface overlay errors to user (snackbar/toast instead of silent catch)
- [ ] Verify overlay creation succeeded before setting `_isOverlayActive = true`
- [ ] Remove or fix unreliable overlay status polling (1-second timer workaround)

GPS performance:

- [ ] Eliminate lag between GPS hardware fix and display update
- [ ] Speed-adaptive GPS precision: HIGH_ACCURACY above ~10 km/h, BALANCED_POWER below, with hysteresis (~8/12 km/h thresholds)
- [ ] Non-exclusive, non-locking GPS access — other apps use location normally

Power & background:

- [ ] Smart background GPS: active when overlay is visible, stopped when not
- [ ] Stop heartbeat timer when not needed (foreground + no overlay)
- [ ] Remove unnecessary wake locks — only hold when actively tracking with overlay
- [ ] Cache overlay size calculation instead of recalculating on every build

### Out of scope

- New features or UI additions — this is a restructure, not a feature release
- Dedicated settings screen — inline toggles stay as-is
- GPS interpolation or prediction between hardware fixes — display what hardware gives, instantly
- iOS testing or optimization — Android primary
- New overlay content — speed + unit + heading stays
- Comprehensive unit/integration test suite — important but separate milestone
- Dependency version upgrades — keep current versions stable

## Context

The app is a working GPS speedometer at v2.3.0-dev on the `feature/gps-manager-architecture` branch. The core problem is architectural: `main.dart` is a monolith where `SpeedometerScreen` alone is ~780 lines managing GPS subscriptions, overlay lifecycle, theme cycling, unit cycling, haptic feedback, background heartbeat, overlay status polling, and gesture handling. This makes every fix a surgical operation in a crowded file.

The `flutter_overlay_window` package has known limitations — bidirectional communication is unreliable, and the current heartbeat/polling approach is a workaround for message-based detection failures. The data pipeline going stale is likely related to timer lifecycle and stream subscription management.

Provider is already a dependency but unused — the app relies on `setState()` throughout. The restructure should wire Provider properly so state flows reactively across extracted widgets.

The GPS cooperative access constraint is important: the app uses Android's Fused Location Provider (via geolocator), which is inherently shared. But holding continuous HIGH_ACCURACY streams with wake locks is aggressive. Speed-adaptive precision reduces this to "high when actually moving, balanced when not."

SharedPreferences is mentioned in CLAUDE.md as implemented but is not actually integrated — settings reset on app restart. This is a known gap but out of scope for this restructure.

## Constraints

- **Platform**: Android primary — iOS exists but is untested and not a target
- **GPS bus**: Must be non-exclusive, non-locking — other apps access location normally
- **Power**: Mixed use — sometimes charging (car), sometimes battery (cycling, walking)
- **Overlay library**: `flutter_overlay_window 0.5.0` has known bidirectional communication issues — design around them
- **Tech stack**: Flutter/Dart, keep existing dependency set — no new major dependencies
- **Backward compatibility**: All current features must continue to work after restructure

## Key decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Speed-adaptive GPS precision (~10 km/h threshold with hysteresis) | Balances responsiveness when moving with cooperative behavior when stationary | — Pending |
| Provider pattern for state management | Already a dependency, fits Flutter idiom, enables reactive updates across extracted widgets | — Pending |
| Background GPS only when overlay visible | No reason to track location if user can't see the data | — Pending |
| Directory structure: screens/, widgets/, services/, providers/, models/ | Standard Flutter convention, separates concerns cleanly | — Pending |
| No new dependencies | Stability — restructure existing code, don't introduce new moving parts | — Pending |

---
*Last updated: 2026-02-09 after initialization*
