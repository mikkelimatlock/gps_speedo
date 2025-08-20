# GPS Speedometer - Claude Code Project Memory

## Project Overview
A customizable Flutter GPS speedometer app targeting Android devices, emphasizing modularity and user customization.

## Current Status: v1.1 Complete 
**Enhanced GPS speedometer with improved user experience and customization options.**

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
Dependencies: geolocator, permission_handler, provider, shared_preferences, flutter_material_color_picker
Platforms: Android (primary), iOS support included but untested
Architecture: Provider + Consumer pattern for reactive state management
Permissions: Location services with graceful degradation
```

## Recent Updates (v1.1)

### ✅ Completed Features
- [x] **Portrait/Landscape Support**: Automatic orientation detection implemented
- [x] **Interactive Gauge**: Click gauge face to switch digital/analog modes
- [x] **Extended Speed Units**: Added knots support with quick selector buttons

## TODO - Future Improvements

### Critical Issues
- [ ] **Dependency Updates**: Update 10 packages to latest compatible versions
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