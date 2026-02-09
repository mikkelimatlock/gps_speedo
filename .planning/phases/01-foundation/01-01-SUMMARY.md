---
phase: 01-foundation
plan: 01
subsystem: infrastructure
tags: [logger, constants, models, directory-structure, refactoring]
requires: []
provides:
  - Logger utility with 4 severity levels (error, warn, info, debug)
  - GPS behavioral constants (GpsConfig)
  - Timing constants (TimingConfig)
  - Overlay display constants (OverlayConfig)
  - ProcessedGpsData immutable model
  - OverlayMessage typed IPC class
  - ThemeModel with palette rotation
  - SpeedUnit enum in config/
  - ColorThemes classes in config/
  - Layer-first directory structure (screens/, widgets/, providers/, models/, config/, services/)
affects:
  - 01-02 (will use Logger and constants)
  - 01-03 (will use models)
  - All subsequent Phase 1 and Phase 2 plans (depend on this foundational structure)
tech-stack:
  added: []
  patterns:
    - "SCREAMING_SNAKE naming for behavioral constants"
    - "Abstract static classes for constant grouping"
    - "Typed IPC messages with toMap()/fromMap() serialization"
    - "Logger with ANSI color-coded severity levels"
key-files:
  created:
    - lib/services/logger.dart
    - lib/config/gps_constants.dart
    - lib/config/timing_constants.dart
    - lib/config/overlay_constants.dart
    - lib/config/speed_unit.dart
    - lib/config/color_themes.dart
    - lib/models/processed_gps_data.dart
    - lib/models/overlay_message.dart
    - lib/models/theme_model.dart
    - lib/screens/ (directory)
    - lib/widgets/ (directory)
    - lib/providers/ (directory)
    - lib/models/ (directory)
    - lib/config/ (directory)
  modified:
    - lib/services/gps_data_manager.dart
    - lib/gps_service.dart
    - lib/main.dart
  deleted:
    - lib/speed_units.dart
    - lib/color_themes.dart
key-decisions:
  - decision: "Use SCREAMING_SNAKE naming for behavioral constants"
    rationale: "Per PROJECT.md Key Decisions table - distinguishes config constants from regular variables"
    impact: "All future constants follow this pattern"
  - decision: "Logger replaces print()/customDebugPrint() globally"
    rationale: "Standardized logging with severity levels, ANSI color coding, timestamps, and kDebugMode guards"
    impact: "All future code uses Logger.error/warn/info/debug"
  - decision: "OverlayMessage typed class for IPC instead of raw Maps"
    rationale: "Type safety, validation, factory constructors for common patterns, eliminates Map key typos"
    impact: "All overlay communication uses OverlayMessage.toMap()/fromMap()"
  - decision: "ThemeModel delegates to ColorThemes for palette storage"
    rationale: "Avoids duplicating static palette data while providing rotation API user expects"
    impact: "Future theme management can extend ThemeModel without touching ColorThemes"
duration: 12.8
completed: 2026-02-09
---

# Phase 1 Plan 01: Foundation Infrastructure Summary

**One-liner:** Logger utility, 5 constants files, 3 data models extracted, layer-first directory structure established — all imports rewired, zero analyzer errors.

## Performance

**Execution:**
- Duration: 12.8 minutes (769 seconds)
- Start: 2026-02-09T21:20:45Z
- End: 2026-02-09T21:33:34Z
- Tasks: 3/3 completed
- Commits: 3 (one per task)
- Files modified: 16 files (9 created, 3 modified, 2 deleted, 2 directories)

**Complexity handled:**
- 79 print/customDebugPrint calls replaced with Logger calls across main.dart
- 27 print calls replaced in gps_data_manager.dart
- All magic numbers (timeouts, sizing ratios, intervals) replaced with named constants
- Overlay IPC converted from raw Maps to typed OverlayMessage class
- Zero analyzer errors after restructuring

## Accomplishments

### Infrastructure Created

**1. Logger Utility (`lib/services/logger.dart`)**
- 4 severity levels: error (red), warn (yellow), info (blue), debug (gray)
- ANSI color-coded output with ISO 8601 timestamps
- Optional caller tags: `Logger.error('message', 'GpsDataManager')`
- All output guarded by `kDebugMode` to avoid production logs
- Uses `debugPrint()` to prevent log truncation
- Replaces 106+ print/customDebugPrint calls across codebase

**2. Constants Files (SCREAMING_SNAKE naming)**

**`lib/config/gps_constants.dart` (GpsConfig):**
- `STALE_DATA_THRESHOLD`: 4s before marking GPS data stale
- `INITIAL_FIX_TIMEOUT`: 20s for cold start GPS acquisition
- `UPDATE_TIMEOUT`: 2s for ongoing updates (indoor detection)
- `VALID_HEADING_MIN/MAX`: 0-360° heading range validation
- `LOW_SPEED_THRESHOLD`: 1.0 m/s below which heading unreliable

**`lib/config/timing_constants.dart` (TimingConfig):**
- `HEARTBEAT_INTERVAL`: 5s background keepalive when overlay active
- `OVERLAY_STATUS_CHECK_INTERVAL`: 1s polling for overlay status
- `TAP_CLOSE_DELAY`: 500ms debounce for tap-to-close
- `LONG_PRESS_SIGNAL_DELAY`: 50ms IPC signal propagation delay

**`lib/config/overlay_constants.dart` (OverlayConfig):**
- `WIDTH_PERCENTAGE`: 0.45 (overlay 45% of screen width)
- `ASPECT_RATIO`: 0.6 (height = 60% of width)
- `BACKGROUND_OPACITY`: 0.85
- `BORDER_OPACITY`: 0.3
- `FONT_SIZE_RATIO`: 0.2 (speed font = 20% of overlay width)
- `UNIT_FONT_RATIO`: 0.6 (unit text = 60% of speed font)
- `ICON_SIZE_RATIO`: 0.72 (navigation icon = 72% of speed font)
- `HEADING_FONT_RATIO`: 0.4 (heading text = 40% of speed font)
- `DEFAULT_SCREEN_WIDTH/OVERLAY_WIDTH/HEIGHT`: Fallback dimensions

**3. Data Models**

**`lib/models/processed_gps_data.dart` (ProcessedGpsData):**
- Extracted from gps_data_manager.dart (lines 6-40)
- Immutable with copyWith() method
- Fields: speed, heading, displaySpeed, displayHeading, isSpeedValid, isHeadingValid
- Pure Dart class, no Flutter dependencies

**`lib/models/overlay_message.dart` (OverlayMessage):**
- Typed replacement for unvalidated Map IPC data
- Fields: action, speedText, unitText, headingText, heading, unitIndex, themeIndex, overlayWidth, overlayHeight
- Factory constructors: `updateDisplay()`, `longPressClose()`, `overlayClosed()`
- Serialization: `toMap()` / `fromMap()` for FlutterOverlayWindow IPC
- Eliminates Map key typos, provides compile-time type safety

**`lib/models/theme_model.dart` (ThemeModel):**
- Wraps ColorThemes with state management
- Exposes: `current` (ColorTheme), `currentSetName` (String), `currentIndex` (int)
- Methods: `rotate()` for circular theme cycling, `copyWith()` for state updates
- Delegates palette storage to ColorThemes (avoids duplication)

**4. Config Files Moved**

**`lib/config/speed_unit.dart`:**
- Moved from lib/speed_units.dart (old file deleted)
- SpeedUnit enum with label, multiplier, convert(), next() methods
- All imports updated from 'speed_units.dart' to 'config/speed_unit.dart'

**`lib/config/color_themes.dart`:**
- Moved from lib/color_themes.dart (old file deleted)
- ColorTheme + ColorThemes classes with 4 palettes
- All imports updated from 'color_themes.dart' to 'config/color_themes.dart'

**5. Directory Structure**

Created layer-first architecture:
- `lib/screens/` - UI screens (future SpeedScreen, SettingsScreen)
- `lib/widgets/` - Reusable widgets (future SpeedDisplay, GaugeWidget)
- `lib/providers/` - State management providers (future GpsProvider, ThemeProvider)
- `lib/models/` - Data models (ProcessedGpsData, OverlayMessage, ThemeModel)
- `lib/config/` - Configuration constants and enums
- `lib/services/` - Business logic services (already existed)

## Task Commits

| Task | Name                                                                 | Commit  | Files Changed                                                                                                                                                                   |
| ---- | -------------------------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | Create directory structure, Logger utility, and constants files      | 2b2fc8f | lib/screens/, lib/widgets/, lib/providers/, lib/models/, lib/config/, lib/services/logger.dart, lib/config/gps_constants.dart, lib/config/timing_constants.dart, lib/config/overlay_constants.dart |
| 2    | Move config files and extract data models                            | 5122be4 | lib/config/speed_unit.dart, lib/config/color_themes.dart, lib/models/processed_gps_data.dart, lib/models/overlay_message.dart, lib/models/theme_model.dart                                      |
| 3    | Rewire all imports, replace print() with Logger, delete old files    | a0d93d7 | lib/services/gps_data_manager.dart, lib/gps_service.dart, lib/main.dart, deleted lib/speed_units.dart, deleted lib/color_themes.dart                                                             |

## Files Created/Modified

**Created (11 files + 5 directories):**
- lib/services/logger.dart (57 lines) - Logger utility with 4 severity levels
- lib/config/gps_constants.dart (24 lines) - GPS behavioral constants
- lib/config/timing_constants.dart (18 lines) - Timer and interval constants
- lib/config/overlay_constants.dart (39 lines) - Overlay sizing constants
- lib/config/speed_unit.dart (20 lines) - Speed unit enum
- lib/config/color_themes.dart (64 lines) - Color theme definitions
- lib/models/processed_gps_data.dart (37 lines) - GPS data model
- lib/models/overlay_message.dart (116 lines) - Typed overlay IPC message
- lib/models/theme_model.dart (32 lines) - Theme model with rotation
- lib/screens/ (directory)
- lib/widgets/ (directory)
- lib/providers/ (directory)
- lib/models/ (directory)
- lib/config/ (directory)

**Modified (3 files):**
- lib/services/gps_data_manager.dart (removed ProcessedGpsData class, added imports, replaced 27 print calls with Logger, applied GpsConfig constants)
- lib/gps_service.dart (added GpsConfig import, replaced heading validation magic numbers)
- lib/main.dart (removed customDebugPrint function, added imports, replaced 79 print/customDebugPrint calls with Logger, replaced overlay IPC Maps with OverlayMessage, applied TimingConfig/OverlayConfig constants)

**Deleted (2 files):**
- lib/speed_units.dart (moved to config/speed_unit.dart)
- lib/color_themes.dart (moved to config/color_themes.dart)

## Decisions Made

**1. SCREAMING_SNAKE naming for behavioral constants**
- **Context:** Need consistent naming pattern to distinguish config constants from regular variables
- **Decision:** Use SCREAMING_SNAKE_CASE for all constants in config/ files
- **Rationale:** Per PROJECT.md Key Decisions table - matches backend convention, highly visible in code, clear intent
- **Impact:** Triggers analyzer info warnings (intentional), all future constants follow this pattern
- **Trade-offs:** Deviates from Dart style guide (lowerCamelCase), but project convention takes precedence

**2. Logger replaces print()/customDebugPrint() globally**
- **Context:** 106+ print/customDebugPrint calls across codebase with inconsistent formatting
- **Decision:** Create Logger utility with 4 severity levels (error, warn, info, debug), ANSI color coding, timestamps, caller tags
- **Rationale:** Standardized logging improves debugging, severity levels enable filtering, color coding improves readability, kDebugMode guards prevent production logs
- **Impact:** All future code uses Logger.error/warn/info/debug, zero bare print() calls allowed
- **Trade-offs:** Slightly more verbose than print(), but significantly better maintainability

**3. OverlayMessage typed class for IPC**
- **Context:** Overlay communication uses raw Map with string keys like `{'action': 'updateDisplay', 'speedText': '42.5', ...}`
- **Decision:** Create typed OverlayMessage class with toMap()/fromMap() serialization, factory constructors for common patterns
- **Rationale:** Type safety eliminates Map key typos (compile-time vs runtime errors), factory constructors enforce correct message structure, self-documenting API
- **Impact:** All overlay communication uses OverlayMessage.updateDisplay(...).toMap() and OverlayMessage.fromMap(data)
- **Trade-offs:** Adds one class, but prevents entire category of runtime bugs

**4. ThemeModel delegates to ColorThemes**
- **Context:** User mental model: "ThemeModel holds all palettes, exposes current set, has rotate() method"
- **Decision:** ThemeModel wraps ColorThemes (which holds static palette list), exposes `current` property and `rotate()` method
- **Rationale:** Delegation pattern avoids duplicating static palette data while providing the API user expects, separation of concerns (ColorThemes = data, ThemeModel = behavior)
- **Impact:** Future theme management extends ThemeModel, ColorThemes remains unchanged
- **Trade-offs:** Adds indirection layer, but better separation of concerns

**5. Layer-first directory structure**
- **Context:** Need modular architecture for Phase 2 provider migration
- **Decision:** Create screens/, widgets/, providers/, models/, config/, services/ directories
- **Rationale:** Layer-first (vs feature-first) matches small app size, clear separation of concerns, aligns with Provider pattern migration in Phase 2
- **Impact:** All future code organized by layer, easy to find files by responsibility
- **Trade-offs:** Slightly longer import paths, but better organization as app grows

## Deviations from Plan

None - plan executed exactly as written.

All tasks completed successfully:
- Task 1: Directory structure, Logger, 3 constants files created
- Task 2: 2 config files moved, 3 data models extracted
- Task 3: All imports rewired, 106+ logging calls replaced, 2 old files deleted

## Issues Encountered

**Issue 1: Missing ProcessedGpsData import in main.dart**
- **Discovered:** During Task 3 verification, flutter analyze showed "Undefined class 'ProcessedGpsData'" errors
- **Root cause:** Forgot to add `import 'models/processed_gps_data.dart';` when updating main.dart imports
- **Resolution:** Added missing import, analyzer errors cleared immediately
- **Category:** Rule 1 (Bug) - Missing critical import
- **Impact:** 2-minute fix, no architectural changes

**No other issues encountered.** Plan was well-structured with clear, atomic tasks. All verification checks passed.

## Next Phase Readiness

**Phase 1 Plan 02 prerequisites: ✅ READY**
- Logger utility available for all future code
- Constants files ready to use in remaining Phase 1 plans
- Models extracted and ready for provider integration
- Directory structure established for widget/screen extraction

**Blockers for future plans:** None

**Concerns:**
- **SCREAMING_SNAKE analyzer warnings:** 21 info-level "constant_identifier_names" warnings intentional per project convention. These are NOT errors and do not affect compilation. Future plans will add more SCREAMING_SNAKE constants, increasing warning count. Consider adding `analysis_options.yaml` rule exclusion if warnings become noise.

**Recommendations:**
- Consider adding `analysis_options.yaml` to suppress `constant_identifier_names` warnings for config/ directory
- Document Logger severity level usage guidelines in CONTRIBUTING.md (when to use error vs warn vs info vs debug)
- Consider adding Logger.trace() level for ultra-verbose GPS coordinate logging if needed in Phase 4

**Ready to proceed with Phase 1 Plan 02.**
