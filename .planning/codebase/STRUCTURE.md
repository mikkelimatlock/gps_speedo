# Codebase Structure

**Analysis Date:** 2026-02-09

## Directory Layout

```
gps_speedo/
├── lib/                                # Main Dart source code
│   ├── main.dart                       # App entry points and UI widgets
│   ├── gps_service.dart                # GPS hardware abstraction
│   ├── speed_units.dart                # Speed unit enum and conversion
│   ├── color_themes.dart               # Theme data and definitions
│   └── services/
│       └── gps_data_manager.dart       # GPS data processing singleton
├── android/                            # Android native code and config
│   └── app/src/main/
│       ├── AndroidManifest.xml         # GPS and system alert window permissions
│       └── kotlin/com/novoyuuparosk/speedo/  # Android entry point
├── fonts/                              # Custom fonts
│   └── din1451alt.ttf                  # DIN 1451 Alt display font
├── icon/                               # App launcher icon
│   └── speedo.png                      # Icon image for Android/iOS
├── pubspec.yaml                        # Flutter dependencies and project config
├── pubspec.lock                        # Dependency lock file
├── analysis_options.yaml               # Dart analyzer configuration
├── test/                               # Test files
│   └── widget_test.dart                # Widget testing scaffold
└── .dart_tool/                         # Dart/Flutter build artifacts (generated)
```

## Directory Purposes

**`lib/`:**
- Purpose: All application Dart source code
- Contains: Widgets, services, models, configuration enums
- Key files: `main.dart` is the central file containing 2 widget classes (44KB)

**`lib/services/`:**
- Purpose: Business logic services isolated from UI
- Contains: `GpsDataManager` singleton service
- Key files: `gps_data_manager.dart` (264 lines of GPS processing logic)

**`android/`:**
- Purpose: Android-specific configuration and permissions
- Contains: Manifest with GPS, overlay, and location permissions; Kotlin entry point
- Key files: `AndroidManifest.xml` defines FINE_LOCATION, COARSE_LOCATION, SYSTEM_ALERT_WINDOW, READ_PHONE_STATE

**`fonts/`:**
- Purpose: Custom font assets
- Contains: DIN 1451 Alt (single font file)
- Key files: `din1451alt.ttf` referenced in pubspec.yaml

**`icon/`:**
- Purpose: Launcher icon for Android and iOS
- Contains: Single PNG image (speedo.png)
- Key files: `speedo.png` (adaptive icon source)

## Key File Locations

**Entry Points:**

- `lib/main.dart` (lines 22-24): `void main()` - Standard Flutter app entry, runs `SpeedoApp()`
- `lib/main.dart` (lines 27-34): `void overlayMain()` - Overlay process entry marked with `@pragma("vm:entry-point")`, runs `OverlaySpeedometer`
- `android/app/src/main/AndroidManifest.xml`: Android app manifest with permissions and overlay metadata

**Configuration:**

- `pubspec.yaml`: Flutter project manifest with dependency versions (geolocator 14.0.2, flutter_overlay_window 0.5.0, etc.)
- `analysis_options.yaml`: Dart linter rules
- `android/app/src/main/AndroidManifest.xml`: GPS and system permissions

**Core Logic:**

- `lib/services/gps_data_manager.dart`: GPS data singleton, stream processing, stale data timeout (4 seconds)
- `lib/gps_service.dart`: GPS permission requests, position stream factory, heading formatting
- `lib/main.dart` (lines 56-837): `SpeedometerScreen` - Main app UI, GPS subscription, overlay lifecycle
- `lib/main.dart` (lines 839-1075): `OverlaySpeedometer` - Floating window UI, data listener

**UI & Data Models:**

- `lib/main.dart` (lines 499-548): `_buildSpeedDisplay()` - Speed display renderer with split decimal parts
- `lib/main.dart` (lines 574-703): `_buildPortraitLayout()` - Portrait screen layout with speed/heading sections
- `lib/main.dart` (lines 705-836): `_buildLandscapeLayout()` - Landscape screen layout with side-by-side sections
- `lib/color_themes.dart` (lines 21-63): `ColorThemes` static list with 4 theme variants
- `lib/speed_units.dart` (lines 1-20): `SpeedUnit` enum with km/h, mph, knots conversion factors
- `lib/services/gps_data_manager.dart` (lines 6-40): `ProcessedGpsData` immutable model class

**Testing:**

- `test/widget_test.dart`: Widget test skeleton (minimal)

## Naming Conventions

**Files:**

- Snake_case: `gps_service.dart`, `gps_data_manager.dart`, `speed_units.dart`, `color_themes.dart`, `main.dart`
- Exception: `main.dart` contains all entry points and main widgets

**Directories:**

- Lowercase: `lib/`, `services/`, `android/`, `fonts/`, `icon/`, `test/`
- Java-style package paths: `android/app/src/main/kotlin/com/novoyuuparosk/speedo/`

**Classes:**

- PascalCase: `SpeedometerScreen`, `GpsDataManager`, `ProcessedGpsData`, `ColorTheme`, `ColorThemes`, `SpeedUnit`, `GpsService`, `OverlaySpeedometer`

**Functions/Methods:**

- camelCase: `initState()`, `dispose()`, `_showFloatingWindow()`, `_onGpsDataUpdate()`, `_pushDataToOverlay()`, `_cycleTheme()`, `_cycleUnit()`
- Private prefix: Methods starting with `_` (e.g., `_initializeGpsManager()`, `_buildPortraitLayout()`)

**Variables:**

- camelCase for local/member: `_currentGpsData`, `_currentUnit`, `_currentThemeIndex`, `_isOverlayActive`, `speedText`, `displaySpeed`
- Constant ALL_CAPS: `_staleDataThreshold` (const Duration), `const directions` array

**Enums:**

- PascalCase: `SpeedUnit`, with lowercase members: `SpeedUnit.kmh`, `SpeedUnit.mph`, `SpeedUnit.knots`

## Where to Add New Code

**New Feature (e.g., Speed History Tracking):**

- Primary code: Create new file in `lib/services/speed_history_manager.dart` for business logic
- Singleton pattern: Follow `GpsDataManager` structure with stream broadcasting
- UI integration: Add stream subscription in `_SpeedometerScreenState.initState()`
- Display: Add widget in `_buildPortraitLayout()` or create separate widget method
- Tests: Add to `test/widget_test.dart`

**New UI Component/Widget:**

- Implementation: Add widget class directly in `lib/main.dart` if small (<100 lines), or create separate file
- Naming: Follow PascalCase class convention, e.g., `SpeedHistoryPanel`, `MetricsDisplay`
- Props: Pass required data as constructor parameters, avoid global state
- Tests: Add widget tests in `test/widget_test.dart`

**New Configuration/Enum:**

- Speed units variant: Add new enum member to `SpeedUnit` in `lib/speed_units.dart`, add multiplier
- Color theme: Add new `ColorTheme` instance to `ColorThemes.themes` list in `lib/color_themes.dart`
- GPS behavior constants: Add to `GpsDataManager` static fields (e.g., timeout durations)

**Utilities/Helpers:**

- Shared helpers: Create `lib/utils/` directory if adding 5+ utility functions
- Single-use helpers: Keep in same file as consumer (e.g., `customDebugPrint()` in `main.dart`)
- Formatting helpers: Add to relevant domain file (`GpsService` for GPS formatting, `SpeedUnit` for speed conversion)

**New Service:**

- Location: `lib/services/new_feature_manager.dart`
- Pattern: Singleton with internal state, public stream for subscribers, async initialize method
- Lifecycle: Call `initialize()` from `SpeedometerScreen.initState()`, add stream listener
- Cleanup: Call `dispose()` in widget `dispose()` method

## Special Directories

**`lib/services/`:**
- Purpose: Business logic services (no UI widgets)
- Generated: No
- Committed: Yes
- Content: `GpsDataManager` (only service currently, designed for expansion)

**`android/`:**
- Purpose: Android native configuration and permissions
- Generated: No (manually configured, but gradle build outputs go to `build/`)
- Committed: Yes
- Key file: `AndroidManifest.xml` defines permissions needed for GPS and overlay functionality

**`build/`:**
- Purpose: Flutter/Android build artifacts
- Generated: Yes (auto-generated by `flutter build`)
- Committed: No (in .gitignore)

**`.dart_tool/`:**
- Purpose: Dart analyzer and build cache
- Generated: Yes (auto-generated by Dart tooling)
- Committed: No (in .gitignore)

**`test/`:**
- Purpose: Automated tests
- Generated: No (manually written)
- Committed: Yes
- Current state: Minimal scaffold only

---

*Structure analysis: 2026-02-09*
