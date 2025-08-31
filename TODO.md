**When updating this file, always keep it short and concise: under 1024 tokens. DO NOT REMOVE THIS LINE**
# GPS Speedometer - Lightweight Overhaul TODO

**Project Vision:** Ultra-lightweight Android split-screen/floating window GPS speedometer.

## ✅ COMPLETED (v2.3.0-dev - Feature Branch)

**v2.3.0-dev GPS Manager Architecture:**
- Implemented GpsDataManager singleton service for centralized GPS data processing
- Refactored main app to use processed GPS data streams instead of raw position data
- Added haptic feedback to all main UI tap interactions (theme, unit, navigation)
- Cleaned up verbose debug logging while preserving essential error handling
- Separate GPS timeouts: 20s initial fix, 2s ongoing updates for indoor/outdoor use
- Temporarily disabled low-speed logic for indoor testing and development
- Clean data flow: GPS Hardware → GpsDataManager → Main App → Overlay
- Foundation ready for intelligent caching logic implementation

**v2.2.2 Background Persistence & Communication:**
- Enhanced background persistence with wake locks and heartbeat mechanisms  
- Proper Android foreground functionality using bg_launcher package
- Fixed overlay state management race conditions
- Improved Android manifest with background persistence permissions

**v2.2.0 Floating Window Improvements:**
- Fixed overlay size calculation using physical pixels instead of scaled logical pixels
- Split decimal display: main speed prominent, smaller faded decimal fraction
- Android SYSTEM_ALERT_WINDOW permissions configured

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
- [ ] Intelligent caching logic: 2-4 second time windows, cached heading from valid speeds >2 km/h
- [ ] Desktop widget
- [ ] Background color customization  
- [ ] User-defined layout customization

## 🎯 STATUS: v2.3.0-dev GPS Architecture Complete

GPS manager architecture implemented and functional. Clean separation of concerns with centralized GPS processing. Overlay functionality preserved from previous version. Ready for intelligent caching logic implementation and merge to master.