---
name: app-lifecycle-protector-screen-protection
description: "Use when adding Flutter privacy masking, lock overlays, idle locking, or lifecycle-aware screen protection with app_lifecycle_protector, including ScreenSecure and ScreenProtector integration."
---

# App Lifecycle Protector: Screen Protection

Use this skill for Flutter-level privacy masks and lock overlays. Start with
the smallest working setup, then add configuration or lifecycle integration
only when the app needs it.

## 1. Start with the ready-to-use overlay

Create one `ScreenSecure` state object and wrap the content to protect with
`ScreenProtector`. Use its mask/lock helpers to change the overlay:

```dart
import 'package:flutter/material.dart';
import 'package:app_lifecycle_protector/app_lifecycle_protector.dart';

class ProtectedPage extends StatefulWidget {
  const ProtectedPage({super.key});

  @override
  State<ProtectedPage> createState() => ProtectedPageState();
}

class ProtectedPageState extends State<ProtectedPage> {
  final ScreenSecure _screenSecure = ScreenSecure();

  @override
  void dispose() {
    _screenSecure.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenProtector(
      screenSecure: _screenSecure,
      child: Scaffold(
        body: Column(
          children: [
            const Text('Sensitive content'),
            ElevatedButton(
              onPressed: _screenSecure.mask,
              child: const Text('Mask'),
            ),
            ElevatedButton(
              onPressed: _screenSecure.lock,
              child: const Text('Lock'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Import `package:flutter/material.dart` and
`package:app_lifecycle_protector/app_lifecycle_protector.dart`. Call
`unmask()` or `unlock()` when the app's own flow permits the content to show
again. The default widgets are simple visual overlays; the default lock
overlay does not authenticate the user.

## 2. Adjust the existing feature

- Use `mask()` / `unmask()` for temporary privacy coverage and `lock()` /
  `unlock()` for a locked state.
- Supply `maskWidget` and `lockWidget` to `ScreenProtector` to customize the
  overlays.
- Use `ScreenProtector` around a page to protect that subtree. To cover the
  whole navigation stack, put it in `MaterialApp.builder` around the
  navigator child.
- Provide authentication in the app. `PassphraseLockScreen` accepts an
  `onValidate` callback; `BiometricLockScreen` accepts a
  `BiometricValidator`. Connect a real authenticator such as `local_auth`
  when appropriate, and provide a safe fallback flow.
- Never put real credentials in source code or example snippets.

## 3. Prefer this package's framework for lifecycle integration

When the app should mask on pause, unmask on resume, or lock after inactivity,
prefer `AppLifecycleScheduler` rather than adding another lifecycle observer
and timer:

```dart
class SecurityEvents extends AppLifecycleEvent {
  SecurityEvents(this.screenSecure);

  final ScreenSecure screenSecure;

  @override
  void initialize() {
    AppLifecycleScheduler.instance.updateAliveStatus();
  }

  @override
  void onPause() => screenSecure.mask();

  @override
  void onResume() => screenSecure.unmask();

  @override
  void onPeriodic() {
    if (!AppLifecycleScheduler.instance.isAlive()) {
      screenSecure.lock();
    }
  }
}
```

Initialize the scheduler after Flutter binding initialization, then set
`AppLifecycleScheduler.instance.aliveDuration` to the desired idle timeout.
Refresh activity with `updateAliveStatus()` from the app's relevant input
sources (pointer, hardware keyboard, and text input as needed). The example
above illustrates the integration pattern; adapt callback timing to the
app's security policy.

Create the shared `ScreenSecure` before initializing the scheduler, pass it to
`SecurityEvents`, and wrap the protected content with `ScreenProtector`. For
example:

```dart
final screenSecure = ScreenSecure();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppLifecycleScheduler.initialize(
    interval: const Duration(seconds: 5),
    event: SecurityEvents(screenSecure),
  );
  AppLifecycleScheduler.instance.aliveDuration =
      const Duration(minutes: 5);
  runApp(const MyApp());
}
```

If the app already has a lifecycle manager, it can call the same
`ScreenSecure` methods instead. This is an alternative, not a requirement for
using the overlay.

## 4. Extend with app-specific security logic last

Add authentication, session expiry, activity tracking, and platform-specific
protection in the app layer. Keep the responsibilities separate:

- This package manages Flutter mask/lock state and overlay rendering.
- The app supplies authentication and decides when unlock is allowed.
- Flutter overlays are not operating-system screenshot or recording
  protection. Use an appropriate platform integration if that protection is
  required.
- Scheduler callbacks can be delayed while the operating system suspends the
  app; do not rely on a background timer as a security boundary.
