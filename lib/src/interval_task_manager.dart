import 'dart:async';

import 'package:logging/logging.dart';

/// Runs an interval task with the ID it was registered under.
typedef IntervalTaskCallback = FutureOr<void> Function(String id);
typedef IntervalTaskErrorHandler = FutureOr<void> Function(
  IntervalTaskFailure failure,
);

/// Current in-memory state of an interval task.
enum IntervalTaskStatus {
  /// Registered and eligible to be checked by the next heartbeat.
  waiting,

  /// Its callback or error handler is still executing.
  running,

  /// Temporarily disabled until explicitly started or the app restarts.
  paused,

  /// Persistently disabled until explicitly started.
  stopped,
}

/// Failure information sent to the task manager's optional error handler.
class IntervalTaskFailure {
  const IntervalTaskFailure({
    required this.taskId,
    required this.error,
    required this.stackTrace,
  });

  final String taskId;
  final Object error;
  final StackTrace stackTrace;
}

class IntervalTask {
  IntervalTask._({
    required this.id,
    required Duration interval,
    required IntervalTaskCallback callback,
    required String description,
    required String intervalDescription,
  })  : _interval = interval,
        _callback = callback,
        _description = description,
        _intervalDescription = intervalDescription;

  final String id;
  Duration _interval;
  IntervalTaskCallback _callback;
  String _description;
  String _intervalDescription;
  DateTime? _lastSuccessTime;
  bool _isStopped = false;
  bool _isPaused = false;
  bool _isRunning = false;

  /// The current execution interval.
  Duration get interval => _interval;

  /// User-facing task description.
  String get description => _description;

  /// Identifier for the app's selected interval option.
  String get intervalDescription => _intervalDescription;

  /// The most recent successful completion time, or `null` before first success.
  DateTime? get lastSuccessTime => _lastSuccessTime;

  /// The task's derived runtime state.
  IntervalTaskStatus get status {
    if (_isStopped) return IntervalTaskStatus.stopped;
    if (_isPaused) return IntervalTaskStatus.paused;
    if (_isRunning) return IntervalTaskStatus.running;
    return IntervalTaskStatus.waiting;
  }
}

/// Manages in-memory interval tasks and exports/imports portable snapshots.
///
/// Call [onPeriodic] from any heartbeat source that should drive the tasks.
/// Snapshot import and export never perform external storage I/O.
class AppIntervalTaskManager {
  AppIntervalTaskManager({
    Logger? logger,
    DateTime Function()? clock,
    this.onError,
  })  : _logger = logger ?? Logger('AppIntervalTaskManager'),
        _clock = clock ?? DateTime.now;

  static const Set<String> _taskSnapshotKeys = {
    'intervalDescription',
    'stopped',
    'lastSuccessTime',
    'intervalMicroseconds',
    'description',
  };
  static const Set<String> _requiredTaskSnapshotKeys = {
    'intervalMicroseconds',
    'stopped',
    'lastSuccessTime',
  };

  final Logger _logger;
  final DateTime Function() _clock;
  final Map<String, IntervalTask> _tasks = {};
  final Set<String> _runningTaskIds = {};

  /// Optional global handler called after a task failure is logged.
  IntervalTaskErrorHandler? onError;

  /// Whether [dispose] has been called.
  bool get isDisposed => _isDisposed;
  bool _isDisposed = false;

  /// Registered tasks in insertion order. The returned list is unmodifiable.
  List<IntervalTask> get tasks =>
      List<IntervalTask>.unmodifiable(_tasks.values);

  /// Returns the task registered under [id], or `null` if it is absent.
  IntervalTask? task(String id) => _tasks[id];

  /// Adds a task or replaces the callback for an existing ID.
  ///
  /// Re-registering an existing ID replaces its callback and descriptions,
  /// while preserving its interval, last success time, and control state.
  /// Omitted descriptions default to empty strings. Set [reset] to apply
  /// [interval] and clear the task's success history and control state.
  /// A task with no successful run is eligible on the next heartbeat.
  void registerTask({
    required String id,
    required Duration interval,
    required IntervalTaskCallback callback,
    String description = '',
    String intervalDescription = '',
    bool reset = false,
  }) {
    _requireNotDisposed();
    _validateTaskDefinition(id, interval);

    final existing = _tasks[id];
    if (existing == null) {
      _tasks[id] = IntervalTask._(
        id: id,
        interval: interval,
        callback: callback,
        description: description,
        intervalDescription: intervalDescription,
      );
      return;
    }

    if (reset) {
      if (_runningTaskIds.contains(id)) {
        throw StateError('Cannot reset running task "$id".');
      }
      existing
        .._interval = interval
        .._lastSuccessTime = null
        .._isStopped = false
        .._isPaused = false;
    }
    existing
      .._callback = callback
      .._description = description
      .._intervalDescription = intervalDescription;
  }

  /// Removes [id] from the manager. Returns `false` if it was not registered.
  bool removeTask(String id) {
    _requireNotDisposed();
    return _tasks.remove(id) != null;
  }

  /// Enables [id], clearing its stopped or paused state.
  void startTask(String id) {
    _requireNotDisposed();
    final task = _requireTask(id);
    task
      .._isStopped = false
      .._isPaused = false;
  }

  /// Runs [id] immediately, bypassing its interval check.
  ///
  /// Paused or stopped tasks are not run, and an already running task is not
  /// started again. A successful manual run updates the last success time.
  void runTaskNow(String id) {
    _requireNotDisposed();
    final task = _requireTask(id);
    if (task._isStopped || task._isPaused || _runningTaskIds.contains(id)) {
      return;
    }
    _startTask(task);
  }

  /// Stops [id]; the stopped state is included in exported snapshots.
  void stopTask(String id) {
    _requireNotDisposed();
    final task = _requireTask(id);
    task
      .._isStopped = true
      .._isPaused = false;
  }

  /// Temporarily pauses [id]. A paused state is not exported.
  void pauseTask(String id) {
    _requireNotDisposed();
    final task = _requireTask(id);
    if (!task._isStopped) {
      task._isPaused = true;
    }
  }

  /// Changes [id]'s interval without resetting its last success time.
  ///
  /// The task's description fields are preserved.
  void updateInterval(String id, Duration interval) {
    _requireNotDisposed();
    if (interval <= Duration.zero) {
      throw ArgumentError.value(interval, 'interval', 'Must be positive.');
    }
    _requireTask(id)._interval = interval;
  }

  /// Updates selected fields of [id], preserving fields that are omitted.
  ///
  /// Pass an empty string to clear [description] or [intervalDescription].
  /// When [interval] changes, update [intervalDescription] as well if the app
  /// uses it to identify a matching interval option.
  void updateTask({
    required String id,
    Duration? interval,
    String? description,
    String? intervalDescription,
  }) {
    _requireNotDisposed();
    if (interval != null && interval <= Duration.zero) {
      throw ArgumentError.value(interval, 'interval', 'Must be positive.');
    }

    final task = _requireTask(id);
    if (interval != null) task._interval = interval;
    if (description != null) task._description = description;
    if (intervalDescription != null) {
      task._intervalDescription = intervalDescription;
    }
  }

  /// Checks registered tasks and starts each due task at most once.
  ///
  /// A task without a successful run is immediately eligible. While its
  /// callback or error handler is running, further heartbeats do not overlap it.
  void onPeriodic() {
    if (_isDisposed) return;

    final now = _clock();
    for (final task in List<IntervalTask>.of(_tasks.values)) {
      if (task._isStopped ||
          task._isPaused ||
          _runningTaskIds.contains(task.id) ||
          !_isDue(task, now)) {
        continue;
      }
      _startTask(task);
    }
  }

  /// Cleans up and stops all interval tasks.
  ///
  /// After calling dispose:
  /// - [onPeriodic] will not start any new tasks
  /// - All registered tasks are cleared
  /// - [onError] is set to null
  /// - Currently running tasks are allowed to complete asynchronously
  /// - The manager should not be used further
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _tasks.clear();
    onError = null;
  }

  /// Exports a detached, JSON-compatible snapshot of durable task state.
  ///
  /// The caller decides when and how to store the returned map.
  Map<String, dynamic> exportSnapshot() {
    final tasks = _tasks.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));

    return {
      for (final task in tasks)
        task.id: {
          'intervalMicroseconds': task.interval.inMicroseconds,
          'description': task.description,
          'intervalDescription': task.intervalDescription,
          'stopped': task._isStopped,
          'lastSuccessTime': task.lastSuccessTime?.toUtc().toIso8601String(),
        },
    };
  }

  /// Imports a snapshot into previously registered task definitions.
  ///
  /// All entries are validated before any state is changed. Every snapshot task
  /// must already have a callback registered under the same stable ID. Tasks
  /// not present in the snapshot keep their current state.
  void importSnapshot(Map<String, dynamic> snapshot) {
    _requireNotDisposed();
    if (_runningTaskIds.isNotEmpty) {
      throw StateError('Cannot import a snapshot while tasks are running.');
    }

    final parsedTasks = <_PersistedTask>[];
    for (final entry in snapshot.entries) {
      final id = entry.key;
      final rawTask = entry.value;
      if (id.trim().isEmpty) {
        throw const FormatException('Snapshot contains an invalid task ID.');
      }
      if (rawTask is! Map) {
        throw FormatException('Snapshot task "$id" must be a map.');
      }
      _validateMapKeys(
        rawTask,
        _requiredTaskSnapshotKeys,
        _taskSnapshotKeys,
        'task "$id"',
      );

      final intervalMicroseconds = rawTask['intervalMicroseconds'];
      final description =
          rawTask.containsKey('description') ? rawTask['description'] : '';
      final intervalDescription = rawTask.containsKey('intervalDescription')
          ? rawTask['intervalDescription']
          : '';
      final stopped = rawTask['stopped'];
      final lastSuccessValue = rawTask['lastSuccessTime'];
      if (intervalMicroseconds is! int || intervalMicroseconds <= 0) {
        throw FormatException(
          'Snapshot task "$id" has an invalid interval.',
        );
      }
      if (stopped is! bool) {
        throw FormatException(
          'Snapshot task "$id" has an invalid stopped state.',
        );
      }
      if (description is! String || intervalDescription is! String) {
        throw FormatException(
          'Snapshot task "$id" has invalid description fields.',
        );
      }

      DateTime? lastSuccessTime;
      if (lastSuccessValue != null) {
        if (lastSuccessValue is! String) {
          throw FormatException(
            'Snapshot task "$id" has an invalid lastSuccessTime.',
          );
        }
        lastSuccessTime = DateTime.tryParse(lastSuccessValue);
        if (lastSuccessTime == null || !lastSuccessTime.isUtc) {
          throw FormatException(
            'Snapshot task "$id" has an invalid lastSuccessTime.',
          );
        }
      }

      if (!_tasks.containsKey(id)) {
        throw StateError(
          'No task callback is registered for snapshot task "$id".',
        );
      }

      parsedTasks.add(
        _PersistedTask(
          id: id,
          interval: Duration(microseconds: intervalMicroseconds),
          description: description,
          intervalDescription: intervalDescription,
          stopped: stopped,
          lastSuccessTime: lastSuccessTime,
        ),
      );
    }

    for (final persisted in parsedTasks) {
      final task = _tasks[persisted.id]!;
      task
        .._interval = persisted.interval
        .._description = persisted.description
        .._intervalDescription = persisted.intervalDescription
        .._isStopped = persisted.stopped
        .._isPaused = false
        .._lastSuccessTime = persisted.lastSuccessTime;
    }
  }

  bool _isDue(IntervalTask task, DateTime now) {
    final lastSuccessTime = task._lastSuccessTime;
    return lastSuccessTime == null ||
        now.difference(lastSuccessTime) >= task.interval;
  }

  void _startTask(IntervalTask task) {
    _runningTaskIds.add(task.id);
    task._isRunning = true;
    unawaited(_runTask(task, task._callback));
  }

  Future<void> _runTask(
    IntervalTask task,
    IntervalTaskCallback callback,
  ) async {
    try {
      await callback(task.id);
      if (identical(_tasks[task.id], task)) {
        task._lastSuccessTime = _clock();
      }
    } catch (error, stackTrace) {
      _logger.severe(
        'Interval task "${task.id}" failed.',
        error,
        stackTrace,
      );
      final handler = onError;
      if (handler != null) {
        try {
          await handler(
            IntervalTaskFailure(
              taskId: task.id,
              error: error,
              stackTrace: stackTrace,
            ),
          );
        } catch (handlerError, handlerStackTrace) {
          _logger.severe(
            'Error handler for interval task "${task.id}" failed.',
            handlerError,
            handlerStackTrace,
          );
        }
      }
    } finally {
      _runningTaskIds.remove(task.id);
      task._isRunning = false;
    }
  }

  IntervalTask _requireTask(String id) {
    final task = _tasks[id];
    if (task == null) {
      throw StateError('No interval task is registered with ID "$id".');
    }
    return task;
  }

  void _requireNotDisposed() {
    if (_isDisposed) {
      throw StateError('Cannot use AppIntervalTaskManager after dispose.');
    }
  }

  static void _validateTaskDefinition(String id, Duration interval) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (interval <= Duration.zero) {
      throw ArgumentError.value(interval, 'interval', 'Must be positive.');
    }
  }

  static void _validateMapKeys(
    Map<dynamic, dynamic> value,
    Set<String> requiredKeys,
    Set<String> allowedKeys,
    String description,
  ) {
    if (value.keys.any((key) => key is! String) ||
        value.keys.toSet().difference(allowedKeys).isNotEmpty ||
        requiredKeys.difference(value.keys.cast<String>().toSet()).isNotEmpty) {
      throw FormatException(
        'Snapshot $description has unexpected or missing fields.',
      );
    }
  }
}

class _PersistedTask {
  const _PersistedTask({
    required this.id,
    required this.interval,
    required this.description,
    required this.intervalDescription,
    required this.stopped,
    required this.lastSuccessTime,
  });

  final String id;
  final Duration interval;
  final String description;
  final String intervalDescription;
  final bool stopped;
  final DateTime? lastSuccessTime;
}
