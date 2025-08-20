# GPS Speedometer

A customizable Flutter speedometer app using GPS location services to display real-time speed.  
**Created with the help of Claude Code**

## Features

### Core Functionality
- Real-time speed display using GPS
- High-precision location tracking
- Works offline (no internet connection required)
- Portrait orientation for mobile phones

### Customizable Settings
- **Speed Units**: mph, km/h (expandable for more units)
- **Display Style**: Digital speedometer, analog gauge (expandable for more styles)
- **Theme**: Light/Dark mode (expandable for custom themes)
- **Metrics Display**: Toggle additional metrics on/off
  - Current location coordinates
  - Distance traveled
  - Trip duration
  - Current speed accuracy

### Technical Specifications
- Target Platform: Android (primary)
- Screen Orientation: Portrait (locked)
- Target Device: Mobile phones
- GPS Requirements: Location permissions required
- Offline Capability: Full functionality without internet

## Architecture Design

The app is designed with customization and extensibility in mind:
- Settings system supports multiple options per category
- Modular design allows easy addition of new speedometer styles
- Theme system supports unlimited themes
- Metrics system allows toggle individual data points

## Permissions Required
- `ACCESS_FINE_LOCATION` - For high-precision GPS tracking
- `ACCESS_COARSE_LOCATION` - Fallback location access

## Getting Started

### Prerequisites
- Flutter SDK
- Android development environment
- Physical device recommended (GPS simulation limited in emulator)

### Installation
1. Clone the repository
2. Run `flutter pub get`
3. Connect Android device or start emulator
4. Run `flutter run`

### Development
- `flutter run` - Run the app in development mode
- `flutter build apk` - Build APK for Android
- `flutter test` - Run unit tests
