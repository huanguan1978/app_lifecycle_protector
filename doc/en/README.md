# App Lifecycle Protector

`app_lifecycle_protector` is an **enhanced lifecycle management and business logic orchestrator** for Flutter.

While it provides out-of-the-box privacy masking and security locking, its core value lies in its **event-driven architecture**, allowing you to bind complex business logic (not just security) to the application's lifecycle states in a declarative way.

## 🌟 Core Value

In complex applications, logic often ends up scattered across various widget lifecycle callbacks, leading to fragmented and hard-to-maintain code. This package solves this pain point through the following mechanisms:

### 1. Enhanced `onPeriodic` Polling
This is the soul of the toolkit. Unlike a standard `Timer`, the `onPeriodic` task **only triggers when the app is visible**:
*   **Resource Friendly**: When the app enters the background or is hidden, polling automatically silences, stopping unnecessary CPU and network consumption.
*   **Smart Scenarios**: Perfect for "keep-alive heartbeats only when used," "idle timeout auto-lock," or "periodic sensitive cache clearing."

### 2. Event-Driven Logic Decoupling
By extending `AppLifecycleEvent`, you can completely decouple logic from the UI tree:
*   **Clean Architecture**: No more repeating `didChangeAppLifecycleState` listeners across multiple pages.
*   **Comprehensive Hooks**: Beyond `onResume/onPause`, it supports fine-grained control like `onShow/onHide`, `onRestart`, and `onExitRequested`.

---

## 🛠️ Four Core Use Cases

| Use Case | Description |
| :--- | :--- |
| **Business Orchestration** | Start **front-end scheduled tasks (e.g., API calls & result distribution)**, network connectivity detection, and automated data management (cleaning, refreshing, pulling) only when visible, achieving true "run on demand." |
| **Idle Timeout Protection** | Automatically trigger security locks after long periods of user inactivity using the `onPeriodic` and `isAlive()` mechanism. |
| **Privacy Masking** | Automatically overlay a privacy layer in the multitasking switcher to prevent sensitive data leakage via system snapshots. |
| **Launch Authorization** | Ensure users must pass authentication (biometrics or password) before accessing sensitive data on app startup. |

---

## 🚀 Quick Start

### Step 1: Define Your Logic Handler
Extend `AppLifecycleEvent` and override the methods you need. You can mix security logic with general business logic:

```dart
class MyLogicHandler extends AppLifecycleEvent {
  final ScreenSecure screenSecure;

  MyLogicHandler(this.screenSecure);

  @override
  void onPeriodic() {
    // 【Enhanced Polling】Runs every 10s ONLY when the app is visible
    // Example: Check if the user has been idle for more than 5 minutes
    if (!AppLifecycleScheduler.instance.isAlive()) {
      screenSecure.lock(); 
    }
    
    // Also perform non-security logic, e.g., maintaining a heartbeat
    print("App visible, performing business inspection...");
  }

  @override
  void onPause() {
    // App backgrounded, show privacy mask immediately
    screenSecure.mask();
  }

  @override
  void onResume() {
    // App foregrounded, remove mask
    screenSecure.unmask();
  }
}
```

### Step 2: Initialize in the Root Widget
**Best Practice**: Configure the scheduler in the `initState` of your root widget (e.g., `MyApp`). This ensures the scheduler is synchronized with the app lifecycle and ready before `MaterialApp` builds.

```dart
class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    
    // 1. Initialize the orchestrator (WidgetsBinding is ready here)
    AppLifecycleScheduler.initialize(
      interval: const Duration(seconds: 10),
      event: MyLogicHandler(screenSecure),
    );
    
    // 2. Configure parameters (e.g., idle timeout duration)
    AppLifecycleScheduler.instance.aliveDuration = const Duration(minutes: 5);
    
    // 3. Optional: If you need an immediate lock on cold start
    screenSecure.lock();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
       // ...
    );
  }
}
```

### Step 3: Integrate UI Protector

#### Option A: Full App Protection (Recommended)
To protect all pages in your app, wrap the `Navigator` within `MaterialApp.builder`.

```dart
MaterialApp(
  builder: (context, child) {
    return ScreenProtector(
      screenSecure: screenSecure,
      lockWidget: MyLockScreen(),
      child: child!, // Protects the entire navigation stack
    );
  },
  home: MyHomePage(),
)
```

#### Option B: Local Protection (Single Page)
Wrap only a specific page (does not protect subsequent pushed routes).

```dart
ScreenProtector(
  screenSecure: screenSecure,
  lockWidget: MyLockScreen(),
  child: MyHomePage(),
)
```

---

## 🔧 Core API Reference

| Class/Method | Description |
| :--- | :--- |
| `AppLifecycleScheduler` | Global singleton managing periodic polling and lifecycle distribution. |
| `AppLifecycleEvent` | Base class for event handlers, including `onPeriodic` and all system-level hooks. |
| `ScreenSecure` | State manager controlling `isMasked` (privacy mask) and `isLocked` (security lock). |
| `ScreenProtector` | UI component that handles overlay logic using a `Stack`. |
| `updateAliveStatus()` | Updates the last active timestamp. Recommended to call in a global `Listener`'s `onPointerDown`. |

---

## 🤝 Third-Party Integration Tips

For maximum security, we recommend:
1.  **Screen Capture Protection**: Use [no_screenshot](https://pub.dev/packages/no_screenshot) to disable screenshots and recordings.
2.  **Local Storage**: Use `shared_preferences` to persist user lock configurations.

---

## 💡 Implementation Guide
Want to dive deeper into the design logic and best practices? Read our [Implementation Guide (EXAMPLE.md)](EXAMPLE.md).

---

### Support the Project 💖

If you find this package useful, please consider showing your support:

- ⭐ **Star the Repo**: Give it a **Star** on GitHub or a **Like** on pub.dev.
- ☕ **Support the Developer (Global)**: Donate via [GitHub Sponsors](https://github.com/sponsors/huanguan1978) or [Buy Me a Coffee](https://buymeacoffee.com/huanguan1978).
- 🐼 **Support via Ifdian (Mainland China)**: Support via [Ifdian](https://ifdian.net/a/huangaun1978).

*Thank you for your support!*

## 📄 License
MIT License.
