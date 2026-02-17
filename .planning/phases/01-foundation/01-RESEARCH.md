# Phase 1: Foundation - Research

**Researched:** 2026-02-09
**Domain:** Flutter code organization and refactoring patterns
**Confidence:** HIGH

## Summary

This research investigates best practices for reorganizing a monolithic Flutter application into a modular, layer-first directory structure. The focus is on extracting immutable data models, centralizing behavioral constants, implementing proper debug logging, and ensuring safe incremental migration without breaking the application.

The standard approach in Flutter emphasizes separation of concerns with a layer-first structure (screens/, widgets/, services/, providers/, models/, config/) for small to medium applications. Flutter officially recommends the MVVM pattern with clear boundaries between UI and data layers. File organization follows strict Dart conventions: snake_case for files, UpperCamelCase for classes, and lowerCamelCase for constants (though SCREAMING_CAPS remains acceptable for legacy consistency).

Key recommendations focus on immutable models with copyWith() methods, domain-grouped constants using static classes, debug-only logging with kDebugMode, and incremental migration where every step maintains a runnable application.

**Primary recommendation:** Use layer-first structure with immutable models, domain-grouped constants in abstract classes, and kDebugMode-guarded logging. Migrate incrementally with immediate import updates to avoid broken states.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter SDK | 3.38.6 | Cross-platform UI framework | Official framework (as of 2026-01-14) |
| Dart | 3.10.3 | Programming language | Flutter's language (updated 2026-02-05) |
| flutter/foundation.dart | Built-in | Debug mode detection | Provides kDebugMode for conditional logging |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| freezed | Latest | Code generation for immutable classes | Complex models requiring serialization/equality |
| copy_with_extension | Latest | Generates copyWith methods | When avoiding manual copyWith boilerplate |
| dart_mappable | Latest | JSON serialization with fromMap/toMap | Models persisted to SharedPreferences |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual copyWith | Freezed package | Manual: More control, less boilerplate. Freezed: Auto-generates but adds build step |
| Layer-first | Feature-first | Layer-first better for small/medium apps, feature-first for large multi-feature apps |
| lowerCamelCase constants | SCREAMING_CAPS | lowerCamelCase is modern Dart standard, SCREAMING_CAPS acceptable for legacy consistency |

**Installation:**
No additional dependencies required for basic refactoring. Optional code generation packages:
```bash
flutter pub add freezed_annotation
flutter pub add --dev freezed build_runner
```

## Architecture Patterns

### Recommended Project Structure
```
lib/
├── screens/           # Top-level screen widgets (1:1 with viewmodels)
├── widgets/           # Reusable UI components (flat structure, no subdirectories)
├── providers/         # State management (Provider pattern)
├── services/          # Business logic and external API wrappers
├── models/            # Immutable data classes with copyWith()
├── config/            # Constants grouped by domain
│   ├── gps_constants.dart
│   ├── ui_constants.dart
│   ├── timing_constants.dart
│   └── overlay_constants.dart
└── main.dart          # App entry point
```

**Key principles:**
- Layer-first organization: Group by technical layer, not feature
- Flat widget directory: All widgets directly in widgets/, no subdirectories
- Overlay code distributed: Overlay widgets in widgets/, overlay services in services/
- File naming: snake_case matching class names (GpsDataManager → gps_data_manager.dart)

### Pattern 1: Immutable Models with copyWith()
**What:** Data classes with final fields and a copyWith() method for creating modified copies
**When to use:** All data models, especially those shared between components or persisted
**Example:**
```dart
// Source: Current codebase (lib/services/gps_data_manager.dart)
class ProcessedGpsData {
  final double speed;
  final double heading;
  final String displaySpeed;
  final String displayHeading;
  final bool isSpeedValid;
  final bool isHeadingValid;

  const ProcessedGpsData({
    required this.speed,
    required this.heading,
    required this.displaySpeed,
    required this.displayHeading,
    required this.isSpeedValid,
    required this.isHeadingValid,
  });

  ProcessedGpsData copyWith({
    double? speed,
    double? heading,
    String? displaySpeed,
    String? displayHeading,
    bool? isSpeedValid,
    bool? isHeadingValid,
  }) {
    return ProcessedGpsData(
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      displaySpeed: displaySpeed ?? this.displaySpeed,
      displayHeading: displayHeading ?? this.displayHeading,
      isSpeedValid: isSpeedValid ?? this.isSpeedValid,
      isHeadingValid: isHeadingValid ?? this.isHeadingValid,
    );
  }
}
```

**Limitation:** Standard copyWith cannot distinguish between "not provided" and "set to null". For nullable fields requiring explicit null setting, use code generation (Freezed) or sentinel pattern.

### Pattern 2: Domain-Grouped Constants with Static Classes
**What:** Constants organized into abstract classes with static members, grouped by functional domain
**When to use:** Behavioral constants (timeouts, thresholds, GPS settings), not UI spacing/padding
**Example:**
```dart
// Source: Flutter community best practices 2026
// config/gps_constants.dart
abstract class GpsConfig {
  static const Duration initialFixTimeout = Duration(seconds: 20);
  static const Duration updateTimeout = Duration(seconds: 2);
  static const Duration staleDataThreshold = Duration(seconds: 4);
  static const double validHeadingMin = 0.0;
  static const double validHeadingMax = 360.0;
  static const double lowSpeedThreshold = 1.0;
}

// config/timing_constants.dart
abstract class TimingConfig {
  static const Duration heartbeatInterval = Duration(seconds: 5);
  static const Duration overlayStatusCheckInterval = Duration(milliseconds: 1000);
  static const Duration tapCloseDelay = Duration(milliseconds: 500);
}

// config/overlay_constants.dart
abstract class OverlayConfig {
  static const double widthPercentage = 0.45;
  static const double aspectRatio = 0.6; // height = width * aspectRatio
  static const double backgroundOpacity = 0.85;
  static const double borderOpacity = 0.3;
}
```

**Naming convention:** lowerCamelCase (modern Dart standard) or SCREAMING_CAPS (legacy consistency)
**File organization:** One file per domain, descriptive names (gps_constants.dart, not constants.dart)

### Pattern 3: Theme Model with Internal Palette Storage
**What:** A model that holds all available color palettes internally, exposing only the current palette's colors and a method to cycle themes
**When to use:** Managing multiple theme options with rotation capability
**Example:**
```dart
// Source: Design decision from CONTEXT.md
// models/theme_model.dart
class ThemeModel {
  final int _currentIndex;
  final List<ColorTheme> _allPalettes;

  const ThemeModel({
    required int currentIndex,
    required List<ColorTheme> allPalettes,
  }) : _currentIndex = currentIndex, _allPalettes = allPalettes;

  // Expose current palette's colors with named accessors
  ColorTheme get current => _allPalettes[_currentIndex % _allPalettes.length];
  String get currentSetName => current.name;

  // Method for rotating themes
  ThemeModel rotate() {
    return ThemeModel(
      currentIndex: (_currentIndex + 1) % _allPalettes.length,
      allPalettes: _allPalettes,
    );
  }

  ThemeModel copyWith({int? currentIndex, List<ColorTheme>? allPalettes}) {
    return ThemeModel(
      currentIndex: currentIndex ?? _currentIndex,
      allPalettes: allPalettes ?? _allPalettes,
    );
  }
}
```

**Separation of concerns:** Persistence (SharedPreferences) handled separately, not in the model itself.

### Pattern 4: Debug-Only Logging with kDebugMode
**What:** Conditional logging that only executes in debug builds using kDebugMode
**When to use:** Replacing all print() statements; all debug logging
**Example:**
```dart
// Source: Flutter official docs - docs.flutter.dev/testing/code-debugging
import 'package:flutter/foundation.dart';

class Logger {
  static const String _reset = '\x1B[0m';
  static const String _red = '\x1B[31m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _gray = '\x1B[90m';

  static void error(String message, [String? caller]) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final callerTag = caller != null ? '[$caller] ' : '';
      debugPrint('$_red[ERROR]$_reset $timestamp $callerTag$message');
    }
  }

  static void warn(String message, [String? caller]) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final callerTag = caller != null ? '[$caller] ' : '';
      debugPrint('$_yellow[WARN]$_reset $timestamp $callerTag$message');
    }
  }

  static void info(String message, [String? caller]) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final callerTag = caller != null ? '[$caller] ' : '';
      debugPrint('$_blue[INFO]$_reset $timestamp $callerTag$message');
    }
  }

  static void debug(String message, [String? caller]) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final callerTag = caller != null ? '[$caller] ' : '';
      debugPrint('$_gray[DEBUG]$_reset $timestamp $callerTag$message');
    }
  }
}
```

**Key benefits:**
- Tree shaking removes logging code entirely in release builds
- debugPrint() avoids log truncation (unlike print())
- Consistent format with timestamps and caller identification

### Pattern 5: Safe Incremental Migration
**What:** Refactoring strategy where app compiles and runs after every change
**When to use:** All code reorganization, especially when moving files between directories
**Example workflow:**
```
Wave 1: Create directory structure
  - mkdir lib/screens lib/widgets lib/providers lib/services lib/models lib/config
  - Verify: flutter analyze (no errors)

Wave 2: Extract first model (ProcessedGpsData)
  - Create lib/models/processed_gps_data.dart
  - Move ProcessedGpsData class
  - Update all imports in consuming files
  - Verify: flutter run --debug (app launches successfully)

Wave 3: Extract second model (OverlayMessage)
  - Create lib/models/overlay_message.dart
  - Move OverlayMessage class
  - Update all imports
  - Verify: flutter run --debug

Wave 4: Extract constants
  - Create lib/config/gps_constants.dart
  - Extract GPS-related constants
  - Update references
  - Verify: flutter run --debug
```

**Critical rules:**
- No temporary re-exports (update imports immediately)
- No broken intermediate states (every wave is a working checkpoint)
- Test on physical device after each wave (bench phone verification)

### Anti-Patterns to Avoid

- **Giant constants file:** Don't create a single constants.dart with all constants. Split by domain (gps_constants.dart, timing_constants.dart, etc.) for maintainability.

- **Premature abstraction:** Don't extract UI padding/sizing constants. These should remain inline as they're context-specific and extracting them reduces readability.

- **Broken intermediate states:** Don't move files without immediately updating imports. Every commit should leave the app in a runnable state.

- **debugPrint() without kDebugMode:** debugPrint() runs in all modes. Always wrap with `if (kDebugMode)` or use a logger utility that does this internally.

- **SCREAMING_CAPS by default:** Modern Dart prefers lowerCamelCase for constants. Only use SCREAMING_CAPS for consistency with existing code that already uses it.

- **Feature-first for small apps:** Don't use feature-first structure for small/medium apps. Layer-first is simpler and avoids excessive "jumping" between distant files.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| copyWith with nullable fields | Custom sentinel pattern | freezed package | Language limitation: can't distinguish null vs omitted. Freezed handles this correctly. |
| Model serialization | Custom toMap/fromMap | dart_mappable or freezed | Handles nested objects, type safety, null safety edge cases. |
| File moving automation | Manual file moves + find/replace imports | IDE refactoring (VSCode: F2 rename, Move to file) | IDE tracks references and updates imports automatically. |
| Debug vs release logic | Custom build flags or globals | kDebugMode from flutter/foundation.dart | Official constant, enables tree shaking, zero runtime cost. |
| Enum-like constant groups | Individual constants | Dart enums or abstract classes with static consts | Type safety, IDE autocomplete, grouped organization. |

**Key insight:** Flutter's ecosystem has mature code generation tools (freezed, build_runner, dart_mappable) that handle edge cases better than hand-rolled solutions. For a foundation phase, start simple (manual copyWith, basic models) but plan for code generation if complexity grows.

## Common Pitfalls

### Pitfall 1: Import Path Breakage During File Moves
**What goes wrong:** Moving files to new directories without updating imports causes compilation errors across the codebase.
**Why it happens:** Dart uses relative imports (e.g., `import 'speed_units.dart'`) that break when file locations change. Forgetting to update all import statements leaves the app uncompilable.
**How to avoid:**
- Use IDE refactoring tools (VSCode F2 rename, "Move to file" command) which automatically update imports
- If moving manually: Use global search for the old import path before moving the file
- Update all imports immediately in the same commit as the file move
- Run `flutter analyze` after every file move to catch broken imports
**Warning signs:**
- Compilation errors like "Target of URI doesn't exist"
- Analyzer errors showing unresolved imports
- Multiple files showing "undefined name" errors for moved classes

### Pitfall 2: Constant Naming Convention Confusion
**What goes wrong:** Mixing SCREAMING_CAPS and lowerCamelCase constants inconsistently across the codebase.
**Why it happens:** Older Dart code used SCREAMING_CAPS (like Java), but modern Dart style guide recommends lowerCamelCase. Developers unfamiliar with the style change default to SCREAMING_CAPS.
**How to avoid:**
- Check official Dart style guide (updated 2026-02-05): "use lowerCamelCase for constant variables"
- For this project: CONTEXT.md specifies SCREAMING_CAPS for consistency with hypothetical existing patterns
- Document the chosen convention in a comment at the top of each constants file
- Use a linter rule to enforce consistency: `constant_identifier_names: false` (allows both styles)
**Warning signs:**
- Mix of `GPS_TIMEOUT` and `gpsTimeout` in same file
- Refactoring changing constant names from const to final breaking style consistency

### Pitfall 3: Extracting UI Constants Prematurely
**What goes wrong:** Moving layout-specific values (padding, font sizes, percentages) to constants files reduces readability without adding value.
**Why it happens:** Over-zealous adherence to "no magic numbers" principle without considering context.
**How to avoid:**
- Only extract behavioral constants (timeouts, thresholds, business logic values)
- Leave UI values inline when they're context-specific (e.g., `fontSize * 0.5` for subfont)
- Extract UI constants only when the same value is used in 3+ places OR represents a design system token
- CONTEXT.md explicitly states: "Extract behavioral constants only — leave UI padding/sizing as inline values"
**Warning signs:**
- Constants file with entries like `buttonPadding8`, `fontSize12`, `opacity50`
- Constants used in only one location
- Developers needing to jump between files to understand layout math

### Pitfall 4: copyWith() Null Ambiguity
**What goes wrong:** Using `model.copyWith(field: null)` doesn't set the field to null; it keeps the existing value due to `??` operator.
**Why it happens:** Dart can't distinguish between omitted parameters and parameters explicitly set to null. The pattern `field ?? this.field` treats both identically.
**How to avoid:**
- For simple models with non-nullable fields: Standard copyWith is sufficient
- For models with nullable fields needing explicit null setting: Use freezed package or sentinel pattern
- Document the limitation in code comments if using manual copyWith
- For this project: ProcessedGpsData has non-nullable fields, so standard copyWith is safe
**Warning signs:**
- Attempting to clear a nullable field: `data.copyWith(optionalField: null)` doesn't work
- Unit tests failing when trying to nullify fields
- Bug reports about "can't reset field to empty state"

### Pitfall 5: Forgetting kDebugMode for debugPrint()
**What goes wrong:** Assuming debugPrint() is automatically debug-only; it actually runs in all build modes.
**Why it happens:** The name "debugPrint" is misleading — it only prevents log truncation, not production execution.
**How to avoid:**
- Always wrap debugPrint() calls with `if (kDebugMode)` guard
- Create a Logger utility class that internally uses kDebugMode
- Replace all bare print() and debugPrint() calls during refactoring
- Configure linter to warn on bare print() usage: `avoid_print: true`
**Warning signs:**
- Performance impact in release builds from excessive logging
- Logs appearing in production app (if connected to debugger)
- Increased APK size from unremoved log strings (minor but measurable)

### Pitfall 6: Broken Intermediate States in Migration
**What goes wrong:** Moving multiple files simultaneously, planning to "fix imports later", leaving app uncompilable for hours or days.
**Why it happens:** Attempting to do too much in one commit; underestimating import dependency complexity.
**How to avoid:**
- Adopt wave-based migration: One file or one domain at a time
- After each file move, immediately update all imports
- Run `flutter run --debug` after each wave to verify app launches
- CONTEXT.md requirement: "App must be runnable on a bench phone after each session/wave"
- Commit after each successful wave, not at the end of a large batch
**Warning signs:**
- Git diff showing 20+ files changed
- Compilation errors blocking any testing
- Comments like "TODO: fix imports" in commit messages
- Unable to demonstrate progress on physical device

### Pitfall 7: Circular Dependency Creation
**What goes wrong:** After reorganization, models depend on services which depend on models, causing compilation errors.
**Why it happens:** Improper separation of concerns; business logic leaking into models; models importing service implementations.
**How to avoid:**
- Maintain dependency direction: Services → Models → Config (never circular)
- Models should be pure data classes with no service imports
- If a model needs formatting logic, use helper methods in services or extensions
- Use dependency injection for services needing other services
**Warning signs:**
- Compilation error: "Circular dependency detected"
- Model files importing from services/ directory
- Config files importing from models/ (should be pure constants)

## Code Examples

Verified patterns from official sources and current codebase:

### File Naming Convention
```dart
// Source: dart.dev/effective-dart/style (updated 2026-02-05)
// Class name: GpsDataManager
// File name: gps_data_manager.dart (lowercase_with_underscores)

// Class name: ProcessedGpsData
// File name: processed_gps_data.dart

// Class name: OverlayMessage
// File name: overlay_message.dart
```

### Model with Serialization for SharedPreferences
```dart
// Source: Flutter community pattern for SharedPreferences persistence
// models/overlay_message.dart
import 'dart:convert';

class OverlayMessage {
  final double speed;
  final double heading;
  final String displaySpeed;
  final String displayHeading;
  final String themeName;
  final String unit;

  const OverlayMessage({
    required this.speed,
    required this.heading,
    required this.displaySpeed,
    required this.displayHeading,
    required this.themeName,
    required this.unit,
  });

  // For SharedPreferences persistence
  Map<String, dynamic> toMap() {
    return {
      'speed': speed,
      'heading': heading,
      'displaySpeed': displaySpeed,
      'displayHeading': displayHeading,
      'themeName': themeName,
      'unit': unit,
    };
  }

  factory OverlayMessage.fromMap(Map<String, dynamic> map) {
    return OverlayMessage(
      speed: map['speed'] as double,
      heading: map['heading'] as double,
      displaySpeed: map['displaySpeed'] as String,
      displayHeading: map['displayHeading'] as String,
      themeName: map['themeName'] as String,
      unit: map['unit'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory OverlayMessage.fromJson(String source) =>
      OverlayMessage.fromMap(json.decode(source) as Map<String, dynamic>);

  OverlayMessage copyWith({
    double? speed,
    double? heading,
    String? displaySpeed,
    String? displayHeading,
    String? themeName,
    String? unit,
  }) {
    return OverlayMessage(
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      displaySpeed: displaySpeed ?? this.displaySpeed,
      displayHeading: displayHeading ?? this.displayHeading,
      themeName: themeName ?? this.themeName,
      unit: unit ?? this.unit,
    );
  }
}
```

### Enum-based Model (SpeedUnit pattern)
```dart
// Source: Current codebase lib/speed_units.dart
// models/speed_unit.dart
enum SpeedUnit {
  kmh('km/h', 1.0),
  mph('mph', 0.621371),
  knots('kts', 0.539957);

  const SpeedUnit(this.label, this.multiplier);

  final String label;
  final double multiplier;

  double convert(double speedMps) {
    return speedMps * 3.6 * multiplier;
  }

  SpeedUnit get next {
    final values = SpeedUnit.values;
    final currentIndex = values.indexOf(this);
    return values[(currentIndex + 1) % values.length];
  }
}
```

**Note:** This enum pattern is idiomatic Dart and should remain as-is, not converted to a class. Move to models/ directory without structural changes.

### Directory Structure Creation
```bash
# Source: Planning decision
# Creates all necessary directories in one go
cd lib
mkdir -p screens widgets providers services models config
```

### Import Update Pattern
```dart
// Source: Migration best practice
// Before (in main.dart):
import 'speed_units.dart';
import 'color_themes.dart';
import 'services/gps_data_manager.dart';

// After reorganization:
import 'models/speed_unit.dart';
import 'models/theme_model.dart';
import 'services/gps_data_manager.dart';
import 'screens/speedometer_screen.dart';
import 'screens/overlay_screen.dart';
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SCREAMING_CAPS for constants | lowerCamelCase for constants | Dart style guide update (pre-2025) | SCREAMING_CAPS still acceptable for legacy; new code prefers lowerCamelCase |
| print() for debugging | kDebugMode + debugPrint() | Flutter 2.x+ | Tree shaking removes debug code; no runtime cost in release |
| Manual copyWith for nullable fields | freezed or sentinel pattern | Community evolution 2024-2025 | Standard copyWith can't set fields to null explicitly |
| Feature-first always recommended | Layer-first for small/medium apps | Flutter community 2025 | Official guidance: choose based on project size/complexity |
| Manual JSON serialization | Code generation (freezed, json_serializable) | Flutter 3.x era | Code generation reduces bugs, handles edge cases |

**Deprecated/outdated:**
- Using plain `print()` without kDebugMode guard: Bloats release builds with debug strings
- Single monolithic constants.dart: Hard to maintain; modern practice uses domain-split files
- Feature-first for all projects: Overkill for apps without many distinct features

## Open Questions

Things that couldn't be fully resolved:

1. **Theme model persistence strategy**
   - What we know: CONTEXT.md specifies "Persistence (SharedPreferences) handled separately from the theme model itself"
   - What's unclear: Should persistence logic live in a service, provider, or repository pattern?
   - Recommendation: Create a ThemeService in services/ that handles loading/saving theme index to SharedPreferences, keeping the ThemeModel pure

2. **Exact fields for OverlayMessage model**
   - What we know: Need to replace unvalidated Map data for overlay communication
   - What's unclear: Current overlay messaging uses dynamic Maps; exact fields require examining overlay communication code
   - Recommendation: Analyze overlay message content during execution wave to determine required fields (likely: speed, heading, theme, unit)

3. **Whether to include toMap/fromMap in all models**
   - What we know: ProcessedGpsData is in-memory only; OverlayMessage likely needs serialization for inter-process communication; ThemeModel index needs persistence
   - What's unclear: Best practice for mixed persistence needs within models/ directory
   - Recommendation: Add toMap/fromMap only to models that need it (OverlayMessage). For ProcessedGpsData, skip serialization (in-memory only). Document this decision in model file comments.

4. **Logger implementation details**
   - What we know: Need 4 levels (error, warn, info, debug) with caller name and timestamp
   - What's unclear: Should logger support automatic caller detection via StackTrace, or require manual caller strings? Should it use ANSI colors for console output?
   - Recommendation: Start simple with manual caller strings (`Logger.info('message', 'GpsManager')`). ANSI colors improve readability in terminal — include them. Can enhance with automatic caller detection later if needed.

## Sources

### Primary (HIGH confidence)
- [Flutter App Architecture Guide](https://docs.flutter.dev/app-architecture/guide) - Official MVVM architecture recommendations (updated 2026-01-14)
- [Dart Effective Style Guide](https://dart.dev/effective-dart/style) - Official naming conventions (updated 2026-02-05)
- [Flutter Debug Documentation](https://docs.flutter.dev/testing/code-debugging) - kDebugMode and debugPrint() usage
- Current codebase analysis - Existing patterns in lib/services/gps_data_manager.dart, lib/speed_units.dart, lib/color_themes.dart

### Secondary (MEDIUM confidence)
- [Flutter Project Structure: Feature-first or Layer-first?](https://codewithandrea.com/articles/flutter-project-structure/) - Community best practices
- [Managing Flutter Logs](https://medium.com/@punithsuppar7795/managing-flutter-logs-reducing-noise-in-debug-console-0229ff7a9235) - kDebugMode patterns
- [Flutter Constants Best Practices](https://dev.to/gulsenkeskin/flutter-constants-best-practices-55og) - Constants organization patterns
- [Understanding copyWith in Flutter](https://medium.com/@alaxhenry0121/understanding-copywith-in-flutter-models-a-complete-guide-for-efficient-state-management-4a41f71eea42) - Immutability patterns
- [How to Explicitly Set Null in CopyWith](https://happy-makadiya.medium.com/how-to-explicitly-set-null-in-copywith-parameters-in-dart-a01f9591c3ea) - copyWith() limitations

### Tertiary (LOW confidence)
- Multiple Medium articles on Flutter architecture (2025-2026) - Community opinions, not official guidance
- Stack Overflow discussions on import management - Practical solutions but not authoritative

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official Flutter/Dart documentation from 2026, current codebase patterns verified
- Architecture: HIGH - Official Flutter architecture guide, clear MVVM recommendations, verified layer-first for small apps
- Pitfalls: MEDIUM to HIGH - Mix of official docs (import errors, kDebugMode), community consensus (constants organization), and logical inference (circular dependencies)

**Research date:** 2026-02-09
**Valid until:** 2026-03-11 (30 days) - Flutter is in mature phase with stable patterns; architecture recommendations unlikely to change significantly

**Notes:**
- User decisions in CONTEXT.md constrain research: SCREAMING_CAPS constants (vs Dart standard lowerCamelCase), layer-first structure (confirmed as appropriate), specific theme model design
- No new dependencies specified in prior decisions; research focused on Flutter built-ins and optional code generation
- Current codebase already demonstrates good patterns: immutable ProcessedGpsData with copyWith, enum-based SpeedUnit, singleton GpsDataManager
