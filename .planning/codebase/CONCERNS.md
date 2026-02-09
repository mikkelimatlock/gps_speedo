# Codebase Concerns

**Analysis Date:** 2026-02-09

## Tech Debt

**Excessive Debug Logging in Production Code:**
- Issue: 27 `print()` calls in `lib/services/gps_data_manager.dart` and 10 `print()` calls in `lib/main.dart` for verbose initialization/lifecycle tracking. These print directly to console in release builds without conditional checking like the rest of the code.
- Files: `lib/services/gps_data_manager.dart` (lines 74-261), `lib/main.dart` (lines 337-373)
- Impact: Performance overhead, console spam in production APK, potential security information leakage in logs. Makes logs harder to parse since most code uses `customDebugPrint()` guard.
- Fix approach: Replace all unconditional `print()` calls with `customDebugPrint()` to respect debug-only context. This is inconsistent with the established logging pattern in the codebase.

**Disabled Low-Speed Heading Display Logic:**
- Issue: Low-speed validation for heading display is temporarily disabled (commented out TODO) to allow testing indoors. Speeds below 1 m/s with invalid heading should show '--' but currently show raw values.
- Files: `lib/main.dart` (line 501), `lib/services/gps_data_manager.dart` (line 172)
- Impact: GPS data invalid at rest is displayed to user, confusing accuracy metrics. May cause false user reports of heading tracking.
- Fix approach: Re-enable the validation logic: `(speed < 1.0 && (heading < 0.0 || heading >= 360.0)) ? '--' : displaySpeed` after completing indoor testing phase. Document test completion criteria.

**Silent Error Suppression in Overlay Creation:**
- Issue: Floating window `_showFloatingWindow()` has a catch block that silently suppresses all exceptions with no logging.
- Files: `lib/main.dart` (line 479-481)
- Impact: Overlay initialization failures go undetected. User sees no overlay and no error message. Makes debugging overlay issues impossible.
- Fix approach: Add `customDebugPrint()` call in catch block to log overlay errors, even at debug level. Users should see informative error messages if overlay fails.

**Inconsistent Error Handling in Overlay Message Processing:**
- Issue: Overlay listener's error handler (line 142-144) logs errors but doesn't inform UI or take corrective action. GPS data stream error handler (line 348-351 in main.dart) sets error message in UI state.
- Files: `lib/main.dart` (lines 115-145, 348-351)
- Impact: Overlay communication errors won't be visible to user, but GPS stream errors will. Inconsistent user experience for different error types.
- Fix approach: Unify error handling: either surface all errors to UI via setState or suppress all non-critical errors consistently. Document which errors are recoverable vs. fatal.

## Known Bugs

**Overlay Long-Press Close Unreliable on Subsequent Overlays:**
- Symptoms: Long-press to close overlay works on first overlay creation, but gesture detection fails on second and subsequent overlay launches. Overlay stays open after long press.
- Files: `lib/main.dart` (lines 1054-1090 overlay gesture handling, lines 649-659 navigation tap detection)
- Trigger: Launch overlay, close with long press (works). Launch overlay again, long press fails to close.
- Workaround: Tap navigation area to close overlay instead (toggles overlay state based on `_isOverlayActive` flag).
- Root cause documented in TODO.md: "Gesture detection works on first overlay but fails on subsequent overlays" - indicates system-level platform limitation.

**Bidirectional Overlay Communication Unreliable:**
- Symptoms: `FlutterOverlayWindow.shareData()` calls from overlay to main app hang or fail silently. Long-press close signal from overlay may not reach main app.
- Files: `lib/main.dart` (lines 1063-1069 overlay signal sending), `lib/services/gps_data_manager.dart` (N/A)
- Trigger: Long-press overlay to send close signal back to main app.
- Workaround: Use status polling instead of message-based detection (`_startOverlayStatusCheck()` at line 153).
- Root cause documented in TODO.md: "FlutterOverlayWindow.shareData() from overlay to main app is fundamentally broken"

**HapticFeedback Calls Hang in Overlay Context:**
- Symptoms: HapticFeedback.lightImpact() calls in overlay context cause indefinite hangs (commented out at line 1059).
- Files: `lib/main.dart` (line 1059 intentionally skipped with comment)
- Trigger: Any attempt to call `HapticFeedback.*` methods from overlay widget.
- Workaround: Skip haptic feedback in overlay entirely. Only use on main app screen (lines 415, 424, 649, 657, 775, 783).
- Root cause documented in TODO.md: "HapticFeedback.* calls hang indefinitely in overlay context (platform services unavailable)"

## Security Considerations

**Permission Request Not Validated in All Paths:**
- Risk: `GpsService.requestPermissions()` may return false if permission denied by user, but app continues running with `displaySpeed: 'NO PERM'` marker. No explicit permission re-request flow or user guidance.
- Files: `lib/services/gps_data_manager.dart` (lines 93-103), `lib/gps_service.dart` (lines 17-20)
- Current mitigation: Display 'NO PERM' message to user indicating lack of permission.
- Recommendations: Add UI button to re-request permission with explanation. Handle permission state changes via lifecycle callbacks if location service is toggled while app runs.

**Location Data Transmitted to Overlay Without Verification:**
- Risk: GPS location data (coordinates implicit in speed/heading, potentially in logs) transmitted via `FlutterOverlayWindow.shareData()` which may be intercepted by other processes with SYSTEM_ALERT_WINDOW permission.
- Files: `lib/main.dart` (lines 403-411, 441-450), `lib/services/gps_data_manager.dart` (N/A)
- Current mitigation: Data sent via Flutter internal IPC, not external networking.
- Recommendations: Verify overlay target identity before sharing sensitive location data. Consider encrypting location data for inter-process communication. Document data privacy model.

**No Certificate Pinning for Future API Integrations:**
- Risk: Codebase currently has no external API calls, but structure provides no hook for certificate validation if APIs are added.
- Files: N/A currently
- Current mitigation: N/A
- Recommendations: When adding external API calls, implement certificate pinning and SSL validation. Add secrets management (env vars not checked into git).

## Performance Bottlenecks

**1133-Line Main.dart File Creates Monolithic State Management:**
- Problem: Single `_SpeedometerScreenState` manages GPS subscription, overlay lifecycle, theme cycling, unit cycling, haptic feedback, background heartbeat, overlay status polling, and gesture handling. Complex interdependencies make optimization difficult.
- Files: `lib/main.dart` (entire file, especially lines 65-837)
- Cause: All UI state and cross-cutting concerns collapsed into one widget state. No separation of concerns.
- Improvement path: Extract overlay management to separate `OverlayController` class. Extract compass/navigation into `CompassWidget`. Extract speed display into `SpeedDisplay` widget. Reduces main file to ~400 lines. Would enable independent optimization of each subsystem.

**Background Heartbeat Timer Fires Every 5 Seconds Even When Not Needed:**
- Problem: `_startBackgroundHeartbeat()` (line 197-220) runs on 5-second intervals for the entire app lifetime. Performs setState() even when overlay is inactive and app is in foreground (wasteful).
- Files: `lib/main.dart` (lines 197-220)
- Cause: Timer always runs without condition to stop when not needed. Only guards action inside timer callback, not timer creation.
- Improvement path: Stop heartbeat timer when app resumes foreground and overlay is closed. Restart only when background + overlay active. Would save 5+ timer ticks per minute during normal use.

**Overlay Status Polling Runs Every 1 Second While Overlay Active:**
- Problem: `_startOverlayStatusCheck()` (line 153-174) polls `FlutterOverlayWindow.isActive()` every 1 second. This is async call that may block on every poll.
- Files: `lib/main.dart` (lines 153-174)
- Cause: Workaround for unreliable message-based close detection. Polling is expensive fallback.
- Improvement path: Once overlay message handling is fixed (known bug), remove polling entirely. Fallback to message-based detection which is event-driven rather than time-based.

**Overlay Size Calculation Runs on Every Build:**
- Problem: `_getOverlaySize()` (line 85-94) recalculates overlay dimensions every time overlay is shown by querying `platformDispatcher.views.first.physicalSize`. View dimensions don't change frequently.
- Files: `lib/main.dart` (lines 85-94, called at lines 435, 461)
- Cause: Called from `_showFloatingWindow()` which is synchronous but not cached.
- Improvement path: Cache overlay size on first calculation. Invalidate cache only on orientation change or platform dispatcher size change. Would save repeated calculations on repeated overlay launches.

## Fragile Areas

**GpsDataManager Singleton State Not Thread-Safe:**
- Files: `lib/services/gps_data_manager.dart` (lines 42-50)
- Why fragile: `_instance` variable is lazily initialized without synchronization. If `GpsDataManager.instance` is called from multiple isolates or during hot-reload, could create multiple instances. `_dataController` broadcast stream is also not protected from concurrent additions.
- Safe modification: Check if used from single isolate only (likely true in Flutter). Add comment documenting single-threaded assumption. For multi-threaded use, wrap initialization in `Mutex` or use `async` getter.
- Test coverage: No unit tests. No integration tests for concurrent access patterns.

**Overlay Widget Assumes Shared Data Structure Without Validation:**
- Files: `lib/main.dart` (lines 897-927, the `_OverlaySpeedometerState._listenToMainAppMessages()`)
- Why fragile: Overlay widget assumes incoming map data has expected keys (`speedText`, `unitText`, etc.). Missing keys get null and default values. If main app changes data structure, overlay silently receives invalid data. No schema validation.
- Safe modification: Add data validation function that checks for required keys before processing. Document expected message schema as Dart class/typedef. Type-safe would require moving message handling to common file.
- Test coverage: No unit tests for message deserialization. No schema validation tests.

**GpsDataManager Display Logic Disabled Means Invalid Data State:**
- Files: `lib/services/gps_data_manager.dart` (line 172, comment), `lib/main.dart` (line 501, comment)
- Why fragile: With TODO-disabled validation, invalid GPS speeds can propagate to UI. Code assumes `displaySpeed == '--'` check at line 246 and 243, but that won't match if speed is invalid.
- Safe modification: Create feature flag `const bool kEnableLowSpeedValidation = false;` and wrap logic. Then toggle to true when ready. This documents the temporary nature and makes re-enabling obvious.
- Test coverage: No tests for low-speed heading suppression logic.

**Overlay Creation Success Not Verified:**
- Files: `lib/main.dart` (line 453-478)
- Why fragile: `FlutterOverlayWindow.showOverlay()` completes without error, but overlay may fail to display due to platform restrictions (permissions, Android version, overlay count limits). Code immediately sets `_isOverlayActive = true` (line 468) without waiting to confirm overlay actually appeared.
- Safe modification: Add verification step after `showOverlay()` call. Wait for first GPS data update or first message from overlay to confirm it started. Set `_isOverlayActive = true` only after confirmation. Currently relying on `_startOverlayStatusCheck()` to detect if overlay is really active.
- Test coverage: No tests. Manual testing on different Android versions needed.

## Scaling Limits

**Single ProcessedGpsData Stream for All Consumers:**
- Current capacity: Single broadcast stream shared by main app + overlay messaging. GPS updates broadcast to all listeners every time, even if only main app needs update.
- Limit: If multiple independent overlay instances tried to subscribe (not current behavior), stream backpressure could cause updates to queue. Currently not scalable to background service model.
- Scaling path: Extract data provider to platform channel with multiple listener support. Or move to provider/GetX for proper multi-listener state management. Document why direct stream subscriptions chosen.

**Hardcoded Timeout Values for GPS and Stale Data:**
- Current capacity: Initial GPS timeout 20s, ongoing stream timeout 2s, stale data threshold 4s. Values tuned for mobile use.
- Limit: Cannot adjust timeouts without code change + rebuild. Fails on edge devices with poor GPS (rural areas, deep indoors). No adaptive timeout mechanism.
- Scaling path: Make timeouts configurable via SharedPreferences settings screen. Allow user to dial in for their use case (rural vs. urban, indoor vs. outdoor).

## Dependencies at Risk

**flutter_overlay_window: Multiple Known Issues:**
- Risk: Package has known limitations (shared data communication broken, gesture detection unreliable) documented in TODO.md and throughout code as hardcoded workarounds.
- Impact: If package is not maintained or breaks in future Android versions, overlay feature will stop working. No fallback implementation.
- Migration plan: Maintain fallback to non-overlay display mode (remove GPS data from overlay, user keeps main app in foreground). Or migrate to newer overlay library if available. Pin to specific version and test on each Flutter/Android release.

**geolocator & permission_handler: Version Pinning:**
- Risk: `pubspec.yaml` pins geolocator to `^14.0.2` and permission_handler to `^12.0.1`. These are major versions so minor updates are allowed, but breaking changes possible. Project was previously on lower versions.
- Impact: Flutter dependency resolution could pull incompatible minor version. Not currently a blocker but prevents easy updates.
- Migration plan: After each Flutter/Android release, run `flutter pub upgrade --dry-run` to check available updates. Test on physical device before committing. Document breaking changes when they occur. Consider migrating to `geolocator: 14.x.x` style for more flexibility.

**bg_launcher: Minimal Package with Limited Maintenance:**
- Risk: `bg_launcher` is a small utility package for bringing app to foreground. May not be maintained actively. Only has 1 public method (`bringAppToForeground()`).
- Impact: If package breaks or is removed from pub.dev, overlay long-press close won't bring main app to foreground. Would require platform-specific implementation via method channels.
- Migration plan: Document method channel approach in comments. If bg_launcher fails, implement native Android code to bring app to foreground using `startActivity()`. Keep fallback ready.

## Missing Critical Features

**No User-Facing Error Messages for Overlay Failures:**
- Problem: If overlay fails to create, user gets no indication. Code catches exception (line 479-481) but prints nothing. User sees no overlay and no error, assumes app is broken.
- Blocks: Users cannot diagnose why overlay won't appear. Cannot report meaningful feedback.
- Recommendation: Display toast/snackbar if overlay creation fails: "Floating window permission denied. Check app permissions." Include specific error category in message.

**No Permission Re-Request Flow:**
- Problem: If user denies GPS permission, app shows 'NO PERM' message. No button to retry or open settings to grant permission.
- Blocks: User must manually go to Settings > App > Permissions to re-grant. App cannot recover from denied permission state.
- Recommendation: Add "Request Permission" button when 'NO PERM' is displayed. Call `openAppSettings()` from permission_handler to open system settings if user wants to grant manually.

**No Connection to SharedPreferences (Mentioned in CLAUDE.md but Not Implemented):**
- Problem: CLAUDE.md mentions "Persistence: SharedPreferences for settings" and states v2.1.0 had "Customizable speed units (km/h, mph) with persistent storage". Current code has no SharedPreferences integration.
- Blocks: Unit selection resets on app restart. Theme selection resets on app restart. No way to save user preferences.
- Recommendation: Implement SharedPreferences save/load for `_currentUnit` and `_currentThemeIndex`. Load from preferences in `initState()`. Save on each change.

## Test Coverage Gaps

**No Unit Tests for GpsDataManager:**
- What's not tested: ProcessedGpsData copyWith(), data stream broadcasting, stale data timeout, error handling, speed formatting logic.
- Files: `lib/services/gps_data_manager.dart` (entire file)
- Risk: Changes to GPS data processing logic could break undetected. Stale data timeout edge cases not verified. Heading validation changes could silently fail.
- Priority: High - GPS data is core to app functionality. Stale data timeout is time-sensitive logic prone to off-by-one errors.

**No Tests for Overlay Message Deserialization:**
- What's not tested: Map data validation, missing key handling, type coercion, corrupt data recovery.
- Files: `lib/main.dart` (lines 897-927)
- Risk: If main app changes message format, overlay silently receives invalid data. Edge case where heading > 360 or speed is negative not tested.
- Priority: Medium - affects overlay reliability but occurs in steady state, not initialization.

**No Integration Tests for Main/Overlay Communication:**
- What's not tested: shareData() timing, message ordering, concurrent updates, cleanup on close.
- Files: `lib/main.dart` (lines 403-411, 441-450 main→overlay; lines 1063-1069 overlay→main; lines 346-352 subscription setup)
- Risk: Race conditions between overlay creation and first data push. Message loss if overlay closes while data is in flight. Zombie overlays not cleaned up.
- Priority: High - known bugs in this area (unreliable bidirectional communication) need test-driven fixes.

**No Tests for Lifecycle State Management:**
- What's not tested: App resume/pause/terminate → overlay state transitions, timer cleanup on dispose, subscription cleanup on reload.
- Files: `lib/main.dart` (lines 267-277 dispose, lines 280-300 lifecycle callbacks, lines 96-98 timer initialization)
- Risk: Memory leaks from uncanceled timers. Orphaned subscriptions. Overlays not closed on app exit.
- Priority: High - affects app stability and battery life. Timer leak easily happens with hot-reload during development.

**No Manual Device Testing Documentation:**
- What's not tested: App behavior on different Android versions (11, 12, 13, 14), different screen sizes (phones, tablets), different GPS conditions (outdoor, indoor, no signal).
- Files: All files
- Risk: Overlay feature tested only on developer's device. May fail silently on other devices. No way to onboard new testers or validate before release.
- Priority: Medium - critical for APK release but not blocking development. TODO.md mentions "Requires physical Android device for GPS functionality" but gives no testing checklist.

---

*Concerns audit: 2026-02-09*
