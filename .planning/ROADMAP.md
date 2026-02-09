# Roadmap: GPS Speedometer Restructure

## Overview

This roadmap transforms a 1,133-line monolithic Flutter app into a maintainable MVVM architecture with proper state management. The journey moves from file organization through Provider migration to overlay communication fixes and GPS optimization, delivering the same features with better reliability, battery efficiency, and code maintainability.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation** - Establish directory structure and extract models
- [ ] **Phase 2: Provider Migration** - Replace setState with proper state management
- [ ] **Phase 3: Overlay Refactor** - Fix overlay communication reliability
- [ ] **Phase 4: GPS & Power Optimization** - Implement adaptive precision and lifecycle management

## Phase Details

### Phase 1: Foundation

**Goal**: Establish architectural foundation with modular file structure and extracted models

**Depends on**: Nothing (first phase)

**Requirements**: ORG-01, ORG-02, ORG-03, ORG-04, ORG-05, ORG-06, ORG-07, ORG-08

**Success Criteria** (what must be TRUE):
  1. Code organized into screens/, widgets/, providers/, services/, models/, config/ directories
  2. ProcessedGpsData and OverlayMessage models exist as separate files with proper typing
  3. All magic numbers moved to centralized constants file with clear names
  4. Debug logging uses customDebugPrint instead of unconditional print statements
  5. App compiles and runs with identical functionality after reorganization

**Plans**: 2 plans

Plans:
- [ ] 01-01-PLAN.md — Infrastructure, Logger, Constants, Models extraction
- [ ] 01-02-PLAN.md — Screen extraction (SpeedometerScreen + OverlaySpeedometer)

### Phase 2: Provider Migration

**Goal**: Replace raw setState with Provider pattern for reactive state management

**Depends on**: Phase 1

**Requirements**: STATE-01, STATE-02, STATE-03, STATE-04, STATE-05, STATE-06, STATE-07

**Success Criteria** (what must be TRUE):
  1. SpeedometerProvider manages GPS stream subscription and exposes speed/heading data
  2. ThemeProvider and OverlayProvider manage their respective state with ChangeNotifier
  3. Main screen uses Consumer/Selector widgets instead of setState calls
  4. Speed display updates without rebuilding theme controls
  5. All timers and stream subscriptions properly canceled in dispose
  6. App runs without "setState after dispose" or "ChangeNotifier after dispose" errors

**Plans**: TBD (2-3 plans expected)

Plans:
- [ ] 02-01: [To be planned]

### Phase 3: Overlay Refactor

**Goal**: Fix overlay data staleness and communication reliability issues

**Depends on**: Phase 2

**Requirements**: OVRL-01, OVRL-02, OVRL-03, OVRL-04, OVRL-05, OVRL-06

**Success Criteria** (what must be TRUE):
  1. Overlay receives continuous GPS updates without going stale
  2. Overlay displays "--" when data is more than 2 seconds old
  3. Overlay creation failures surface to user via snackbar instead of silent failure
  4. OverlayService encapsulates all flutter_overlay_window platform calls
  5. Heartbeat timer only runs when overlay active and app backgrounded
  6. Overlay shows current speed and heading that matches main app display

**Plans**: TBD (1-2 plans expected)

Plans:
- [ ] 03-01: [To be planned]

### Phase 4: GPS & Power Optimization

**Goal**: Implement speed-adaptive GPS precision and lifecycle-aware power management

**Depends on**: Phase 2

**Requirements**: GPS-01, GPS-02, GPS-03, GPS-04, PWR-01, PWR-02, PWR-03, PWR-04, PWR-05, PWR-06

**Success Criteria** (what must be TRUE):
  1. GPS data updates display with zero additional processing lag
  2. GPS accuracy switches to HIGH when speed exceeds 12 km/h, switches to BALANCED when below 8 km/h
  3. GPS tracking stops when app backgrounded without overlay visible
  4. GPS tracking continues when app backgrounded with overlay visible
  5. Wake lock only held when actively tracking with overlay
  6. Other apps can access location normally while GPS Speedometer runs

**Plans**: TBD (2-3 plans expected)

Plans:
- [ ] 04-01: [To be planned]

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 0/2 | Planned | - |
| 2. Provider Migration | 0/TBD | Not started | - |
| 3. Overlay Refactor | 0/TBD | Not started | - |
| 4. GPS & Power Optimization | 0/TBD | Not started | - |

## Notes

**Backward Compatibility**: Requirements COMPAT-01, COMPAT-02, COMPAT-03 apply to all phases and will be verified at phase completion:
- COMPAT-01: All existing features continue to work (verified per phase)
- COMPAT-02: No new dependencies beyond provider package (verified at end)
- COMPAT-03: No manifest permission changes (verified at end)

**Phase Independence**: Phase 3 and Phase 4 can potentially run in parallel after Phase 2 completes, as they have no direct dependencies on each other.

**Research Flags**: Phase 2 and Phase 3 are HIGH/MEDIUM risk due to async lifecycle complexity and overlay isolate communication issues. Manual regression testing required after each phase.

---
*Roadmap created: 2026-02-09*
*Last updated: 2026-02-09 (Phase 1 planned)*
