# App Lifecycle Protector Example

This example demonstrates how to integrate `app_lifecycle_protector` to build a high-security application featuring **Full Lifecycle Monitoring**, **Privacy Masking**, and **Idle Timeout Locking**.

## 💡 Core Logic

1.  **Global State**: Use `ScreenSecure` to drive UI masking and locking states.
2.  **Lifecycle Logic**: Extend `AppLifecycleEvent` to inspect idle state in `onPeriodic` and toggle the mask in `onPause`/`onResume`.
3.  **Interaction Tracking**: Combine `Listener` (Pointer events) and `HardwareKeyboard` (Key events) to track user activity and refresh the "alive" status.
4.  **UI Overlay**: Wrap business pages with `ScreenProtector` to automatically handle security layers.

---

## 🚀 Complete Implementation

You can copy and adapt the following code into your project.

### 1. Define the Security Handler
This acts as the "Security Brain" of your app.

```dart
import 'package:app_lifecycle_protector/app_lifecycle_protector.dart';

class MySecurityHandler extends AppLifecycleEvent {
  final ScreenSecure screenSecure;

  MySecurityHandler(this.screenSecure);

  @override
  void onPeriodic() {
    // [Enhanced Inspection] Triggered by the scheduler (default every 10s)
    final scheduler = AppLifecycleScheduler.instance;
    
    // Auto-lock if the user is idle for more than the predefined duration
    if (!scheduler.isAlive()) {
      screenSecure.lock(); 
    }
  }

  @override
  void onPause() {
    // Show privacy mask when entering Task Manager
    screenSecure.mask();
  }

  @override
  void onResume() {
    // Hide mask when returning to foreground
    screenSecure.unmask();
  }
}
```

### 2. Mock Biometric Validator
In a real project, implement this using the `local_auth` package.

```dart
class MockBiometricValidator implements BiometricValidator {
  @override
  Future<bool> canAuthenticate() async => true; 

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    // Simulate authentication process
    await Future.delayed(const Duration(seconds: 1));
    return true; 
  }
}
```

### 3. App Entry & UI Composition (Local Application Pattern)
The following code demonstrates how to protect the **Home Page**. Note that in this pattern, the protection only applies to the widget tree under `ScreenProtector`.

```dart
// ... imports and boilerplate ...
      child: MaterialApp(
        title: 'Security App',
        home: Builder(
          builder: (context) {
            // ... lock screen setup ...
            return ScreenProtector(
              screenSecure: screenSecure,
              lockWidget: lockWidget,
              child: const MyHomePage(),
            );
          },
        ),
      ),
// ...
```

---

## 🌍 Global Application Pattern (Recommended)

To ensure **all pages** (including those opened via `Navigator.push`) are protected, use the `MaterialApp.builder` property. This wraps the entire navigation stack under the `ScreenProtector`.

```dart
MaterialApp(
  // Use builder to provide global protection
  builder: (context, child) {
    return ScreenProtector(
      screenSecure: screenSecure,
      lockWidget: MyGlobalLockWidget(),
      child: child!, // child represents the Navigator
    );
  },
  home: const MyHomePage(),
)
```

> **Pro Tip**: For a complete, production-ready implementation of the Global Pattern, please refer to the [example/lib/main.dart](../../example/lib/main.dart) file in the repository.

---

## 📌 Key Takeaways

### Precise Interaction Tracking
To prevent accidental lockouts during active use (e.g., reading or typing), we recommend a multi-layered approach:
*   **Touch/Mouse**: Handled by the `Listener` in the example.
*   **Hardware Keyboard**: Handled by `HardwareKeyboard.addHandler`.
*   **Software Keyboard (Crucial)**: Soft keyboard taps are not pointer events. For **editor-heavy apps**, manually refresh the status in `TextField.onChanged`:
  ```dart
  TextField(
    onChanged: (_) => AppLifecycleScheduler.instance.updateAliveStatus(),
  )
  ```

### Manual Locking
You can trigger an immediate lock (e.g., for a "Security Logout" button) using:
```dart
screenSecure.lock();
```

### Customization
`ScreenProtector` provides `maskWidget` and `lockWidget` slots. If omitted, default professional styles (Privacy Icon / "App Locked" text) are used.
