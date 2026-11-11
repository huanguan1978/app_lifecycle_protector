# Screen Protection: `ScreenSecure` and `ScreenProtector`

This guide explains how to use `ScreenSecure` to manage masking and lock
state, and `ScreenProtector` to display those states in a Flutter UI. The
example also shows how to combine lifecycle callbacks, user-activity tracking,
and an authentication screen. Authentication itself is supplied by your app.

## How it works

1. **Shared state:** Create a `ScreenSecure` instance to hold the mask and lock
   state.
2. **Lifecycle handling:** Extend `AppLifecycleEvent` to check for idle
   timeouts in `onPeriodic()` and show or hide the privacy mask in
   `onPause()` and `onResume()`.
3. **Activity tracking:** Use `Listener` for pointer events and
   `HardwareKeyboard` for hardware-key events to refresh the last-activity
   timestamp.
4. **UI overlay:** Wrap the pages you want to protect in `ScreenProtector`.
   It displays the appropriate overlay when the state changes.

## Complete example

The following example can be adapted for an app that protects a single page.

### 1. Define a lifecycle event handler

This handler checks for idle timeouts and applies a privacy mask as the app
pauses or resumes.

```dart
import 'package:app_lifecycle_protector/app_lifecycle_protector.dart';

class MySecurityHandler extends AppLifecycleEvent {
  MySecurityHandler(this.screenSecure);

  final ScreenSecure screenSecure;

  @override
  void initialize() {
    super.initialize();
    AppLifecycleScheduler.instance.updateAliveStatus();
  }

  @override
  void onPeriodic() {
    // The operating system may suspend Dart execution while the app is in the background.
    final scheduler = AppLifecycleScheduler.instance;

    if (!scheduler.isAlive()) {
      screenSecure.lock();
    }

    if (isInForeground) {
      // Run lightweight foreground-only work here.
    }
  }

  @override
  void onPause() {
    screenSecure.mask();
  }

  @override
  void onResume() {
    screenSecure.unmask();
  }
}
```

### 2. Provide an authentication validator

This mock validator simulates a biometric check. In a real app, connect the
validator to your authentication flow, for example with
[`local_auth`](https://pub.dev/packages/local_auth).

```dart
class MockBiometricValidator implements BiometricValidator {
  @override
  Future<bool> canAuthenticate() async => true;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return true;
  }
}
```

### 3. Compose the app and protect a page

In this local-protection pattern, only widgets below `ScreenProtector` are
covered. To protect every route, see the global-protection pattern below.

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_lifecycle_protector/app_lifecycle_protector.dart';

final ScreenSecure screenSecure = ScreenSecure();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    AppLifecycleScheduler.initialize(
      interval: const Duration(seconds: 3),
      event: MySecurityHandler(screenSecure),
    );
    AppLifecycleScheduler.instance.aliveDuration =
        const Duration(minutes: 5);

    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  bool _handleKeyEvent(KeyEvent event) {
    AppLifecycleScheduler.instance.updateAliveStatus();
    return false;
  }

  void _onUnlocked() {
    screenSecure.unlock();
    // Start a fresh idle period after the user unlocks.
    AppLifecycleScheduler.instance.updateAliveStatus();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    AppLifecycleScheduler.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) =>
          AppLifecycleScheduler.instance.updateAliveStatus(),
      child: MaterialApp(
        title: 'Security App',
        home: Builder(
          builder: (context) {
            final lockWidget = BiometricLockScreen(
              validator: MockBiometricValidator(),
              onUnlocked: _onUnlocked,
              fallback: PassphraseLockScreen(
                onValidate: (password, _) =>
                    password == '123456' ? null : 'Incorrect passphrase',
                onUnlocked: _onUnlocked,
              ),
            );

            return ScreenProtector(
              screenSecure: screenSecure,
              lockWidget: lockWidget,
              // maskWidget: const MyCustomMask(),
              child: const MyHomePage(),
            );
          },
        ),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Private data')),
      body: const Center(
        child: Text('Sensitive content appears here.'),
      ),
    );
  }
}
```

## Practical tips

### Track user activity accurately

To avoid locking the app while someone is actively using it, update the
activity timestamp for the input types your app supports:

- **Touch, mouse, and other pointer input:** A root-level `Listener` can
  observe pointer-down events.
- **Hardware keyboard:** Register a handler with
  `HardwareKeyboard.instance.addHandler` and remove it when the owning widget
  is disposed.
- **Software keyboard:** Soft-keyboard input is not reported as pointer input.
  For text-heavy screens, refresh activity in `TextField.onChanged`:

  ```dart
  TextField(
    onChanged: (_) =>
        AppLifecycleScheduler.instance.updateAliveStatus(),
  )
  ```

### Lock the app manually

For example, call `lock()` from a logout or “lock now” action:

```dart
screenSecure.lock();
```

### Customize the overlays

`ScreenProtector` accepts `maskWidget` and `lockWidget` parameters. If omitted,
it displays built-in default overlays: a dark privacy mask and a basic
“App Locked” screen.

`ScreenProtector` provides Flutter-level masking and lock-screen UI. It does
not authenticate users or provide operating-system screenshot or recording
protection. Add your own authentication flow and platform-specific protections
where required.

### Protect the entire navigation stack

To cover every route, put `ScreenProtector` in `MaterialApp.builder`. Its child
is the navigator, so the overlay sits above the app's routes:

```dart
MaterialApp(
  builder: (context, child) {
    return ScreenProtector(
      screenSecure: screenSecure,
      lockWidget: MyLockWidget(),
      child: child ?? const SizedBox.shrink(),
    );
  },
  home: const MyHomePage(),
)
```

For real biometric authentication, consider
[`local_auth`](https://pub.dev/packages/local_auth). For operating-system
screenshot controls, use an appropriate platform plugin, such as
[`no_screenshot`](https://pub.dev/packages/no_screenshot); this complements,
but is separate from, the Flutter overlay.
