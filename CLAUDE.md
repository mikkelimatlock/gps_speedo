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

### ✅ Completed Features
- [x] **Floating Window Overlay**: System-level overlay window for persistent speed display over other apps
- [x] **Split Decimal Display**: Main speed prominent with smaller, faded decimal fraction for better readability
- [x] **Optimized Content Sizing**: Maximized readability with improved responsive layout and flex ratios
- [x] **Navigation Icon Trigger**: Tap compass/navigation area to launch floating window overlay
- [x] **Multiple Close Options**: Overlay close button and long-press navigation area for easy dismissal
- [x] **Theme Synchronization**: Dark/Light theme and speed unit settings sync between main app and overlay
- [x] **Android System Integration**: SYSTEM_ALERT_WINDOW permissions and foreground service configuration

### Previous Updates (v1.1)
- [x] **Portrait/Landscape Support**: Automatic orientation detection implemented  
- [x] **Interactive Gauge**: Click gauge face to switch digital/analog modes
- [x] **Extended Speed Units**: Added knots support with quick selector buttons

## TODO - Future Improvements

### Known Issues (v2.1.0)
- [ ] **Floating Window Sizing**: Content sizing calculations need refinement for better overlay display
- [ ] **Overlay Positioning**: Improve stability and positioning consistency across different devices
- [ ] **Content Synchronization**: Enhance real-time sync between main app and overlay window

### Critical Issues
- [ ] **Dependency Updates**: Update packages to latest compatible versions
- [ ] **Orientation Override**: Fix auto-rotate to work regardless of system toggle status

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

## Code Patterns to Maintain
- Provider pattern for state management
- Separate widgets for reusability  
- Settings persistence with SharedPreferences
- Graceful error handling for GPS/permissions
- Responsive design principles