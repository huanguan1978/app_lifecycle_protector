# App Lifecycle Protector

`app_lifecycle_protector` is an **enhanced lifecycle management and business logic orchestrator** for Flutter.

While it provides out-of-the-box privacy masking and security locking, its core value lies in its **event-driven architecture**, allowing you to bind complex business logic (not just security) to the application's lifecycle states in a declarative way.

## 🌟 Core Value

In complex applications, logic often ends up scattered across various widget lifecycle callbacks, leading to fragmented and hard-to-maintain code. This package solves this pain point through the following mechanisms:

### 1. Full-Lifecycle `onPeriodic` Scheduling with State Awareness
This is the core feature of the toolkit. Unlike a standard `Timer`, the `onPeriodic` task **runs continuously across the entire active application lifecycle** (until suspended by the OS or terminated):
*   **Foreground/Background State Awareness**: Built-in read-only getters `isInForeground` and `isInBackground` empower developers to easily distinguish between tasks that should only execute when visible and tasks that should continue in the background.
*   **Full-Spectrum Protection**: Even when the app is backgrounded or minimized, idle timeout checks remain active. When an idle timeout occurs, it locks proactively in the background, eliminating any visual leakage when resuming; automatic recovery is built-in upon returning to the foreground.

### 2. Event-Driven Logic Decoupling
By extending `AppLifecycleEvent`, you can completely decouple logic from the UI tree:
*   **Clean Architecture**: No more repeating `didChangeAppLifecycleState` listeners across multiple pages.
*   **Comprehensive Hooks**: Beyond `onResume/onPause`, it supports fine-grained control like `onShow/onHide`, `onRestart`, and `onExitRequested`.
*   **Graceful Exit Handling**: Override `onExitRequested()` to intercept app shutdown and perform cleanup before exit, such as closing database connections, saving app settings, or persisting cache.

---

## 🛠️ Four Core Use Cases

| Use Case | Description |
| :--- | :--- |
| **Business Orchestration** | Leverage `isInForeground` and `isInBackground` to orchestrate high-frequency tasks (API polling, UI refresh) only in foreground and lightweight tasks (syncing, cache maintenance) in background for true "run on demand." |
| **Idle Timeout Protection** | Automatically trigger security locks after long periods of user inactivity using `onPeriodic` and `isAlive()`, with background idle timeouts proactively locking behind the scenes. |
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
    // 1. [Full-Lifecycle Security Check] Runs in foreground & background
    // Example: Proactively lock in background if user has been idle for > 5 mins
    if (!AppLifecycleScheduler.instance.isAlive()) {
      screenSecure.lock(); 
    }
    
    // 2. [On-Demand Foreground Business] Runs ONLY when visible to save battery/bandwidth
    if (isInForeground) {
      print("App is in foreground, refreshing UI data or keeping heartbeat...");
    }

    // 3. [Optional Background Task] Runs when hidden/backgrounded
    if (isInBackground) {
      // E.g., track background elapsed duration or persist unsaved drafts
    }
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

| Class/Method/Property | Description |
| :--- | :--- |
| `AppLifecycleScheduler` | Global singleton managing full-lifecycle periodic scheduling and lifecycle distribution. |
| `AppLifecycleEvent` | Base class for event handlers, including `onPeriodic`, state awareness, and all system hooks. |
| `isInForeground` / `isInBackground` | Read-only getters on `AppLifecycleEvent` and `AppLifecycleScheduler` indicating whether the app is in the foreground (visible) or background (hidden). |
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
- 🐼 **Support via Ifdian (Mainland China)**: Support via [Ifdian](https://ifdian.net/a/huanguan1978).

*Thank you for your support!*

## 📄 License
MIT License.
