# Architecture

**Analysis Date:** 2026-02-09

## Pattern Overview

**Overall:** Layered Service Pattern with Reactive Data Flow

**Key Characteristics:**
- **Singleton Service Layer** - Centralized GPS data management via `GpsDataManager`
- **Reactive Streams** - Broadcast streams for reactive UI updates across main app and overlay
- **Direct Communication** - Main app and floating window communicate via `FlutterOverlayWindow.shareData()`
- **Stateful Widget Hierarchy** - Two independent stateful widgets (`SpeedometerScreen` and `OverlaySpeedometer`) consuming shared GPS data
- **Widget-to-Widget Data Push** - Main app explicitly pushes formatted data to overlay instead of shared state management

## Layers

**GPS Hardware Layer:**
- Purpose: Acquire raw GPS data from device sensors
- Location: `lib/gps_service.dart`
- Contains: GPS permission handling, position stream creation, heading calculations
- Depends on: `geolocator`, `permission_handler` packages
- Used by: `GpsDataManager`

**GPS Data Management Layer:**
- Purpose: Process raw GPS data, validate signals, manage stale data timeouts, broadcast processed data
- Location: `lib/services/gps_data_manager.dart`
- Contains: `GpsDataManager` singleton, `ProcessedGpsData` model, stream subscription and timing logic
- Depends on: `GpsService`, `SpeedUnit`
- Used by: `SpeedometerScreen` and `OverlaySpeedometer`

**UI State & Rendering Layer:**
- Purpose: Consume GPS data, manage theme/unit selection, render main app and overlay screens
- Location: `lib/main.dart`
- Contains: `SpeedometerScreen` (main app widget), `OverlaySpeedometer` (overlay widget), layout builders, gesture handlers
- Depends on: `GpsDataManager`, `ColorThemes`, `SpeedUnit`, `WakelockPlus`, `FlutterOverlayWindow`, `BgLauncher`
- Used by: Flutter framework

**Configuration/Utilities Layer:**
- Purpose: Provide constants and helper functions for speed units, color themes
- Location: `lib/speed_units.dart`, `lib/color_themes.dart`
- Contains: `SpeedUnit` enum, `ColorTheme` classes, theme collection
- Depends on: Flutter Material Design
- Used by: All UI and data layers

## Data Flow

**GPS Data Collection & Broadcasting:**

1. `main.dart` calls `GpsDataManager.instance.initialize()` on app startup
2. `GpsDataManager` requests permissions via `GpsService.requestPermissions()`
3. `GpsDataManager` calls `Geolocator.getCurrentPosition()` with 20s timeout for initial fix
4. Once initial position obtained, `GpsDataManager` subscribes to `GpsService.positionStream()` with 2s update timeout
5. Raw `Position` updates trigger `GpsDataManager._onPositionUpdate()`
6. `GpsDataManager` validates speed/heading, formats display strings, creates `ProcessedGpsData`
7. `GpsDataManager` broadcasts via `_dataController.add(newData)` (broadcast stream)
8. Both `SpeedometerScreen` and `OverlaySpeedometer` receive updates via stream subscriptions

**Main App Display Update:**

1. `SpeedometerScreen._onGpsDataUpdate()` receives `ProcessedGpsData` from stream
2. Updates local state: `_currentGpsData`, `_currentUnit`, `_currentThemeIndex`
3. Rebuilds UI with converted speed value and formatted heading
4. If overlay is active, calls `_pushDataToOverlay()` to sync overlay display

**Overlay Activation & Communication:**

1. User taps compass area of main app
2. `_showFloatingWindow()` executes: prepares display data, calls `FlutterOverlayWindow.shareData()`, launches overlay
3. `FlutterOverlayWindow.showOverlay()` creates new process running `OverlaySpeedometer`
4. Overlay's `_listenToMainAppMessages()` sets up listener for `overlayListener`
5. Main app pushes updates via periodic `_pushDataToOverlay()` calls when overlay active
6. Overlay applies updates to state and rebuilds display

**Background Persistence:**

1. App detects background transition via `didChangeAppLifecycleState()`
2. Enables wake lock via `WakelockPlus.enable()`
3. If overlay active, starts heartbeat timer every 5 seconds
4. Heartbeat calls `_pushDataToOverlay()` to maintain communication with overlay process
5. On resume, disables heartbeat

**State Management:**

- **No centralized Provider** - App uses direct state via `setState()` in main screen
- **No local persistence** - GPS data is ephemeral (speed, heading, validity flags)
- **Settings stored in SharedPreferences** - Would be implemented here if settings persistence added
- **Overlay state isolated** - Overlay maintains its own independent state, receives push updates from main app

## Key Abstractions

**ProcessedGpsData (Model):**
- Purpose: Represents validated, formatted GPS information
- Examples: `lib/services/gps_data_manager.dart` (lines 6-40)
- Pattern: Immutable data class with `copyWith()` constructor for updates
- Contains: `speed` (m/s), `heading` (degrees), display strings, validity flags

**GpsDataManager (Singleton Service):**
- Purpose: Centralized GPS lifecycle and data processing
- Examples: `lib/services/gps_data_manager.dart` (lines 42-263)
- Pattern: Singleton (`_instance ??= GpsDataManager._internal()`) with public stream and synchronous getter
- Manages: Permission handling, GPS subscription, stale data timeouts, format conversion

**SpeedUnit (Configuration Enum):**
- Purpose: Speed unit definitions with conversion logic
- Examples: `lib/speed_units.dart` (lines 1-20)
- Pattern: Enum with associated data (label, multiplier) and methods (`convert()`, `next`)
- Values: `kmh` (1.0x), `mph` (0.621371x), `knots` (0.539957x) all convert from m/s via 3.6 multiplier

**ColorTheme (Configuration):**
- Purpose: Immutable theme definition for UI colors
- Examples: `lib/color_themes.dart` (lines 3-19)
- Pattern: Immutable data class with predefined theme collection
- Used by: Both main app and overlay for consistent visual styling

**OverlayListener Pattern:**
- Purpose: Async message passing from main app to overlay process
- Method: `FlutterOverlayWindow.overlayListener.listen()` (broadcast stream from plugin)
- Data format: Maps with action key and payload (speed, heading, theme index, etc.)

## Entry Points

**Main App Entry:**
- Location: `lib/main.dart` (lines 22-24)
- Triggers: `flutter run` or app launch
- Responsibilities: Create `SpeedometerApp`, initialize MaterialApp theme, set home to `SpeedometerScreen`

**Overlay Entry:**
- Location: `lib/main.dart` (lines 27-34: `overlayMain()`)
- Triggers: `FlutterOverlayWindow.showOverlay()` with overlay file parameter
- Responsibilities: Create isolated MaterialApp, set home to `OverlaySpeedometer`, no theme inheritance from main app
- Annotation: `@pragma("vm:entry-point")` required for Flutter to recognize as valid entry point

**Speedometer Screen (Main):**
- Location: `lib/main.dart` (lines 56-837: `SpeedometerScreen`, `_SpeedometerScreenState`)
- Triggers: Set as home widget in MaterialApp
- Responsibilities: Initialize GPS manager, subscribe to data stream, render portrait/landscape layouts, handle overlay lifecycle, manage background persistence

**Overlay Speedometer (Floating Window):**
- Location: `lib/main.dart` (lines 839-1075: `OverlaySpeedometer`, `_OverlaySpeedometerState`)
- Triggers: Launched via `FlutterOverlayWindow.showOverlay()`
- Responsibilities: Listen for main app updates, render speed/heading display, handle close and long-press gestures, send close signal to main app

## Error Handling

**Strategy:** Graceful degradation with user-visible status

**Patterns:**

- **GPS Service Disabled:** Set display text to "GPS OFF", mark validity flags false, continue app without crash
- **Permissions Denied:** Set display to "NO PERM", mark validity flags false, allow user to retry via OS settings prompt
- **GPS Timeout:** `ProcessedGpsData` copied with `isSpeedValid=false`, display text set to "--", heading may remain valid if recently received
- **Stale Data:** Timer-based: after 4 seconds without update, set speed to "--" but keep heading if valid
- **Overlay Errors:** Wrapped in try-catch in `_showFloatingWindow()` and `_closeFloatingWindow()`, silent failures prevent main app crash
- **Stream Errors:** Caught in listener error handler, sets `_errorMessage` for display, allows user to see issue

## Cross-Cutting Concerns

**Logging:**
- Direct `print()` statements with emoji prefix codes for identification
- Debug-only printing via `customDebugPrint()` which checks `kDebugMode`
- Format: `[Component] emoji Descriptive message`
- Examples: `[GpsDataManager] 📡 Raw GPS update:`, `[Main] ❌ GPS stream error callback:`

**Validation:**
- Speed validation: `position.speed.isFinite && position.speed >= 0`
- Heading validation: `position.heading.isFinite && position.heading >= 0 && position.heading < 360`
- Invalid data triggers fallback: speed becomes 0.0, heading keeps last valid value
- Display text fallback: "--" used for invalid/stale speed data

**Permissions:**
- Requested via `Permission.locationWhenInUse.request()` from `permission_handler`
- Overlay overlay permissions checked via `FlutterOverlayWindow.isPermissionGranted()`
- No permission flow UI; user must grant in Android system settings

**Background Lifecycle:**
- Wake lock enabled on init via `WakelockPlus.enable()`
- Lifecycle observer via `WidgetsBinding.instance.addObserver(this)`
- Background heartbeat timer prevents process hibernation when overlay active
- Multiple timer cleanup in dispose to prevent memory leaks

**Overlay Synchronization:**
- Size calculated in main app: `(physicalSize.width * 0.45).round()` for width, `width * 0.6` for height
- Size sent to overlay via `shareData()` on creation
- Theme index and unit index sent on every update
- Speed value re-converted for overlay to use (overlay doesn't have access to `_currentUnit`)

---

*Architecture analysis: 2026-02-09*
