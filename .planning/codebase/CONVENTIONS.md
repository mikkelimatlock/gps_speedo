# Coding Conventions

**Analysis Date:** 2026-02-09

## Naming Patterns

**Files:**
- snake_case for file names: `gps_service.dart`, `color_themes.dart`, `speed_units.dart`
- Underscore prefix for internal/private files: `gps_data_manager.dart` in `services/` directory

**Classes:**
- PascalCase: `GpsService`, `ColorTheme`, `ColorThemes`, `GpsDataManager`, `ProcessedGpsData`
- State classes use underscore prefix: `_SpeedometerScreenState`, `_OverlaySpeedometerState`
- Widget classes standard PascalCase: `SpeedoApp`, `SpeedometerScreen`, `OverlaySpeedometer`

**Functions:**
- camelCase for all functions and methods: `initialize()`, `requestPermissions()`, `getFormattedSpeed()`, `_onPositionUpdate()`, `_onGpsError()`
- Private/internal functions use underscore prefix: `_updateData()`, `_scheduleStaleDataTimer()`, `_buildPortraitLayout()`
- Single-purpose private methods are common: `_cycleUnit()`, `_cycleTheme()`, `_handleOverlayClose()`

**Variables:**
- camelCase for instance and local variables: `_currentUnit`, `_currentThemeIndex`, `displaySpeed`, `speedText`
- Underscore prefix for private fields: `_gpsSubscription`, `_currentData`, `_isOverlayActive`, `_errorMessage`
- Boolean variables include descriptive names: `_isInitialized`, `_isSpeedValid`, `_isHeadingValid`, `_isInBackground`

**Types:**
- PascalCase for enums: `SpeedUnit` with enum values in lowercase: `kmh`, `mph`, `knots`
- Data classes: `ProcessedGpsData`, `ColorTheme` with named constructors using `const`

**Constants:**
- UPPER_CASE with underscore prefix for private constants: `_staleDataThreshold`
- camelCase for enum members: `kmh`, `mph`, `knots`, `themes`

## Code Style

**Formatting:**
- 2-space indentation throughout all Dart files
- Lines typically kept under 100 characters but pragmatically longer when needed (examples: line 671-672 in main.dart for complex expressions)
- Single newline between method definitions
- Double newline between class definitions

**Linting:**
- Uses `flutter_lints: ^6.0.0` from pubspec.yaml
- Configured via `analysis_options.yaml` with `include: package:flutter_lints/flutter.yaml`
- Explicit `exclude` pattern for backup directories: `backup_v1.1/**`

**Language Features:**
- Uses `const` constructors for immutable data classes: `const ProcessedGpsData(...)`, `const ColorTheme(...)`
- Enum with properties: `SpeedUnit` enum includes label and multiplier
- Named parameters with required keyword: `required this.speed`, `required this.label`
- Null safety enabled by default (Dart 3.9+)

## Import Organization

**Order:**
1. Dart SDK imports: `import 'dart:async'`, `import 'dart:math'`
2. Flutter framework imports: `import 'package:flutter/material.dart'`, `import 'package:flutter/foundation.dart'`
3. Third-party package imports: `import 'package:geolocator/geolocator.dart'`, `import 'package:permission_handler/permission_handler.dart'`
4. Relative imports (local files): `import 'speed_units.dart'`, `import 'services/gps_data_manager.dart'`

**Path Aliases:**
- No path aliases configured - uses explicit relative imports
- Deep imports work from lib root: `import 'services/gps_data_manager.dart'` from main.dart, `import '../speed_units.dart'` from services/gps_data_manager.dart

**Import Annotations:**
- Uses `as` for disambiguation: `import 'dart:math' as math;` to access `math.pi`
- Comments inline with imports for clarity: `import 'package:flutter/foundation.dart'; // For kDebugMode`

## Error Handling

**Patterns:**
- Try-catch blocks with specific error handling: 15 try-catch blocks across codebase
- Error messages propagated through `setState()`: `setState(() => _errorMessage = 'Failed to initialize GPS manager')`
- Silent error handling in production code: catch blocks with `customDebugPrint()` only - see `_showFloatingWindow()` line 480
- Stack trace logging: `catch (e, stackTrace)` pattern used consistently in GPS manager and main app
- Error display in UI: `_errorMessage` variable checked in build methods and displayed when non-empty

**Error Message Patterns:**
- Prefixed error states in GPS manager: `'GPS OFF'`, `'NO PERM'`, `'GPS ERR'` for UI display
- Detailed debug messages for troubleshooting: `[GpsDataManager] ❌ GPS manager initialization exception: $e`

## Logging

**Framework:**
- Uses `print()` for initialization and critical operations (GPS manager setup, main app lifecycle)
- Uses custom `customDebugPrint()` helper for conditional debug output
- Logging conditionally enabled in debug mode via `if (kDebugMode)` check

**Pattern - customDebugPrint():**
```dart
void customDebugPrint(String message) {
  if (kDebugMode) {
    print(message);
  }
}
```

**Patterns:**
- Heavy use of emoji prefixes for log levels: ✅ success, ❌ error, ⚠️  warning, 📡 data/status, 🚀 start, 🔴 end
- Consistent tagging system: `[GpsDataManager]`, `[Main]`, `[Overlay]` for source identification
- Log immediately on entry and exit: `print('[Main] 🚀 Starting GPS manager initialization...')` and `print('[Main] ✅ GPS manager initialization completed')`
- Detailed state information in logs: `customDebugPrint('[Main] 📡 Received GPS data: ${gpsData.speed.toStringAsFixed(1)} m/s, ${gpsData.displayHeading}')`

## Comments

**When to Comment:**
- Block comments explain WHY, not WHAT: `// Aggressive heartbeat to keep main app process active for overlay communication`
- Inline comments for non-obvious logic: `// Use actual physical pixels for overlay sizing`
- TODO comments mark future work: `// TODO: Re-enable: if (_currentGpsData.speed < 1.0...` (line 501)
- Feature notes: `// Tap to bring main app to front functionality removed per NOTES.txt` (line 1092)

**JSDoc/TSDoc:**
- Not used. Dart conventions not followed strictly for documentation.
- Comments are inline and contextual, not formal doc comments.

## Function Design

**Size:**
- Methods vary from 3 lines to 70+ lines
- Widget build methods are large (100+ lines) as they contain layout logic
- Helper methods tend to be 10-20 lines: `_cycleUnit()`, `_cycleTheme()`, `_formatHeading()`

**Parameters:**
- Named parameters preferred over positional: `{required this.speed, required this.heading}`
- Optional parameters with defaults: `void customDebugPrint(String message)`
- Named parameters in method calls: `await FlutterOverlayWindow.showOverlay(enableDrag: true, overlayTitle: "Speedometer"...)`

**Return Values:**
- Void for side-effect operations: `void _cycleUnit()`, `void _cycleTheme()`, `void _updateData()`
- Stream returns for reactive data: `Stream<ProcessedGpsData> get dataStream => _dataController.stream`
- Widget returns for UI methods: `Widget _buildSpeedDisplay(...)`, `Widget _buildPortraitLayout(...)`
- Future returns for async operations: `Future<void> _enableWakelock()`, `Future<void> _initializeGpsManager()`
- String returns for formatting: `String getFormattedSpeed(SpeedUnit unit)`, `String formatHeading(double heading)`

## Module Design

**Exports:**
- No explicit pub exports used
- Public API via static methods: `GpsService.isLocationServiceEnabled()`, `ColorThemes.getTheme()`
- Singleton pattern for manager: `GpsDataManager.instance`

**Barrel Files:**
- Not used - each module imported directly by name
- Example: `import 'services/gps_data_manager.dart'` (not `import 'services/index.dart'`)

**Singleton Pattern:**
- Used in `GpsDataManager`: lazy initialization with null coalescing
```dart
static GpsDataManager? _instance;
static GpsDataManager get instance => _instance ??= GpsDataManager._internal();
GpsDataManager._internal();
```

**Service Classes:**
- Stateless utility class: `GpsService` contains only static methods
- Stateful manager: `GpsDataManager` contains mutable state and streams

---

*Convention analysis: 2026-02-09*
