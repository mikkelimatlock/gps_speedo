# Phase 1: Foundation - Context

**Gathered:** 2026-02-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish architectural foundation by reorganizing the monolithic Flutter app into a modular directory structure, extracting data models, centralizing behavioral constants, and replacing raw print statements with a proper logger. All existing functionality must remain identical after reorganization.

</domain>

<decisions>
## Implementation Decisions

### Directory conventions
- Layer-first structure directly under lib/: screens/, widgets/, providers/, services/, models/, config/
- Flat widget structure — all widget files directly in widgets/, no subdirectories
- Overlay-specific code lives within the layer folders (overlay widgets in widgets/, overlay services in services/) rather than a dedicated overlay/ directory
- File names match class names exactly: GpsDataManager → gps_data_manager.dart

### Model extraction
- ProcessedGpsData, OverlayMessage, and a Theme model to be extracted
- Models are immutable — all fields final, changes via copyWith()
- Theme model holds all available color palettes internally, exposes only the current palette's named colors, a "current set name" label, and a rotate() method for cycling themes
- Persistence (SharedPreferences) handled separately from the theme model itself

### Claude's Discretion
- Whether models include formatting/serialization helpers (toMap, fromMap) based on current usage patterns
- Exact fields and structure of each model based on existing code analysis
- How theme palette rotation wraps (circular vs bounded)

### Constants organization
- Split by domain into separate files: config/gps_constants.dart, config/ui_constants.dart, config/timing_constants.dart, etc.
- Extract behavioral constants only (timeouts, thresholds, GPS settings, speed limits) — leave UI padding/sizing as inline values
- SCREAMING_SNAKE naming convention: GPS_TIMEOUT_SECONDS, SPEED_THRESHOLD_HIGH
- Grouped into abstract classes with static members: GpsConfig.TIMEOUT_SECONDS, TimingConfig.HEARTBEAT_INTERVAL

### Migration strategy
- Incremental migration — app must compile and run after each execution wave
- When files move, all imports updated immediately (no temporary re-exports)
- No intermediate broken states; each wave is a working checkpoint

### Debug logging
- Semi-proper logger with 4 verbosity levels: error, warn, info, debug
- Include caller name and timestamp in log output
- Replaces all existing unconditional print statements

</decisions>

<specifics>
## Specific Ideas

- Theme model mental model: "holds all possible colour palettes, exposing only the current set of colours (with their nametags), informative 'current set name', and a method for rotating themes"
- App must be runnable on a bench phone after each session/wave — this is a hard verification constraint
- Logger should feel like a proper utility, not just a debugPrint wrapper

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-02-09*
