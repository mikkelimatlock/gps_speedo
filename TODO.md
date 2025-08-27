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

**Overlay Interaction Issues:**
- [ ] Fix overlay tap to bring main app to front - currently non-functional
- [ ] Fix overlay long press close functionality - currently non-functional

**Critical Issues:**
- [ ] Fix Android APK installation - both debug and release builds marked as invalid by Android
- [ ] Update packages to latest compatible versions  

**Future Features:**
- [ ] Desktop widget
- [ ] Background color customization
- [ ] User-defined layout customization

## 🎯 STATUS: v2.2.2 Background Persistence Enhanced

Core floating window functionality and data flow working well. Overlay displays updates smoothly with 2Hz cached GPS data. Background persistence significantly improved. Overlay gesture interactions need attention but main UI fully functional.