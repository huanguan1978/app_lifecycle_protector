---
name: app-lifecycle-protector-interval-tasks
description: "Use when adding or managing interval-driven tasks in a Flutter app with app_lifecycle_protector, including AppIntervalTaskManager, heartbeat integration, task controls, error handling, and task snapshots."
---

# App Lifecycle Protector: Interval Task Management

Use this skill for recurring client-app work such as refreshing a cache or
syncing account data. Follow the app's simplest working path first: connect a
heartbeat and register one task, then tune its interval and controls, and add
app-specific error handling or persistence only when needed.

## 1. Start with one task and a lifecycle heartbeat

`AppIntervalTaskManager` does not create a timer. The app supplies a heartbeat;
the simplest package integration is to call `tasks.onPeriodic()` from
`AppLifecycleEvent.onPeriodic()`:

```dart
import 'package:flutter/widgets.dart';
import 'package:app_lifecycle_protector/app_lifecycle_protector.dart';

class AppEvents extends AppLifecycleEvent {
  AppEvents(this.tasks);

  final AppIntervalTaskManager tasks;

  @override
  void onPeriodic() => tasks.onPeriodic();
}

Future<void> refreshCache(String taskId) async {
  // Use taskId to load the corresponding data and refresh the cache.
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(const MyApp());
}
```

The 10-second scheduler interval is the **heartbeat interval**; it controls
how often the manager checks tasks. The 5-minute task interval is measured
from the last successful completion. A new task runs at a heartbeat check;
afterward, it runs at the first heartbeat after its interval has elapsed.
The manager can also be driven by the app's own timer or another event source.
The task callback receives its registered ID as a `String`; reuse one callback
for multiple tasks when the ID selects the task's data. Use `(_)` when the
callback does not need the ID.

## 2. Tune task intervals and controls

Choose a heartbeat cadence that suits the app, then set each task's own
interval. These are separate values: a task does not run exactly on its
interval boundary, but on a heartbeat check after that boundary.

Use stable, unique task IDs. Update selected fields without replacing the
callback:

```dart
tasks.updateTask(
  id: 'refresh-cache',
  interval: const Duration(minutes: 2),
  intervalDescription: '2m',
);
```

The app can pause, stop, restart, or remove a task:

```dart
tasks.pauseTask('refresh-cache'); // Temporary; not included in snapshots.
tasks.startTask('refresh-cache'); // Resume or restart.
tasks.stopTask('refresh-cache'); // Stopped state is included in snapshots.
tasks.removeTask('refresh-cache');
tasks.runTaskNow('refresh-cache'); // Bypass the interval; paused/stopped tasks stay inactive.
```

These controls prevent a later heartbeat from starting the task; they do not
cancel a callback that is already running. `updateTask` preserves fields you
omit. Pass an empty string to clear `description` or `intervalDescription`.
If the interval changes, also update or clear its option ID when the app uses
one.

To replace a callback, register the same ID again. This replaces the callback
and description fields while preserving interval and run state. Pass
`reset: true` to apply the supplied interval, clear the last-success time, and
clear stopped or paused state. Do not reset a task while its callback or error
handler is running.

## 3. Add app-specific error handling and persistence

Callbacks can be synchronous or asynchronous. Failures are logged and do not
update the last-success time, so a later heartbeat checks the task again.
Handle failures in app code when needed:

```dart
final tasks = AppIntervalTaskManager(
  onError: (failure) {
    reportTaskFailure(failure.taskId, failure.error);
  },
);
```

`onError` receives an `IntervalTaskFailure` with the task ID, error, and
stack trace. The app decides whether to log, report, or notify the user.

Tasks are in memory by default. To restore them after a restart, register the
callbacks under their stable IDs first, then import a saved snapshot. Export
the snapshot whenever the app's persistence policy calls for it:

```dart
final snapshot = tasks.exportSnapshot();
await saveSnapshotToAppStorage(snapshot);

final savedSnapshot = await readSnapshotFromAppStorage();
if (savedSnapshot != null) {
  tasks.importSnapshot(savedSnapshot);
}
```

The manager exchanges a `Map<String, dynamic>` and does not access storage.
Snapshots contain durable task data, not callbacks or transient running and
paused state. The stopped state is preserved. See the
[interval task management guide](../../doc/en/interval_task_manager.md) for
the snapshot shape and complete API behavior.

## Respect client runtime limits

Heartbeats can run only while the app process is able to execute Dart code.
If the operating system suspends the app, checks are delayed; if the process
terminates, tasks stop running. Missed intervals are not queued for replay:
after execution resumes, a task whose interval has elapsed runs once at a
later heartbeat.
