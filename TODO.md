**When updating this file, always keep it short and concise: under 1024 tokens. DO NOT REMOVE THIS LINE**
# GPS Speedometer - Lightweight Overhaul TODO

**Project Vision:** Ultra-lightweight Android split-screen/floating window GPS speedometer.

## ✅ COMPLETED (v2.2.2 - Master Branch)

**v2.2.2 Background Persistence & Communication:**
- Implemented lazy overlay listener creation/destruction - eliminated ghost overlay
- Added 2Hz cached GPS data push for smooth overlay updates
- Enhanced background persistence with wake locks and heartbeat mechanisms  
- Proper Android foreground functionality using bg_launcher package
- Fixed overlay state management race conditions
- Added comprehensive debug logging throughout communication system
- Improved Android manifest with background persistence permissions
- Eliminated overlay status polling interference with data flow

**v2.2.0 Floating Window Improvements:**
- Fixed overlay size calculation using physical pixels instead of scaled logical pixels
- Proper state synchronization between main app and overlay
- Split decimal display: main speed prominent, smaller faded decimal fraction
- Optimized content sizing with improved responsive layout
- Android SYSTEM_ALERT_WINDOW permissions configured
- Tap navigation area to show floating window, long-press to close

## 🔄 REMAINING

**Overlay Interaction Issues (Partially Working):**
- [x] Fixed overlay unit display syntax and layout issues
- [x] Implemented overlay status monitoring with FlutterOverlayWindow.isActive()
- [x] Fixed duplicate dispose() method causing widget lifecycle issues
- [x] Removed tap-to-close to prevent accidental closure from dragging
- [x] Enhanced debugging for overlay creation/disposal tracking
- [ ] **Long press close on second+ overlays non-functional** - gestures work on first overlay only
- [x] Tap brings main app to foreground (when bidirectional communication works)
- [ ] Bidirectional overlay communication unreliable (shareData() hangs or fails silently)

**Root Cause Analysis:**
- HapticFeedback.* calls hang indefinitely in overlay context (platform services unavailable)
- FlutterOverlayWindow.shareData() from overlay to main app is fundamentally broken
- Overlay status monitoring via .isActive() works reliably
- Gesture detection works on first overlay but fails on subsequent overlays

**Technical Approach:**
- Fire-and-forget communication pattern implemented
- Non-blocking overlay interactions with fallback mechanisms
- Comprehensive debug logging for troubleshooting

**Critical Issues:**
- ✅ Fix Android APK installation - both debug and release builds marked as invalid by Android
- [ ] Update packages to latest compatible versions  

**Future Features:**
- [ ] Desktop widget
- [ ] Background color customization  
- [ ] User-defined layout customization

## 🎯 STATUS: v2.2.3-wip Overlay Interactions Partially Fixed

Overlay functionality **somewhat working**: first overlay responds to gestures, subsequent overlays display correctly but gesture detection fails. Bidirectional communication between overlay and main app proven unreliable. Status monitoring approach implemented as workaround. Main speedometer fully functional.