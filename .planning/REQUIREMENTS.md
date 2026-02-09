# Requirements: GPS Speedometer Restructure

**Defined:** 2026-02-09
**Core Value:** Reliable, lag-free GPS speed display that coexists politely with other Android apps

## v1 Requirements

Requirements for the restructure milestone. Each maps to roadmap phases.

### Code organization

- [x] **ORG-01**: Code split into directory structure: `screens/`, `widgets/`, `services/`, `providers/`, `models/`, `config/`
- [x] **ORG-02**: `ProcessedGpsData` model extracted to `models/processed_gps_data.dart`
- [x] **ORG-03**: `SpeedUnit` and `ColorTheme` moved to `config/` directory
- [x] **ORG-04**: Constants file created with all magic numbers (timeouts, thresholds, overlay percentages)
- [x] **ORG-05**: Typed `OverlayMessage` class replaces unvalidated Map data for overlay communication
- [x] **ORG-06**: All unconditional `print()` replaced with Logger utility (debug-only logging with severity levels)
- [x] **ORG-07**: `SpeedometerScreen` extracted from monolithic `main.dart` to `screens/speedometer_screen.dart`
- [x] **ORG-08**: `OverlaySpeedometer` extracted to `screens/overlay_screen.dart`

### State management

- [ ] **STATE-01**: `SpeedometerProvider` (ChangeNotifier) manages GPS data stream subscription and speed/heading state
- [ ] **STATE-02**: `ThemeProvider` (ChangeNotifier) manages theme index and dark/light mode
- [ ] **STATE-03**: `OverlayProvider` (ChangeNotifier) manages overlay lifecycle and status
- [ ] **STATE-04**: `MultiProvider` setup in `main.dart` wiring services and providers
- [ ] **STATE-05**: All `setState()` calls in main screen replaced with Provider Consumer/Selector pattern
- [ ] **STATE-06**: Selector widgets used for granular rebuilds (speed display does not rebuild on theme change)
- [ ] **STATE-07**: GPS stream subscription managed by provider, not widget state

### Overlay reliability

- [ ] **OVRL-01**: Overlay receives continuous debounced data updates (not one-shot push + heartbeat)
- [ ] **OVRL-02**: Overlay errors surfaced to user via snackbar/toast (no silent catch blocks)
- [ ] **OVRL-03**: Overlay creation verified before setting `isOverlayActive` flag
- [ ] **OVRL-04**: Messages include timestamp for staleness detection in overlay
- [ ] **OVRL-05**: Overlay displays "--" when data is stale (no updates for >2 seconds)
- [ ] **OVRL-06**: `OverlayService` encapsulates all `FlutterOverlayWindow` platform calls

### GPS performance

- [ ] **GPS-01**: GPS data updates display with zero additional lag (stream subscription, no polling intermediary)
- [ ] **GPS-02**: Speed-adaptive precision: `LocationAccuracy.high` above ~10 km/h, `LocationAccuracy.medium` below
- [ ] **GPS-03**: Hysteresis on precision switching: up at ~12 km/h, down at ~8 km/h (no thrashing)
- [ ] **GPS-04**: GPS access is non-exclusive — uses Fused Location Provider, other apps access location normally

### Power & lifecycle

- [ ] **PWR-01**: GPS tracking stops when app backgrounded without overlay visible
- [ ] **PWR-02**: GPS tracking continues when app backgrounded with overlay visible
- [ ] **PWR-03**: Heartbeat timer only runs when overlay is active and app is backgrounded
- [ ] **PWR-04**: Overlay status polling only runs when overlay is active
- [ ] **PWR-05**: Wake lock only held when actively tracking with overlay visible
- [ ] **PWR-06**: All timers and stream subscriptions properly canceled in dispose()

### Backward compatibility

- [ ] **COMPAT-01**: All existing features continue to work after restructure (speed display, gauge, theme, units, overlay, haptics)
- [ ] **COMPAT-02**: App compiles and runs without new dependencies beyond `provider` package
- [ ] **COMPAT-03**: No changes to Android manifest permissions or service declarations

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Testing

- **TEST-01**: Unit tests for ProcessedGpsData model and speed unit conversions
- **TEST-02**: Widget tests for extracted widgets with mocked providers
- **TEST-03**: Integration tests for GPS → Provider → Widget data flow
- **TEST-04**: Manual test checklist for overlay lifecycle edge cases

### Persistence

- **PERSIST-01**: Speed unit preference persisted via SharedPreferences
- **PERSIST-02**: Theme preference persisted via SharedPreferences
- **PERSIST-03**: Settings load on app startup

### Error recovery

- **ERR-01**: Permission re-request button when GPS shows 'NO PERM'
- **ERR-02**: Permission re-check on app resume (handle runtime revocation)

## Out of scope

| Feature | Reason |
|---------|--------|
| New UI features | This is a restructure, not a feature release |
| Dedicated settings screen | Inline toggles sufficient for current scope |
| GPS interpolation between fixes | Display what hardware gives, instantly |
| iOS testing or optimization | Android primary |
| Riverpod migration | Provider sufficient for single-screen app complexity |
| Dependency version upgrades | Keep current versions stable during restructure |
| BLoC pattern | Over-engineered for this app's complexity |
| Feature-first directory structure | Layer-first appropriate for single-screen app |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ORG-01 | Phase 1 | Complete |
| ORG-02 | Phase 1 | Complete |
| ORG-03 | Phase 1 | Complete |
| ORG-04 | Phase 1 | Complete |
| ORG-05 | Phase 1 | Complete |
| ORG-06 | Phase 1 | Complete |
| ORG-07 | Phase 1 | Complete |
| ORG-08 | Phase 1 | Complete |
| STATE-01 | Phase 2 | Pending |
| STATE-02 | Phase 2 | Pending |
| STATE-03 | Phase 2 | Pending |
| STATE-04 | Phase 2 | Pending |
| STATE-05 | Phase 2 | Pending |
| STATE-06 | Phase 2 | Pending |
| STATE-07 | Phase 2 | Pending |
| OVRL-01 | Phase 3 | Pending |
| OVRL-02 | Phase 3 | Pending |
| OVRL-03 | Phase 3 | Pending |
| OVRL-04 | Phase 3 | Pending |
| OVRL-05 | Phase 3 | Pending |
| OVRL-06 | Phase 3 | Pending |
| GPS-01 | Phase 4 | Pending |
| GPS-02 | Phase 4 | Pending |
| GPS-03 | Phase 4 | Pending |
| GPS-04 | Phase 4 | Pending |
| PWR-01 | Phase 4 | Pending |
| PWR-02 | Phase 4 | Pending |
| PWR-03 | Phase 4 | Pending |
| PWR-04 | Phase 4 | Pending |
| PWR-05 | Phase 4 | Pending |
| PWR-06 | Phase 4 | Pending |
| COMPAT-01 | All | Pending |
| COMPAT-02 | All | Pending |
| COMPAT-03 | All | Pending |

**Coverage:**
- v1 requirements: 30 total
- Mapped to phases: 30
- Unmapped: 0

---
*Requirements defined: 2026-02-09*
*Last updated: 2026-02-09 (Phase 1 requirements marked Complete)*
