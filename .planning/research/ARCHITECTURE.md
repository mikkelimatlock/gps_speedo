# Architecture Patterns: Flutter GPS Speedometer

**Domain:** GPS speedometer mobile application
**Researched:** 2026-02-09
**Confidence:** HIGH

## Executive Summary

Flutter GPS speedometer apps require clean separation between **UI**, **state management**, **GPS data processing**, and **overlay communication**. The recommended architecture follows Flutter's MVVM pattern with Provider state management, modular widget extraction, and a dedicated overlay service for reliable system-level window communication.

**Key architectural decision:** Use **Provider with ChangeNotifier** for reactive state management, extract widgets by feature/responsibility, maintain GPS data flow through a centralized manager, and architect overlay communication with explicit message schemas to avoid data staleness.

## Recommended Architecture

### Layer Structure (MVVM + Provider)

```
┌──────────────────────────────────────────────────────┐
│                   UI Layer (Views)                    │
│  - screens/                                           │
│    └── speedometer_screen.dart (StatelessWidget)     │
│  - widgets/                                           │
│    ├── speed_display.dart                            │
│    ├── heading_compass.dart                          │
│    ├── metrics_panel.dart                            │
│    ├── unit_selector.dart                            │
│    └── theme_selector.dart                           │
├──────────────────────────────────────────────────────┤
│            State Management (ViewModels)              │
│  - providers/                                         │
│    ├── speedometer_provider.dart (ChangeNotifier)    │
│    ├── theme_provider.dart (ChangeNotifier)          │
│    └── overlay_provider.dart (ChangeNotifier)        │
├──────────────────────────────────────────────────────┤
│            Services (Data/Logic Layer)                │
│  - services/                                          │
│    ├── gps_data_manager.dart (Singleton)             │
│    ├── gps_service.dart (GPS permissions/stream)     │
│    └── overlay_service.dart (Overlay lifecycle)      │
├──────────────────────────────────────────────────────┤
│            Models (Domain Objects)                    │
│  - models/                                            │
│    ├── processed_gps_data.dart                       │
│    ├── overlay_message.dart                          │
│    ├── speedometer_settings.dart                     │
│    └── trip_stats.dart                               │
├──────────────────────────────────────────────────────┤
│          Configuration (Constants/Themes)             │
│  - config/                                            │
│    ├── speed_units.dart                              │
│    └── color_themes.dart                             │
└──────────────────────────────────────────────────────┘
```

### Data Flow Architecture

```
GPS Hardware
    ↓
[GpsDataManager (Singleton)]
    ↓ Broadcast Stream (ProcessedGpsData)
    ↓
[SpeedometerProvider (ChangeNotifier)]
    ↓ notifyListeners()
    ↓
[Consumer Widgets] → Speed Display, Compass, Metrics
    ↓
[OverlayProvider] → Structured OverlayMessage
    ↓
[OverlayService] → FlutterOverlayWindow.shareData()
    ↓
[Overlay Window (Separate Isolate)]
```

**Key principle:** Unidirectional data flow with clear boundaries. GPS data flows DOWN through managers → providers → widgets. User interactions flow UP through callbacks → provider methods → service calls.

## Component Boundaries

### 1. Screens (UI Entry Points)

**Location:** `lib/screens/`

**Responsibility:**
- Top-level widget compositions with Scaffold
- Route handling and navigation
- Provider setup for the screen scope
- Layout structure (portrait/landscape)

**What goes here:**
- `speedometer_screen.dart`: Main screen with speed display, compass, metrics panel
- `overlay_speedometer.dart`: Overlay window entry point (separate isolate)

**What does NOT go here:**
- Business logic (use providers)
- Direct GPS access (use services)
- Reusable UI components (use widgets/)
- setState calls (use Consumer/Provider)

**Example structure:**
```dart
// speedometer_screen.dart
class SpeedometerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<SpeedometerProvider>(
        builder: (context, speedometer, child) {
          return OrientationBuilder(
            builder: (context, orientation) {
              return orientation == Orientation.portrait
                ? _buildPortraitLayout(speedometer)
                : _buildLandscapeLayout(speedometer);
            },
          );
        },
      ),
    );
  }
}
```

### 2. Widgets (Reusable UI Components)

**Location:** `lib/widgets/`

**Responsibility:**
- Self-contained, reusable UI components
- Presentational logic only (conditionals, animations, layout)
- Consume state via Consumer or context.watch
- Expose callbacks for user interactions

**Component breakdown:**

| Widget | Purpose | State Access | Events Emitted |
|--------|---------|--------------|----------------|
| `speed_display.dart` | Digital speed with unit, split decimal formatting | SpeedometerProvider | onTap (toggle unit) |
| `heading_compass.dart` | Rotating compass icon with heading text | SpeedometerProvider | onTap (launch overlay), onLongPress (close overlay) |
| `metrics_panel.dart` | Coordinates, distance, trip time, accuracy | SpeedometerProvider | onResetTrip |
| `unit_selector.dart` | Quick unit selection buttons | SpeedometerProvider | onUnitSelected |
| `theme_selector.dart` | Theme picker UI | ThemeProvider | onThemeSelected |
| `analog_gauge.dart` | Circular speedometer gauge | SpeedometerProvider | onTap (switch mode) |

**Anti-pattern to avoid:**
```dart
// ❌ DON'T: Widget with business logic
class SpeedDisplay extends StatefulWidget {
  @override
  State<SpeedDisplay> createState() => _SpeedDisplayState();
}

class _SpeedDisplayState extends State<SpeedDisplay> {
  StreamSubscription<ProcessedGpsData>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = GpsDataManager.instance.dataStream.listen((data) {
      setState(() { /* update local state */ });
    });
  }
}

// ✅ DO: Widget consuming provider state
class SpeedDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SpeedometerProvider>(
      builder: (context, speedometer, child) {
        return Text(speedometer.displaySpeed);
      },
    );
  }
}
```

### 3. Providers (State Management / ViewModels)

**Location:** `lib/providers/`

**Responsibility:**
- Extend ChangeNotifier to manage UI state
- Subscribe to service streams (GPS, overlay events)
- Transform service data into UI-ready format
- Expose commands (methods) for user interactions
- Call `notifyListeners()` when state changes

**Provider breakdown:**

#### SpeedometerProvider (Primary State)
```dart
class SpeedometerProvider extends ChangeNotifier {
  final GpsDataManager _gpsManager;
  final OverlayService _overlayService;
  StreamSubscription<ProcessedGpsData>? _gpsSubscription;

  // UI-ready state
  String displaySpeed = '--';
  String displayHeading = 'N/A';
  double heading = -1.0;
  SpeedUnit currentUnit = SpeedUnit.kmh;
  bool isGpsActive = false;
  TripStats tripStats = TripStats.empty();

  SpeedometerProvider({
    required GpsDataManager gpsManager,
    required OverlayService overlayService,
  }) : _gpsManager = gpsManager,
       _overlayService = overlayService {
    _init();
  }

  Future<void> _init() async {
    await _gpsManager.initialize();
    _gpsSubscription = _gpsManager.dataStream.listen(_onGpsDataUpdate);
  }

  void _onGpsDataUpdate(ProcessedGpsData data) {
    displaySpeed = data.displaySpeed;
    displayHeading = data.displayHeading;
    heading = data.heading;
    isGpsActive = data.isSpeedValid;

    // Update trip stats
    tripStats = tripStats.update(data);

    notifyListeners(); // Triggers Consumer rebuilds

    // Push to overlay if active
    if (_overlayService.isActive) {
      _overlayService.sendUpdate(
        OverlayMessage.speedUpdate(
          speedText: displaySpeed,
          headingText: displayHeading,
          heading: heading,
          unitText: currentUnit.label,
          themeIndex: _themeProvider.currentIndex,
        ),
      );
    }
  }

  // Command methods (called by UI)
  void toggleUnit() {
    currentUnit = currentUnit.next;
    notifyListeners();
  }

  void resetTrip() {
    tripStats = TripStats.empty();
    notifyListeners();
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    super.dispose();
  }
}
```

#### ThemeProvider (Theme State)
```dart
class ThemeProvider extends ChangeNotifier {
  int _currentThemeIndex = 0;

  int get currentThemeIndex => _currentThemeIndex;
  ColorTheme get currentTheme => ColorThemes.getTheme(_currentThemeIndex);

  void nextTheme() {
    _currentThemeIndex = ColorThemes.getNextThemeIndex(_currentThemeIndex);
    notifyListeners();
  }
}
```

#### OverlayProvider (Overlay State)
```dart
class OverlayProvider extends ChangeNotifier {
  final OverlayService _overlayService;
  bool isOverlayActive = false;

  OverlayProvider(this._overlayService) {
    _overlayService.statusStream.listen((active) {
      isOverlayActive = active;
      notifyListeners();
    });
  }

  Future<void> showOverlay() async {
    await _overlayService.show();
  }

  Future<void> closeOverlay() async {
    await _overlayService.close();
  }
}
```

### 4. Services (Data/Logic Layer)

**Location:** `lib/services/`

**Responsibility:**
- Encapsulate external APIs (GPS, platform channels, overlays)
- Manage background processes and lifecycle
- Provide streams or futures for data access
- Handle error states and retries
- Stateless where possible (except lifecycle management)

**Service breakdown:**

#### GpsDataManager (EXISTING - Keep as-is)
**Status:** Already implemented correctly as singleton
**Confidence:** HIGH

```dart
class GpsDataManager {
  static GpsDataManager? _instance;
  static GpsDataManager get instance => _instance ??= GpsDataManager._internal();

  final StreamController<ProcessedGpsData> _dataController =
      StreamController<ProcessedGpsData>.broadcast();

  Stream<ProcessedGpsData> get dataStream => _dataController.stream;
  ProcessedGpsData get currentData => _currentData;

  Future<void> initialize() async { /* existing logic */ }
  void dispose() { /* existing logic */ }
}
```

**Why it works:**
- Singleton pattern ensures single GPS stream
- Broadcast stream allows multiple listeners (providers + overlay)
- Centralized timeout and stale data handling
- Already separates raw GPS → processed display logic

**Change needed:** None. Keep this service intact.

#### GpsService (EXISTING - Keep as static utility)
**Status:** Already correctly structured
**Confidence:** HIGH

Static utility class for GPS permissions and stream creation. No changes needed.

#### OverlayService (NEW - Extract from main.dart)
**Purpose:** Manage overlay lifecycle and communication
**Confidence:** MEDIUM (overlay communication has known reliability issues)

```dart
class OverlayService {
  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  bool _isActive = false;
  bool get isActive => _isActive;

  Timer? _heartbeatTimer;

  Future<void> show({
    required int width,
    required int height,
  }) async {
    if (_isActive) return;

    final hasPermission = await FlutterOverlayWindow.requestPermission();
    if (!hasPermission) {
      throw OverlayPermissionException();
    }

    await FlutterOverlayWindow.showOverlay(
      width: width,
      height: height,
      enableDrag: true,
    );

    _isActive = true;
    _statusController.add(true);
    _startHeartbeat();
  }

  Future<void> close() async {
    _heartbeatTimer?.cancel();
    await FlutterOverlayWindow.closeOverlay();
    _isActive = false;
    _statusController.add(false);
  }

  void sendUpdate(OverlayMessage message) {
    if (!_isActive) return;

    FlutterOverlayWindow.shareData(message.toJson()).catchError((error) {
      print('[OverlayService] Failed to send update: $error');
      // Don't throw - overlay may have closed
    });
  }

  void _startHeartbeat() {
    // Periodic updates to keep overlay in sync
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkOverlayStatus(),
    );
  }

  Future<void> _checkOverlayStatus() async {
    final active = await FlutterOverlayWindow.isActive();
    if (active != _isActive) {
      _isActive = active;
      _statusController.add(active);
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _statusController.close();
  }
}
```

**Key design decisions:**
- Encapsulates all overlay platform channel calls
- Status stream for reactive overlay state
- Heartbeat for status polling (overlay runs in separate isolate)
- Graceful error handling (overlay communication can fail)

### 5. Models (Domain Objects)

**Location:** `lib/models/`

**Responsibility:**
- Define data structures with immutability
- Provide copyWith, toJson, fromJson methods
- No business logic (just data + serialization)

**Model breakdown:**

#### ProcessedGpsData (EXISTING - Move from service to models/)
```dart
class ProcessedGpsData {
  final double speed;
  final double heading;
  final String displaySpeed;
  final String displayHeading;
  final bool isSpeedValid;
  final bool isHeadingValid;

  const ProcessedGpsData({ /* ... */ });

  ProcessedGpsData copyWith({ /* ... */ });
}
```

#### OverlayMessage (NEW - Typed message schema)
```dart
class OverlayMessage {
  final String action;
  final Map<String, dynamic> payload;

  OverlayMessage({required this.action, required this.payload});

  factory OverlayMessage.speedUpdate({
    required String speedText,
    required String headingText,
    required double heading,
    required String unitText,
    required int themeIndex,
  }) {
    return OverlayMessage(
      action: 'updateDisplay',
      payload: {
        'speedText': speedText,
        'headingText': headingText,
        'heading': heading,
        'unitText': unitText,
        'themeIndex': themeIndex,
      },
    );
  }

  factory OverlayMessage.close() {
    return OverlayMessage(action: 'close', payload: {});
  }

  Map<String, dynamic> toJson() => {'action': action, ...payload};
}
```

**Why typed messages?**
- Prevents typos in action strings
- Centralizes message structure
- Makes refactoring safer
- Self-documenting

#### TripStats (NEW - Extract trip logic)
```dart
class TripStats {
  final double totalDistance;
  final Duration tripDuration;
  final DateTime? startTime;

  const TripStats({
    this.totalDistance = 0.0,
    this.tripDuration = Duration.zero,
    this.startTime,
  });

  factory TripStats.empty() => const TripStats();

  TripStats update(ProcessedGpsData data) {
    // Trip calculation logic
  }

  TripStats copyWith({ /* ... */ });
}
```

#### SpeedometerSettings (NEW - Persistent settings)
```dart
class SpeedometerSettings {
  final SpeedUnit unit;
  final int themeIndex;
  final bool showMetrics;

  const SpeedometerSettings({
    this.unit = SpeedUnit.kmh,
    this.themeIndex = 0,
    this.showMetrics = true,
  });

  Map<String, dynamic> toJson() { /* ... */ }
  factory SpeedometerSettings.fromJson(Map<String, dynamic> json) { /* ... */ }
}
```

### 6. Configuration (Constants/Enums/Themes)

**Location:** `lib/config/`

**Files:**
- `speed_units.dart` (EXISTING - Move here)
- `color_themes.dart` (EXISTING - Move here)

No architectural changes needed for these.

## Data Flow Patterns

### Pattern 1: GPS Data Flow (Reactive)

```
Hardware GPS
    ↓ Position updates
GpsService.positionStream
    ↓ Raw Position objects
GpsDataManager.initialize()
    ↓ Process & validate
    ↓ Format display strings
    ↓ Handle staleness
GpsDataManager._dataController.add()
    ↓ Broadcast Stream<ProcessedGpsData>
SpeedometerProvider._gpsSubscription
    ↓ Transform for UI state
    ↓ Update trip stats
SpeedometerProvider.notifyListeners()
    ↓
Consumer<SpeedometerProvider> widgets rebuild
    ↓
Speed Display, Compass, Metrics Panel render
```

**Key characteristics:**
- Pull-based: UI subscribes to state changes
- Single source of truth: GpsDataManager
- Unidirectional: Data flows down, never up
- Reactive: UI rebuilds automatically

### Pattern 2: User Interaction Flow (Command)

```
User taps unit selector button
    ↓
UnitSelector.onTap() callback
    ↓
SpeedometerProvider.toggleUnit()
    ↓
currentUnit = currentUnit.next
    ↓
notifyListeners()
    ↓
Consumer rebuilds
    ↓
SpeedDisplay shows new unit
```

**Key characteristics:**
- Push-based: UI calls provider methods
- Synchronous: Immediate state change
- Provider is command handler

### Pattern 3: Overlay Communication (Push)

```
SpeedometerProvider receives GPS update
    ↓
Check if overlay active
    ↓
Create OverlayMessage.speedUpdate()
    ↓
OverlayService.sendUpdate(message)
    ↓
FlutterOverlayWindow.shareData(json)
    ↓ Platform channel (main isolate → overlay isolate)
Overlay: FlutterOverlayWindow.overlayListener
    ↓
Overlay: setState() with new data
    ↓
Overlay rebuilds
```

**Key challenges:**
- **Separate isolates**: Main app and overlay don't share memory
- **One-way communication**: Main → Overlay only (overlay can't call back reliably)
- **Message staleness**: If overlay is busy, messages can be dropped
- **Status polling**: Need heartbeat to detect overlay closure

**Reliability improvements:**
1. **Structured messages** with typed OverlayMessage class
2. **Status stream** for overlay lifecycle tracking
3. **Graceful failures** - don't crash if overlay message fails
4. **Debounce updates** - send overlay updates at 5Hz max, not every GPS tick

## Architecture Patterns to Follow

### Pattern 1: Provider Placement

```dart
void main() {
  runApp(
    MultiProvider(
      providers: [
        // Services (singletons)
        Provider<GpsDataManager>(
          create: (_) => GpsDataManager.instance,
          dispose: (_, manager) => manager.dispose(),
        ),
        Provider<OverlayService>(
          create: (_) => OverlayService(),
          dispose: (_, service) => service.dispose(),
        ),

        // State providers (ChangeNotifier)
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<SpeedometerProvider>(
          create: (context) => SpeedometerProvider(
            gpsManager: context.read<GpsDataManager>(),
            overlayService: context.read<OverlayService>(),
          ),
        ),
        ChangeNotifierProvider<OverlayProvider>(
          create: (context) => OverlayProvider(
            context.read<OverlayService>(),
          ),
        ),
      ],
      child: const SpeedoApp(),
    ),
  );
}
```

**Principles:**
- Services at top level (app-wide singletons)
- Providers depend on services via constructor injection
- Use `context.read()` in create to avoid rebuild loops

### Pattern 2: Widget Extraction Priority

Extract in this order:

1. **Leaf widgets first** (speed display, compass, unit selector)
   - No dependencies on other widgets
   - Self-contained Consumer patterns
   - Easiest to test

2. **Composite widgets** (metrics panel with multiple displays)
   - Compose leaf widgets
   - Pass callbacks down

3. **Layout widgets** (portrait/landscape containers)
   - Orchestrate composite widgets
   - Handle orientation logic

4. **Screen** (top-level)
   - Final integration point
   - Minimal logic, mostly layout

### Pattern 3: Consumer Optimization

```dart
// ❌ BAD: Entire screen rebuilds on any state change
Consumer<SpeedometerProvider>(
  builder: (context, speedometer, child) {
    return Column(
      children: [
        SpeedDisplay(speed: speedometer.displaySpeed),
        Compass(heading: speedometer.heading),
        MetricsPanel(stats: speedometer.tripStats),
      ],
    );
  },
)

// ✅ GOOD: Each component consumes only what it needs
Column(
  children: [
    // Only rebuilds when speed changes
    Consumer<SpeedometerProvider>(
      builder: (context, speedometer, child) {
        return SpeedDisplay(speed: speedometer.displaySpeed);
      },
    ),
    // Only rebuilds when heading changes
    Consumer<SpeedometerProvider>(
      builder: (context, speedometer, child) {
        return Compass(heading: speedometer.heading);
      },
    ),
    // Only rebuilds when trip stats change
    Consumer<SpeedometerProvider>(
      builder: (context, speedometer, child) {
        return MetricsPanel(stats: speedometer.tripStats);
      },
    ),
  ],
)

// ✅ BEST: Extract to widgets with internal Consumers
Column(
  children: [
    SpeedDisplayWidget(),  // Contains Consumer internally
    CompassWidget(),       // Contains Consumer internally
    MetricsPanelWidget(),  // Contains Consumer internally
  ],
)
```

### Pattern 4: Overlay Communication Reliability

```dart
// ❌ PROBLEM: Push every GPS update to overlay (60+ per second)
void _onGpsDataUpdate(ProcessedGpsData data) {
  displaySpeed = data.displaySpeed;
  notifyListeners();

  // Floods overlay with messages
  _overlayService.sendUpdate(/* ... */);
}

// ✅ SOLUTION: Debounce overlay updates
Timer? _overlayUpdateTimer;

void _onGpsDataUpdate(ProcessedGpsData data) {
  displaySpeed = data.displaySpeed;
  notifyListeners(); // UI updates at full rate

  // Debounce overlay updates to 5 Hz
  _overlayUpdateTimer?.cancel();
  _overlayUpdateTimer = Timer(
    const Duration(milliseconds: 200),
    () => _sendOverlayUpdate(),
  );
}

void _sendOverlayUpdate() {
  if (!_overlayService.isActive) return;

  _overlayService.sendUpdate(
    OverlayMessage.speedUpdate(/* ... */),
  );
}
```

**Why debounce?**
- Overlay runs in separate isolate with platform channel overhead
- Message passing has serialization cost
- Overlay only updates at screen refresh rate (60 FPS = 16ms)
- 200ms = 5 Hz is plenty for human perception

## Anti-Patterns to Avoid

### Anti-Pattern 1: Business Logic in Widgets

```dart
// ❌ BAD: Widget directly subscribes to GPS stream
class SpeedDisplay extends StatefulWidget {
  @override
  State<SpeedDisplay> createState() => _SpeedDisplayState();
}

class _SpeedDisplayState extends State<SpeedDisplay> {
  late StreamSubscription _subscription;
  String _speed = '--';

  @override
  void initState() {
    super.initState();
    _subscription = GpsDataManager.instance.dataStream.listen((data) {
      setState(() { _speed = data.displaySpeed; });
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_speed);
  }
}
```

**Problems:**
- Widget has GPS knowledge (breaks separation of concerns)
- setState causes widget-level rebuilds (not optimized)
- Subscription management scattered across widgets
- Hard to test (requires mocking GPS stream)
- Duplicate subscriptions if multiple speed displays

```dart
// ✅ GOOD: Widget consumes provider state
class SpeedDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SpeedometerProvider>(
      builder: (context, speedometer, child) {
        return Text(speedometer.displaySpeed);
      },
    );
  }
}
```

### Anti-Pattern 2: Direct Overlay Communication from Widgets

```dart
// ❌ BAD: Widget pushes to overlay
class Compass extends StatelessWidget {
  final double heading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Widget knows about overlay internals
        FlutterOverlayWindow.shareData({
          'action': 'updateHeading',
          'heading': heading,
        });
      },
      child: Icon(Icons.navigation),
    );
  }
}
```

**Problems:**
- Widget has overlay platform channel knowledge
- No type safety (typo in 'updateHeading')
- No error handling
- Can't track overlay state

```dart
// ✅ GOOD: Widget calls provider, provider handles overlay
class Compass extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SpeedometerProvider>(
      builder: (context, speedometer, child) {
        return GestureDetector(
          onTap: () => speedometer.toggleOverlay(),
          child: Transform.rotate(
            angle: speedometer.heading * pi / 180,
            child: Icon(Icons.navigation),
          ),
        );
      },
    );
  }
}

// Provider handles overlay coordination
class SpeedometerProvider extends ChangeNotifier {
  void toggleOverlay() {
    if (_overlayService.isActive) {
      _overlayService.close();
    } else {
      _overlayService.show();
    }
  }
}
```

### Anti-Pattern 3: Multiple Sources of Truth

```dart
// ❌ BAD: Both provider and widget have speed state
class SpeedometerProvider extends ChangeNotifier {
  String displaySpeed = '--';

  void updateSpeed(String speed) {
    displaySpeed = speed;
    notifyListeners();
  }
}

class SpeedDisplay extends StatefulWidget {
  @override
  State<SpeedDisplay> createState() => _SpeedDisplayState();
}

class _SpeedDisplayState extends State<SpeedDisplay> {
  String _localSpeed = '--'; // Duplicate state!

  @override
  Widget build(BuildContext context) {
    return Consumer<SpeedometerProvider>(
      builder: (context, speedometer, child) {
        // Which is correct? Provider or widget state?
        return Text(_localSpeed ?? speedometer.displaySpeed);
      },
    );
  }
}
```

**Problems:**
- State synchronization issues
- Unclear which is authoritative
- Bugs from stale widget state

```dart
// ✅ GOOD: Provider is single source of truth
class SpeedometerProvider extends ChangeNotifier {
  String displaySpeed = '--';
}

class SpeedDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SpeedometerProvider>(
      builder: (context, speedometer, child) {
        return Text(speedometer.displaySpeed);
      },
    );
  }
}
```

### Anti-Pattern 4: Polling Instead of Reactive Streams

```dart
// ❌ BAD: Timer-based polling
class SpeedometerProvider extends ChangeNotifier {
  Timer? _pollTimer;

  void startPolling() {
    _pollTimer = Timer.periodic(Duration(seconds: 1), (_) {
      final data = GpsDataManager.instance.currentData;
      displaySpeed = data.displaySpeed;
      notifyListeners();
    });
  }
}
```

**Problems:**
- Unnecessary CPU usage
- Delayed updates (up to 1 second lag)
- Timer doesn't align with GPS update rate

```dart
// ✅ GOOD: Subscribe to GPS stream
class SpeedometerProvider extends ChangeNotifier {
  StreamSubscription<ProcessedGpsData>? _subscription;

  SpeedometerProvider() {
    _subscription = GpsDataManager.instance.dataStream.listen((data) {
      displaySpeed = data.displaySpeed;
      notifyListeners();
    });
  }
}
```

## Overlay Communication Architecture

### Challenge: Separate Isolates

FlutterOverlayWindow creates a **separate Flutter engine** in a different isolate:

```
┌─────────────────────────────────────┐
│        Main App (Isolate 1)         │
│  - Full Flutter app                 │
│  - GPS streams                      │
│  - Provider state                   │
│  - UI widgets                       │
└──────────────┬──────────────────────┘
               │ Platform Channel
               │ (JSON messages only)
┌──────────────▼──────────────────────┐
│     Overlay Window (Isolate 2)      │
│  - Separate Flutter engine          │
│  - No shared memory                 │
│  - Receives JSON via platform       │
│  - Must maintain own state          │
└─────────────────────────────────────┘
```

**Implications:**
- **No shared state**: Overlay can't access main app providers
- **One-way communication**: Main → Overlay only (reverse requires platform implementation)
- **Message serialization**: All data must be JSON-serializable
- **Lifecycle independence**: Overlay can survive main app backgrounding

### Recommended Pattern: Dedicated OverlayService

```dart
// Service handles all overlay platform communication
class OverlayService {
  // Lifecycle management
  Future<void> show({int width, int height});
  Future<void> close();

  // Status tracking
  Stream<bool> get statusStream;
  bool get isActive;

  // Message sending
  void sendUpdate(OverlayMessage message);

  // Periodic status check (overlay can close externally)
  Timer? _heartbeatTimer;
}

// Provider uses service, never direct platform calls
class SpeedometerProvider extends ChangeNotifier {
  final OverlayService _overlayService;

  void _onGpsUpdate(ProcessedGpsData data) {
    // Update main app state
    displaySpeed = data.displaySpeed;
    notifyListeners();

    // Push to overlay if active
    if (_overlayService.isActive) {
      _overlayService.sendUpdate(
        OverlayMessage.speedUpdate(/* ... */),
      );
    }
  }
}
```

### Message Schema Pattern

```dart
// Typed messages prevent bugs
class OverlayMessage {
  final String action;
  final Map<String, dynamic> payload;

  // Factory constructors for each message type
  factory OverlayMessage.speedUpdate({...}) { /* ... */ }
  factory OverlayMessage.themeUpdate({...}) { /* ... */ }
  factory OverlayMessage.close() { /* ... */ }

  Map<String, dynamic> toJson() => {'action': action, ...payload};
}

// Overlay receives and parses
FlutterOverlayWindow.overlayListener.listen((data) {
  if (data is Map && data['action'] == 'speedUpdate') {
    setState(() {
      _speedText = data['speedText'];
      _heading = data['heading'];
      // ...
    });
  }
});
```

### Staleness Mitigation Strategies

**Problem:** Overlay updates can be missed if:
- Overlay is busy rendering
- Message queue fills up
- Platform channel has backpressure

**Solutions:**

1. **Debounce updates** (5 Hz instead of GPS rate)
2. **Include timestamp** in messages to detect stale data
3. **Send full state** every time (not deltas)
4. **Heartbeat sync** every 5 seconds with full state refresh

```dart
class OverlayMessage {
  factory OverlayMessage.speedUpdate({
    required String speedText,
    required double heading,
    // ...
    DateTime? timestamp, // Detect staleness
  }) {
    return OverlayMessage(
      action: 'updateDisplay',
      payload: {
        'speedText': speedText,
        'heading': heading,
        'timestamp': (timestamp ?? DateTime.now()).millisecondsSinceEpoch,
      },
    );
  }
}

// Overlay checks staleness
FlutterOverlayWindow.overlayListener.listen((data) {
  if (data is Map && data['action'] == 'updateDisplay') {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
    final age = DateTime.now().difference(timestamp);

    if (age < Duration(seconds: 5)) {
      setState(() { /* apply update */ });
    } else {
      print('[Overlay] Ignoring stale update: ${age.inSeconds}s old');
    }
  }
});
```

## Build Order Recommendations

### Phase 1: Foundation (Extract Models & Config)

**Goal:** Establish data structures and configuration

```
1. Create directory structure
   lib/
   ├── models/
   ├── config/
   ├── services/
   ├── providers/
   ├── widgets/
   └── screens/

2. Move existing files
   - speed_units.dart → config/
   - color_themes.dart → config/

3. Extract ProcessedGpsData → models/processed_gps_data.dart

4. Create new models
   - models/overlay_message.dart
   - models/trip_stats.dart
   - models/speedometer_settings.dart
```

**Validation:** Code compiles, imports updated

### Phase 2: Service Layer (Extract Overlay Logic)

**Goal:** Isolate platform channel communication

```
1. Create services/overlay_service.dart
   - Move overlay lifecycle logic from _SpeedometerScreenState
   - Extract FlutterOverlayWindow calls
   - Add status stream

2. Keep existing services
   - gps_data_manager.dart (no changes)
   - gps_service.dart (no changes)
```

**Validation:** Overlay can show/close via OverlayService

### Phase 3: Provider Setup (Create State Management)

**Goal:** Replace setState with Provider pattern

```
1. Add provider dependency
   pubspec.yaml:
     provider: ^6.1.0

2. Create providers/speedometer_provider.dart
   - Migrate GPS subscription from _SpeedometerScreenState
   - Add trip stats logic
   - Add overlay coordination

3. Create providers/theme_provider.dart
   - Migrate theme index state

4. Create providers/overlay_provider.dart
   - Wrap OverlayService with ChangeNotifier

5. Update main.dart with MultiProvider
   - Wrap SpeedoApp with providers
```

**Validation:** State changes trigger rebuilds

### Phase 4: Widget Extraction (Decompose Screen)

**Goal:** Break SpeedometerScreen into reusable widgets

**Order (leaf to composite):**

```
1. Extract leaf widgets (no dependencies)
   - widgets/speed_display.dart (speed + unit text)
   - widgets/heading_compass.dart (compass icon + heading)
   - widgets/unit_selector.dart (quick unit buttons)

2. Extract composite widgets
   - widgets/metrics_panel.dart (coordinates, distance, time)

3. Extract layout widgets
   - widgets/portrait_layout.dart (portrait orientation)
   - widgets/landscape_layout.dart (landscape orientation)

4. Simplify screens/speedometer_screen.dart
   - Remove setState (now StatelessWidget)
   - Compose extracted widgets
```

**Validation:** Screen renders identically, state updates work

### Phase 5: Overlay Refactor (Apply Architecture)

**Goal:** Apply same architecture to overlay window

```
1. Move overlay to screens/overlay_speedometer.dart

2. Create overlay-specific widgets
   - widgets/overlay/overlay_speed_display.dart
   - widgets/overlay/overlay_compass.dart

3. Update overlay message handling
   - Use OverlayMessage.toJson() / fromJson()
   - Add timestamp staleness checks
```

**Validation:** Overlay receives updates reliably

### Phase 6: Cleanup & Optimization

**Goal:** Remove dead code, optimize performance

```
1. Remove old setState code
2. Remove background heartbeat timers (replaced by stream subscriptions)
3. Add Consumer optimization (place deep in widget tree)
4. Add debouncing to overlay updates
5. Profile rebuild performance
```

**Validation:** App performs as well or better than before

## Dependency Management

### Wiring Pattern

```dart
// main.dart
void main() {
  runApp(
    MultiProvider(
      providers: [
        // Step 1: Provide services (no dependencies)
        Provider<GpsDataManager>(
          create: (_) => GpsDataManager.instance,
        ),
        Provider<OverlayService>(
          create: (_) => OverlayService(),
        ),

        // Step 2: Provide state (depend on services)
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<SpeedometerProvider>(
          create: (context) => SpeedometerProvider(
            gpsManager: context.read<GpsDataManager>(),
            overlayService: context.read<OverlayService>(),
          ),
        ),
        ChangeNotifierProvider<OverlayProvider>(
          create: (context) => OverlayProvider(
            context.read<OverlayService>(),
          ),
        ),
      ],
      child: const SpeedoApp(),
    ),
  );
}
```

**Rules:**
- Use `context.read()` in create (not watch/listen)
- Services before providers (dependency order)
- Dispose services in provider disposal

## Scalability Considerations

| Concern | Current (< 100 users) | At 10K users | At 1M users |
|---------|----------------------|--------------|-------------|
| **GPS data rate** | Geolocator default (1-5 Hz) | Same, already optimized | Same, hardware-limited |
| **Overlay updates** | Debounce to 5 Hz | Same | Same |
| **State size** | Small (< 1KB) | Small | Small |
| **Provider rebuilds** | Consumer optimization | Add Selector for granular rebuilds | Same |
| **Persistence** | SharedPreferences | Same | Consider encrypted storage |
| **Analytics** | None | Add Firebase Analytics | Same + custom backend |
| **Error reporting** | Print statements | Add Sentry/Crashlytics | Same |

**Architectural benefit:** Provider pattern scales well. No fundamental changes needed for 1M users since app is local-first with no backend.

## Testing Strategy

### Unit Tests (Models & Services)

```dart
// Test models (pure Dart, no Flutter)
test('ProcessedGpsData.copyWith updates fields', () {
  final data = ProcessedGpsData(/* ... */);
  final updated = data.copyWith(speed: 10.0);
  expect(updated.speed, 10.0);
});

// Test services with mocks
test('OverlayService emits status on show', () async {
  final service = OverlayService();
  expectLater(service.statusStream, emits(true));
  await service.show(width: 100, height: 100);
});
```

### Provider Tests (ChangeNotifier Logic)

```dart
testWidgets('SpeedometerProvider notifies on GPS update', (tester) async {
  final mockGpsManager = MockGpsDataManager();
  final provider = SpeedometerProvider(
    gpsManager: mockGpsManager,
    overlayService: MockOverlayService(),
  );

  bool notified = false;
  provider.addListener(() => notified = true);

  // Simulate GPS update
  mockGpsManager.simulateUpdate(ProcessedGpsData(/* ... */));

  expect(notified, true);
  expect(provider.displaySpeed, '10.0');
});
```

### Widget Tests (UI Components)

```dart
testWidgets('SpeedDisplay shows speed from provider', (tester) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<SpeedometerProvider>(
      create: (_) => MockSpeedometerProvider(displaySpeed: '25.5'),
      child: MaterialApp(home: SpeedDisplay()),
    ),
  );

  expect(find.text('25.5'), findsOneWidget);
});
```

## Sources

### Flutter Official Documentation (HIGH Confidence)
- [Guide to app architecture](https://docs.flutter.dev/app-architecture/guide) - MVVM pattern, layer structure
- [Common architecture concepts](https://docs.flutter.dev/app-architecture/concepts) - Separation of concerns, SSOT, UDF
- [Simple app state management](https://docs.flutter.dev/data-and-backend/state-mgmt/simple) - Provider pattern, ChangeNotifier

### Provider Pattern (HIGH Confidence)
- [provider package](https://pub.dev/packages/provider) - Official Provider package documentation
- [Flutter Provider & ChangeNotifier Architecture Guide](https://jgrandchavin.medium.com/flutter-provider-changenotifier-architecture-guide-47ad05aa608e) - Practical implementation patterns
- [State Management for Beginners: Getting Started with Provider in Flutter](https://vibe-studio.ai/insights/state-management-for-beginners-getting-started-with-provider-in-flutter) - Best practices for 2026

### Modular Architecture (HIGH Confidence)
- [Flutter Modular Architecture: How to Structure a Scalable App](https://medium.com/@punithsuppar7795/flutter-modular-architecture-how-to-structure-a-scalable-app-4c3b31a7514c) - Folder structure patterns
- [Scaling Flutter Apps with Feature-First Folder Structures](https://dev.to/alaminkarno/scaling-flutter-apps-with-feature-first-folder-structures-547f) - Feature vs layer organization
- [Flutter Project Structure: Feature-first or Layer-first?](https://codewithandrea.com/articles/flutter-project-structure/) - Architecture decision guidance

### GPS & Location Tracking (MEDIUM Confidence)
- [Advanced Location Tracking in Flutter: The Complete 2026 Guide](https://medium.com/@ali.mohamed.hgr/advanced-location-tracking-in-flutter-the-complete-2026-guide-cce138f2d558) - GPS architecture patterns
- [geolocator package](https://pub.dev/packages/geolocator) - Official Geolocator documentation
- [Best Flutter State Management Libraries 2026](https://foresightmobile.com/blog/best-flutter-state-management) - State management comparison

### Overlay Communication (MEDIUM Confidence - Known Issues)
- [flutter_overlay_window package](https://pub.dev/packages/flutter_overlay_window) - Official overlay package documentation
- [Flutter overlay window data sync issues](https://github.com/X-SLAYER/flutter_overlay_window/issues/115) - Known reliability problems
- [Broadcast Streams Cache Last Result issue](https://github.com/dart-lang/core/issues/329) - Stream limitations

### Widget Extraction & Refactoring (HIGH Confidence)
- [Refactoring in Flutter](https://salman-nurhoiriza.medium.com/refactoring-in-flutter-9f16edd5cf82) - Extract method/class patterns
- [Creating Reusable Custom Widgets in Flutter](https://www.kodeco.com/10126984-creating-reusable-custom-widgets-in-flutter) - Widget composition patterns
- [Consumer class documentation](https://pub.dev/documentation/provider/latest/provider/Consumer-class.html) - Consumer optimization patterns

---

**Architecture Confidence:** HIGH
**Overlay Communication Confidence:** MEDIUM (known reliability issues with separate isolates)
**Build Order Confidence:** HIGH (validated dependency chain)
