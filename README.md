# GPS Speedometer

A GPS Speedometer aimed at Android on Motorcycle / Bicycle applications.
**Created with the help of Claude Code**

## Features

### Core Functionality
- Real-time speed display using GPS
- Maybe also direction display using GPS
- Good floating window / split screen support(hopefully)

### Customizable Settings
- **Speed Units**: mph, km/h, knots (with convenient unit selector buttons)
- **Theme**: Light/Dark mode (expandable for custom themes)

### Technical Specifications
- Target Platform: Android (primary)
- Target Device: Mobile phones and tablets
- GPS Requirements: Location permissions required
- Offline Capability: Full functionality without internet

## Architecture Design

*To be updated*

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
