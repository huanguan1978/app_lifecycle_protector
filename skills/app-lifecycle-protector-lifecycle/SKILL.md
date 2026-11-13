---
name: app-lifecycle-protector-lifecycle
description: "Use when building Flutter lifecycle handling with app_lifecycle_protector, including resume, foreground/background, idle-time checks, scheduler setup, and lifecycle-driven feature integration."
---

# App Lifecycle Protector: Lifecycle Framework

Use this skill when a Flutter app needs centralized lifecycle callbacks,
periodic work, foreground/background decisions, or idle-time checks. For
screen-protection or network-probing tasks, use the corresponding package
feature if available; this skill explains how to integrate those features
with the framework.

## Start with the framework

Extend `AppLifecycleEvent` and initialize the scheduler after Flutter binding
initialization:

```dart
class AppEvents extends AppLifecycleEvent {
  @override
  void onResume() {
    // Refresh data after the app resumes.
  }

  @override
  void onPeriodic() {
    if (isInForeground) {
      // Run work appropriate while the app is visible.
    }
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppLifecycleScheduler.initialize(
    interval: const Duration(seconds: 10),
    event: AppEvents(),
  );
  runApp(const MyApp());
}
```

Import `package:flutter/widgets.dart` and
`package:app_lifecycle_protector/app_lifecycle_protector.dart` where needed.
The first `onPeriodic()` call occurs after one interval.

## Choose callbacks by meaning

- Use `onResume()` for work after the app resumes, `onPause()` for pause
  handling, `onShow()` and `onHide()` for visibility transitions, and
  `onDetach()` for detachment. Do not treat these callbacks as interchangeable.
- `isInForeground` and `isInBackground` are available on the event handler.
  The scheduler updates them on show/hide notifications.
- The periodic timer remains active when the app is hidden. Keep periodic work
  lightweight and check foreground state when the work should be visible-only.
- Override only the callbacks the app needs.

## Handle user-idle events

Override `onIdle()` to respond once on the next heartbeat after `aliveDuration`
passes without recorded user interaction. This signal is independent of
foreground state and background work. The idle clock starts when the scheduler
is initialized; calling `updateAliveStatus()` from relevant input sources
starts a new idle period. The default timeout is three minutes:

```dart
AppLifecycleScheduler.instance.aliveDuration =
    const Duration(minutes: 5);
```

`isAlive()` remains available for code that needs a direct activity check. It
returns `false` until activity has first been recorded.

## Integrate interval tasks when needed

For interval-driven work, use the dedicated
[interval task management skill](../app-lifecycle-protector-interval-tasks/SKILL.md)
for the beginner workflow, task controls, error handling, and snapshots. The
integration point is to call the independent manager from `onPeriodic()`:

```dart
class AppEvents extends AppLifecycleEvent {
  AppEvents(this.tasks);

  final AppIntervalTaskManager tasks;

  @override
  void onPeriodic() => tasks.onPeriodic();
}

void initializeLifecycle() {
  final tasks = AppIntervalTaskManager();
  tasks.registerTask(
    id: 'refresh-cache',
    interval: const Duration(minutes: 5),
    callback: refreshCache,
  );
  AppLifecycleScheduler.initialize(
    interval: const Duration(seconds: 10),
    event: AppEvents(tasks),
  );
}
```

The manager does not create a timer. If the app already has an appropriate
heartbeat source, call `tasks.onPeriodic()` from that source instead of
initializing another `AppLifecycleScheduler`.

## Integrate package features before inventing another scheduler

When a package feature needs lifecycle-driven behavior, prefer using
`AppLifecycleEvent` and `AppLifecycleScheduler` so lifecycle checks and
periodic cadence stay in one place. For example, an event handler can call an
`AppIntervalTaskManager` or `NetworkProber` from `onPeriodic()`, or mask/unmask
a `ScreenSecure` instance from pause/resume callbacks. Follow the feature's
own skill or package guide for its setup and safety boundaries.

Use an existing app scheduler instead when the app already has one and
replacing it would add unnecessary complexity.

## Respect runtime limits and lifecycle ownership

- A Dart timer can run only while the process is alive and Dart execution is
  allowed. The operating system can suspend the app, delaying callbacks, or
  terminate the process, stopping them entirely. Do not promise exact
  background timing or use this scheduler as a substitute for platform
  background-task APIs.
- The scheduler is a global singleton. `initialize()` creates it only once;
  later calls do not replace its interval or event handler.
- Dispose it when the owning app scope ends:

  ```dart
  AppLifecycleScheduler.instance.dispose();
  ```

- Do not initialize multiple competing scheduler instances. Ensure the owner
  disposes the singleton once, and dispose any feature objects owned by the
  same scope.
