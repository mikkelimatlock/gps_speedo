# GPS Speedometer - Claude Code Project Memory

## Project Overview
A customizable Flutter GPS speedometer app targeting Android devices, emphasizing modularity and user customization.

## Current Status: v2.1.0 Complete 
**GPS speedometer with floating window overlay functionality and optimized visual design.**

### Architecture Implemented
- **State Management:** Provider pattern
- **Structure:** Modular widgets, providers, screens separation
- **Persistence:** SharedPreferences for settings
- **GPS Service:** Geolocator with permission handling
- **UI Patterns:** Consumer widgets, responsive design

### Core Features Completed
-  Real-time GPS speed tracking with accuracy monitoring
-  Customizable speed units (km/h � mph) with persistent storage
-  Dual display styles: Digital speedometer + Analog gauge
-  Dark/Light theme support with system integration
-  Optional metrics panel: coordinates, distance, trip time, accuracy
-  Trip reset functionality and comprehensive error handling
-  Portrait orientation lock for mobile-first experience
-  Android permissions configuration (FINE_LOCATION, COARSE_LOCATION)

### Technical Stack
```
Dependencies: geolocator, permission_handler, provider, shared_preferences, flutter_material_color_picker, flutter_overlay_window
Platforms: Android (primary), iOS support included but untested
Architecture: Provider + Consumer pattern for reactive state management
Permissions: Location services + SYSTEM_ALERT_WINDOW for overlay functionality
```

## Recent Updates (v2.1.0)

### ✅ Completed Features (Master Branch - Stable)
- [x] **Split Decimal Display**: Main speed prominent with smaller, faded decimal fraction for better readability
- [x] **Optimized Content Sizing**: Maximized readability with improved responsive layout and flex ratios
- [x] **Basic Floating Window**: Simple overlay with "GPS SPEEDO" text and close button (stable implementation)
- [x] **Navigation Icon Trigger**: Tap compass/navigation area to launch floating window overlay
- [x] **Multiple Close Options**: Overlay close button and long-press navigation area for easy dismissal
- [x] **Android System Integration**: SYSTEM_ALERT_WINDOW permissions and foreground service configuration

### 🚧 Work in Progress Features (dev/floating-window-wip Branch - Seriously Buggy)
- [ ] **Advanced Floating Window Overlay**: System-level overlay with live GPS data - basic functionality works but seriously buggy
  - GPS data synchronization implemented but unreliable
  - Theme/unit sync between main app and overlay works partially
  - Proportional sizing and positioning needs major refinement
  - Close button functionality works but overlay behavior inconsistent
  - Performance may impact main app, needs optimization

### Previous Updates (v1.1)
- [x] **Portrait/Landscape Support**: Automatic orientation detection implemented  
- [x] **Interactive Gauge**: Click gauge face to switch digital/analog modes
- [x] **Extended Speed Units**: Added knots support with quick selector buttons

## TODO - Future Improvements

### Known Issues

**Master Branch (v2.1.0 - Stable):**
- [ ] **Dependency Updates**: Update packages to latest compatible versions
- [ ] **Orientation Override**: Fix auto-rotate to work regardless of system toggle status

**Dev Branch (floating-window-wip - Seriously Buggy):**
- [ ] **Floating Window Reliability**: Overlay behavior inconsistent across different devices and Android versions
- [ ] **GPS Data Sync**: Real-time GPS synchronization between main app and overlay unreliable
- [ ] **Theme/Unit Sync**: Setting synchronization works partially but not consistently
- [ ] **Overlay Positioning**: Poor positioning stability, sizing calculations need major work
- [ ] **Performance**: Overlay may impact main app performance, needs optimization

### UI/UX Enhancements
- [ ] **Background Customization**: Custom background color selection
- [ ] **Interface Rearrangement**: User-defined layout customization
- [ ] **Settings Menu Refurbishment**: More intuitive interactions and better UX

### Technical Improvements  
- [ ] **Font Embedding**: Consider custom fonts for better typography
- [ ] **Feature Removal**: Identify and remove unused/redundant functionalities
- [ ] **Code Cleanup**: Refactor deprecated warnings, optimize performance

### Design Philosophy
- Preserve modularity for easy future extensions
- Prioritize user customization options
- Maintain clean, extensible architecture
- Focus on mobile-first, gesture-friendly interactions

## Development Notes
- **Testing**: Requires physical Android device for GPS functionality
- **Build System**: Standard Flutter build process, first builds take time for Android SDK setup
- **Memory**: Project uses automatic Claude Code memory - this file for major decisions only
- **Git**: Active repository at `https://github.com/mikkelimatlock/gps_speedo`

## Branch Strategy
- **master**: Stable releases, ready for production APK builds
- **dev/floating-window-wip**: Advanced floating window development (seriously buggy, not for release)
- Tagged releases: v2.1.0 on master branch contains stable basic floating window

## Code Patterns to Maintain
- Provider pattern for state management
- Separate widgets for reusability  
- Settings persistence with SharedPreferences
- Graceful error handling for GPS/permissions
- Responsive design principles