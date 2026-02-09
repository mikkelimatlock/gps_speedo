# Testing Patterns

**Analysis Date:** 2026-02-09

## Test Framework

**Runner:**
- `flutter_test` (included with Flutter SDK)
- Config: None detected (uses default Flutter test configuration)

**Assertion Library:**
- Flutter's built-in matchers from `flutter_test` package
- Uses `expect()` and `find.*()` for widget testing

**Run Commands:**
```bash
flutter test                  # Run all tests
flutter test --watch         # Watch mode (not explicitly configured but supported)
flutter test --coverage      # Coverage mode (not explicitly configured)
flutter run test/widget_test.dart  # Run specific test file
```

## Test File Organization

**Location:**
- Co-located in `test/` directory parallel to `lib/`
- Single test file: `test/widget_test.dart`

**Naming:**
- Pattern: `{purpose}_test.dart`
- Example: `widget_test.dart`

**Structure:**
```
test/
└── widget_test.dart      # Basic widget tests
```

## Test Structure

**Suite Organization:**
```dart
void main() {
  testWidgets('GPS Speedometer app loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SpeedoApp());

    // Verify that the app loads with the title
    expect(find.text('0'), findsOneWidget);
  });
}
```

**Patterns:**
- Single `main()` function per test file containing one or more test cases
- `testWidgets()` for widget tests (not `test()` for unit tests)
- `async/await` for asynchronous operations
- Setup: `tester.pumpWidget()` to build the widget tree
- Teardown: None explicit - Flutter test framework cleans up automatically

## Mocking

**Framework:**
- Not currently used in codebase
- No mock packages found in `pubspec.yaml`
- No mocking libraries imported in test files

**Patterns:**
- No mocking patterns found in existing tests
- Real widget testing approach taken: actual `SpeedoApp` widget instantiated

**What NOT to Mock (Current Approach):**
- Flutter widgets and MaterialApp - built and tested directly
- Widget state and lifecycle - managed by WidgetTester

## Fixtures and Factories

**Test Data:**
- No fixtures defined
- Hard-coded expectations: `expect(find.text('0'), findsOneWidget);`

**Location:**
- N/A - not implemented in current codebase

## Coverage

**Requirements:**
- Not enforced - no coverage configuration found in pubspec.yaml
- No coverage thresholds set

**View Coverage:**
```bash
# Not explicitly documented, but standard Flutter command:
flutter test --coverage
# Generates lcov.info file with coverage data
```

## Test Types

**Widget Tests:**
- Primary test type in use
- Scope: Full app widget tree integration
- Location: `test/widget_test.dart`
- Approach: Build `SpeedoApp` and verify basic functionality loads
- Example from line 13-19:
```dart
testWidgets('GPS Speedometer app loads', (WidgetTester tester) async {
  await tester.pumpWidget(const SpeedoApp());
  expect(find.text('0'), findsOneWidget);
});
```

**Unit Tests:**
- Not currently implemented
- Candidates for unit testing:
  - `SpeedUnit.convert()` method in `lib/speed_units.dart`
  - `GpsService` static methods: `getCompassDirection()`, `formatHeading()`
  - `ColorThemes.getTheme()`, `ColorThemes.getNextThemeIndex()`
  - `ProcessedGpsData.copyWith()` copy constructor

**Integration Tests:**
- Not implemented
- Candidates would include:
  - GPS initialization flow (`GpsDataManager.initialize()`)
  - Overlay window creation and communication
  - Theme/unit synchronization between main app and overlay

**E2E Tests:**
- Not used - no Appium or similar automation framework detected

## Common Patterns

**Async Testing:**
- Uses `async/await` pattern with `WidgetTester`
- No explicit futures chaining or timeout handling in current tests
- Could expand with patterns like:
```dart
// Not currently used but could be:
await tester.pumpWidget(const SpeedoApp());
await tester.pumpAndSettle(); // Wait for all animations
expect(find.byType(SpeedometerScreen), findsOneWidget);
```

**Error Testing:**
- Not currently implemented
- No error path testing for:
  - GPS permission denial handling
  - GPS service disabled scenarios
  - GPS stream errors and recovery

**Gesture Testing:**
- Not currently tested, but WidgetTester supports:
```dart
// Example pattern (not in current tests):
await tester.tap(find.byType(GestureDetector));
await tester.pumpAndSettle();
// Verify tap resulted in theme/unit change
```

## Test Gaps

**Untested Components:**
- `_SpeedometerScreenState` - Core app state management (lifecycle, theme cycling, unit cycling)
- `_OverlaySpeedometerState` - Overlay widget state and message handling
- `GpsDataManager` - GPS data processing, stale data handling, stream broadcasting
- `GpsService` - Permission handling, location stream creation, heading formatting
- All error paths - GPS errors, permission denial, service disabled
- Gesture interactions - tap, long-press, pan gestures on both main and overlay
- Overlay messaging - data synchronization between main app and overlay window
- Theme switching - `_cycleTheme()` and related state updates
- Unit conversion - `_cycleUnit()` and display formatting

**Coverage Assessment:**
- Current test coverage: Minimal - single smoke test verifying app loads
- Estimated actual coverage: <5% of codebase
- High-risk untested areas:
  - GPS data processing and validation (critical for core functionality)
  - Overlay communication (complex async messaging)
  - State synchronization between main and overlay (prone to race conditions)

## Suggested Testing Roadmap

**Priority 1 - Core Functionality:**
1. Unit tests for `SpeedUnit.convert()` with various speed values
2. Unit tests for `GpsService.formatHeading()` with edge cases (0°, 360°, invalid values)
3. Unit tests for `ProcessedGpsData.copyWith()` partial updates
4. Integration tests for `GpsDataManager` initialization sequence

**Priority 2 - Error Handling:**
1. GPS permission denial scenarios
2. GPS service disabled scenarios
3. GPS stream errors and timeout handling
4. Stale data detection and state updates

**Priority 3 - UI/Interaction:**
1. Widget tests for theme cycling with `_cycleTheme()`
2. Widget tests for unit cycling with `_cycleUnit()`
3. Gesture tests for tap/long-press on navigation area
4. Overlay messaging and data synchronization tests

**Priority 4 - Edge Cases:**
1. App lifecycle transitions (background/foreground)
2. Overlay creation, display, and closure
3. Concurrent operations (GPS updates + theme changes)
4. Memory cleanup on dispose

---

*Testing analysis: 2026-02-09*
