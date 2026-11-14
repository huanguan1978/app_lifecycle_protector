# Interval Task Management

`AppIntervalTaskManager` manages tasks that run at intervals while a client
app is active. It invokes a task's callback when the task is eligible to run.

The manager does not create a heartbeat or depend on
`AppLifecycleScheduler`. Call it from `onPeriodic()` or drive it with your own
timer or another event source.

## Why client apps need a different approach

Server applications can often run continuously, making `cron` a good fit for
scheduling work at fixed times. Client apps, especially mobile apps, may be
suspended or closed, so they cannot reliably run tasks on schedule. Platform
background-task SDKs can ask the operating system to schedule work while an
app is in the background, but require platform-specific configuration and
leave execution timing to the operating system.

For work that only needs to run at intervals while the app is active, a
lightweight in-app task manager is a better fit.

## Two ways to trigger app work

App work can be triggered in two ways:

- **Lifecycle events:** Attach business logic to events such as `onShow`,
  `onHide`, or `onIdle`; the logic runs when the event occurs.
- **Heartbeat checks:** A periodic heartbeat checks whether a task can run.
  This is suitable for work that repeats at a specified interval.

`AppIntervalTaskManager` manages tasks triggered by heartbeat checks. A newly
registered task runs at a heartbeat check. After that, it runs again at a
subsequent check once the configured interval has elapsed since its last
successful completion. If the app cannot run temporarily, tasks do not run in
the background and missed intervals are not queued. When execution resumes,
an overdue task runs once at a later heartbeat.

A task is eligible for checking when it is registered, not currently running,
and neither paused nor stopped.

## Step 1: Register and run a task

This example creates a task manager, registers a cache-refresh task, and
drives it from a lifecycle heartbeat:

```dart
import 'package:app_lifecycle_protector/app_lifecycle_protector.dart';

class AppEvents extends AppLifecycleEvent {
  AppEvents(this.tasks);

  final AppIntervalTaskManager tasks;

  @override
  void onPeriodic() {
    tasks.onPeriodic();
  }
}

late final AppIntervalTaskManager tasks;

void startAppLifecycle() {
  tasks = AppIntervalTaskManager();

  tasks.registerTask(
    id: 'refresh-cache',
    interval: const Duration(minutes: 5),
    callback: refreshCache,
    description: 'Refresh cache',
    intervalDescription: '5m',
  );

  AppLifecycleScheduler.initialize(
    interval: const Duration(seconds: 10),
    event: AppEvents(tasks),
  );
}

Future<void> refreshCache(String taskId) async {
  // Use taskId to load the corresponding data, then refresh the cache.
}
```

`callback` must accept one `String` argument: the task's registered `id`.
The same callback can be registered for tasks with different IDs and
intervals, then use the ID to load each task's data. If a callback does not
need the ID, ignore it with `callback: (_) => runMaintenance()`.

Call `startAppLifecycle()` after initializing the Flutter binding, for
example before `runApp()`. In this example:

- The 10 seconds configured for `AppLifecycleScheduler` is the **heartbeat
  interval**: a lifecycle heartbeat is triggered every 10 seconds.
- The 5 minutes passed to `registerTask` is the **task interval**. It is
  independent of the heartbeat interval.

## Step 2: Manage tasks as needed

Give each task a stable, unique ID. After registration, you can update its
interval, pause or stop it, start it again, or remove it:

```dart
tasks.updateTask(
  id: 'refresh-cache',
  interval: const Duration(minutes: 2),
  intervalDescription: '2m',
);
tasks.pauseTask('refresh-cache'); // Pause
tasks.startTask('refresh-cache'); // Resume or restart
tasks.stopTask('refresh-cache'); // Stop
tasks.removeTask('refresh-cache'); // Remove
```

To trigger a task manually—for example, while debugging or before its next
interval elapses—run it by ID:

```dart
tasks.runTaskNow('refresh-cache');
```

This bypasses the interval check, but does not run paused or stopped tasks and
does not overlap an existing run. On success, the task's last-success time is
updated, so its next interval is measured from that completion.

Pausing is temporary; the stopped state is included in task snapshots. After
a task is paused, stopped, or removed, later heartbeats will not start it
again. A callback that has already started continues until it completes.

`updateTask` changes only the fields you pass; omitted fields keep their
current values. Pass an empty string to clear `description` or
`intervalDescription`. When changing the interval, update its option ID too,
or pass an empty string to clear the old ID.

To replace a task's callback, register the same ID again. Its interval and
runtime state are preserved. The new `description` and `intervalDescription`
replace the old values; omitted values are set to empty strings. Pass
`reset: true` to apply the new interval, clear the last-success time, and
restart the task:

```dart
tasks.registerTask(
  id: 'refresh-cache',
  interval: const Duration(minutes: 5),
  callback: refreshCacheWithNewLogic,
  reset: true,
);
```

You cannot reset a task while it is running or its error handler is still
being processed. Reset it after that work completes.

### Async tasks and error handling

If a task fails, the manager records the error. To handle failures in your
app, set `onError`:

```dart
final tasks = AppIntervalTaskManager(
  onError: (failure) {
    reportTaskFailure(failure.taskId, failure.error);
  },
);
```

`onError` receives an `IntervalTaskFailure` containing the task ID, error,
and stack trace. It is called for both synchronous and asynchronous callback
failures. A failure does not update the last-success time, so later
heartbeats can retry the task.

## Step 3: Import and export task snapshots as needed

Tasks are kept in memory by default. To restore them after an app restart,
save the `Map<String, dynamic>` returned by `exportSnapshot()` in your own
storage. On startup, register the callbacks first, then import the snapshot.
The manager does not read from or write to storage itself.

```dart
// On startup: register callbacks before restoring task data.
Future<AppIntervalTaskManager> loadTasks() async {
  final tasks = AppIntervalTaskManager();
  tasks.registerTask(
    id: 'refresh-cache',
    interval: const Duration(minutes: 5),
    callback: refreshCache,
  );

  final Map<String, dynamic>? snapshot =
      await readSnapshotFromAppStorage();
  if (snapshot != null) tasks.importSnapshot(snapshot);
  return tasks;
}

// When needed: export the snapshot to your app's storage.
Future<void> saveTasks(AppIntervalTaskManager tasks) async {
  await writeSnapshotToAppStorage(tasks.exportSnapshot());
}
```

Implement the storage functions for your app. You do not need the snapshot
API if tasks do not need to be restored after a restart.

The snapshot is keyed by task ID, with each value containing that task's
data:

```dart
{
  'refresh-cache': {
    'intervalMicroseconds': 300000000,
    'stopped': false,
    'lastSuccessTime': '2025-01-01T00:00:00.000Z',
    'description': 'Refresh cache',
    'intervalDescription': '5m',
  },
}
```

`intervalMicroseconds` stores the actual interval. `intervalDescription` is
an app-defined option ID (such as `5m`) that can restore a UI selection; it
does not affect timing. Unset description fields are empty strings. Callback
functions and other runtime-only state are not included in the snapshot.

## When to use it

This manager is suitable for work such as cache refreshes and data syncs that
can run while the app is active and do not require precise timing. For tasks
that must continue after the app closes or run at an exact time, use a
server-side scheduler or a platform background-task API.

## How it relates to lifecycle events

Lifecycle events can also respond to user activity. For example, `onIdle()`
is dispatched when the user has not interacted with the app's UI for the
configured period. Call `updateAliveStatus()` when the user interacts with
the UI to restart the idle timer.

For an overview of the framework and reusable features, see the
[English overview](README.md).
