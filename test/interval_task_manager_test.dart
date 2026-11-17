import 'dart:async';

import 'package:app_lifecycle_protector/app_lifecycle_protector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppIntervalTaskManager', () {
    late DateTime now;
    late AppIntervalTaskManager manager;

    setUp(() {
      now = DateTime.utc(2025);
      manager = AppIntervalTaskManager(clock: () => now);
    });

    test('runs an eligible task and updates its last success time', () async {
      var calls = 0;
      manager.registerTask(
        id: 'refresh',
        interval: const Duration(minutes: 1),
        callback: (_) => calls++,
      );

      manager.onPeriodic();
      await _flushAsyncWork();

      expect(calls, 1);
      expect(manager.task('refresh')!.lastSuccessTime, now);
      expect(manager.task('refresh')!.status, IntervalTaskStatus.waiting);
    });

    test('passes each task ID to the callback', () async {
      final taskIds = <String>[];
      Future<void> processTask(String id) async {
        taskIds.add(id);
      }

      manager.registerTask(
        id: 'customer-42',
        interval: const Duration(minutes: 5),
        callback: processTask,
      );
      manager.registerTask(
        id: 'customer-99',
        interval: const Duration(minutes: 30),
        callback: processTask,
      );

      manager.onPeriodic();
      await _flushAsyncWork();

      expect(taskIds, ['customer-42', 'customer-99']);
    });

    test('does not overlap a running task', () async {
      final completion = Completer<void>();
      var calls = 0;
      manager.registerTask(
        id: 'refresh',
        interval: const Duration(seconds: 1),
        callback: (_) {
          calls++;
          return completion.future;
        },
      );

      manager.onPeriodic();
      manager.onPeriodic();
      expect(calls, 1);
      expect(manager.task('refresh')!.status, IntervalTaskStatus.running);

      completion.complete();
      await _flushAsyncWork();
      expect(manager.task('refresh')!.status, IntervalTaskStatus.waiting);
    });

    test('runs a task immediately without waiting for its interval', () async {
      var calls = 0;
      manager.registerTask(
        id: 'refresh',
        interval: const Duration(days: 1),
        callback: (_) => calls++,
      );
      manager.onPeriodic();
      await _flushAsyncWork();

      now = now.add(const Duration(seconds: 1));
      manager.runTaskNow('refresh');
      await _flushAsyncWork();

      expect(calls, 2);
      expect(manager.task('refresh')!.lastSuccessTime, now);
    });

    test('does not run paused or stopped tasks manually', () async {
      var calls = 0;
      manager.registerTask(
        id: 'refresh',
        interval: const Duration(days: 1),
        callback: (_) => calls++,
      );

      manager.pauseTask('refresh');
      manager.runTaskNow('refresh');
      expect(manager.task('refresh')!.status, IntervalTaskStatus.paused);

      manager.startTask('refresh');
      manager.runTaskNow('refresh');
      await _flushAsyncWork();
      expect(calls, 1);

      manager.stopTask('refresh');
      manager.runTaskNow('refresh');
      expect(manager.task('refresh')!.status, IntervalTaskStatus.stopped);
      expect(calls, 1);
    });

    test('does not overlap a manual run', () async {
      final completion = Completer<void>();
      var calls = 0;
      manager.registerTask(
        id: 'refresh',
        interval: const Duration(days: 1),
        callback: (_) {
          calls++;
          return completion.future;
        },
      );

      manager.runTaskNow('refresh');
      manager.runTaskNow('refresh');
      expect(calls, 1);

      completion.complete();
      await _flushAsyncWork();
      expect(manager.task('refresh')!.status, IntervalTaskStatus.waiting);
    });

    test('updates interval relative to the last success time', () async {
      var calls = 0;
      manager.registerTask(
        id: 'refresh',
        interval: const Duration(seconds: 10),
        callback: (_) => calls++,
      );

      manager.onPeriodic();
      await _flushAsyncWork();
      expect(calls, 1);

      now = now.add(const Duration(seconds: 4));
      manager.updateInterval('refresh', const Duration(seconds: 5));
      manager.onPeriodic();
      await _flushAsyncWork();
      expect(calls, 1);

      now = now.add(const Duration(seconds: 1));
      manager.onPeriodic();
      await _flushAsyncWork();
      expect(calls, 2);
    });

    test('registers optional descriptions and updates only supplied fields',
        () {
      manager.registerTask(
        id: 'refresh',
        interval: const Duration(minutes: 5),
        callback: (_) {},
        description: 'Refresh app cache',
        intervalDescription: '5m',
      );

      manager.updateTask(
        id: 'refresh',
        interval: const Duration(minutes: 2),
      );
      expect(manager.task('refresh')!.interval, const Duration(minutes: 2));
      expect(manager.task('refresh')!.description, 'Refresh app cache');
      expect(manager.task('refresh')!.intervalDescription, '5m');

      manager.updateTask(
        id: 'refresh',
        description: '',
        intervalDescription: '2m',
      );
      expect(manager.task('refresh')!.description, '');
      expect(manager.task('refresh')!.intervalDescription, '2m');
    });

    test('re-registering an ID clears omitted descriptions', () {
      manager.registerTask(
        id: 'refresh',
        interval: const Duration(minutes: 5),
        callback: (_) {},
        description: 'Refresh app cache',
        intervalDescription: '5m',
      );

      manager.registerTask(
        id: 'refresh',
        interval: const Duration(minutes: 10),
        callback: (_) {},
      );

      expect(manager.task('refresh')!.description, '');
      expect(manager.task('refresh')!.intervalDescription, '');
    });

    test('retries failures and provides failure context', () async {
      final failures = <IntervalTaskFailure>[];
      var calls = 0;
      manager.onError = failures.add;
      manager.registerTask(
        id: 'refresh',
        interval: const Duration(seconds: 1),
        callback: (_) {
          calls++;
          throw StateError('failed');
        },
      );

      manager.onPeriodic();
      await _flushAsyncWork();

      expect(calls, 1);
      expect(failures, hasLength(1));
      expect(failures.single.taskId, 'refresh');
      expect(failures.single.error, isA<StateError>());
      expect(failures.single.stackTrace, isA<StackTrace>());
      expect(manager.task('refresh')!.lastSuccessTime, isNull);

      manager.onPeriodic();
      await _flushAsyncWork();
      expect(calls, 2);
      expect(failures, hasLength(2));
    });

    test('logs and contains errors thrown by the error handler', () async {
      manager.onError = (_) => throw StateError('handler failed');
      manager.registerTask(
        id: 'refresh',
        interval: const Duration(seconds: 1),
        callback: (_) => throw StateError('task failed'),
      );

      expect(() => manager.onPeriodic(), returnsNormally);
      await _flushAsyncWork();
      expect(manager.task('refresh')!.lastSuccessTime, isNull);
    });

    test('pause is transient while stop is exported and restored', () async {
      manager.registerTask(
        id: 'refresh',
        interval: const Duration(seconds: 1),
        callback: (_) {},
      );
      manager.pauseTask('refresh');
      expect(manager.task('refresh')!.status, IntervalTaskStatus.paused);

      final snapshot = manager.exportSnapshot();
      final restored = AppIntervalTaskManager(clock: () => now);
      restored.registerTask(
        id: 'refresh',
        interval: const Duration(seconds: 2),
        callback: (_) {},
      );
      restored.importSnapshot(snapshot);
      expect(restored.task('refresh')!.status, IntervalTaskStatus.waiting);

      restored.stopTask('refresh');
      final stoppedSnapshot = restored.exportSnapshot();
      final nextRestore = AppIntervalTaskManager(clock: () => now);
      nextRestore.registerTask(
        id: 'refresh',
        interval: const Duration(seconds: 2),
        callback: (_) {},
      );
      nextRestore.importSnapshot(stoppedSnapshot);
      expect(nextRestore.task('refresh')!.status, IntervalTaskStatus.stopped);
    });

    test('exports durable fields and restores interval and last success',
        () async {
      manager.registerTask(
        id: 'refresh',
        interval: const Duration(seconds: 1),
        callback: (_) {},
      );
      manager.onPeriodic();
      await _flushAsyncWork();

      final successTime = manager.task('refresh')!.lastSuccessTime;
      manager.updateInterval('refresh', const Duration(seconds: 10));
      final snapshot = manager.exportSnapshot();
      final taskData = snapshot['refresh']! as Map;

      expect(snapshot.keys, {'refresh'});
      expect(taskData.keys, {
        'intervalMicroseconds',
        'description',
        'intervalDescription',
        'stopped',
        'lastSuccessTime',
      });
      expect(taskData['intervalMicroseconds'],
          const Duration(seconds: 10).inMicroseconds);
      expect(
          taskData['lastSuccessTime'], successTime!.toUtc().toIso8601String());

      final restored = AppIntervalTaskManager(clock: () => now);
      restored.registerTask(
        id: 'refresh',
        interval: const Duration(seconds: 2),
        callback: (_) {},
      );
      restored.importSnapshot(snapshot);

      expect(restored.task('refresh')!.interval, const Duration(seconds: 10));
      expect(restored.task('refresh')!.lastSuccessTime, successTime);
      expect(restored.task('refresh')!.description, '');
      expect(restored.task('refresh')!.intervalDescription, '');
    });

    test('exports and restores task descriptions', () {
      manager.registerTask(
        id: 'refresh',
        interval: const Duration(minutes: 5),
        callback: (_) {},
        description: 'Refresh app cache',
        intervalDescription: '5m',
      );
      final snapshot = manager.exportSnapshot();

      final restored = AppIntervalTaskManager(clock: () => now);
      restored.registerTask(
        id: 'refresh',
        interval: const Duration(minutes: 1),
        callback: (_) {},
      );
      restored.importSnapshot(snapshot);

      expect(restored.task('refresh')!.description, 'Refresh app cache');
      expect(restored.task('refresh')!.intervalDescription, '5m');
    });

    test('imports older snapshots without optional description fields', () {
      manager.registerTask(
        id: 'refresh',
        interval: const Duration(minutes: 5),
        callback: (_) {},
        description: 'Existing task description',
        intervalDescription: '5m',
      );

      manager.importSnapshot({
        'refresh': {
          'intervalMicroseconds': const Duration(minutes: 10).inMicroseconds,
          'stopped': false,
          'lastSuccessTime': null,
        },
      });

      expect(manager.task('refresh')!.description, '');
      expect(manager.task('refresh')!.intervalDescription, '');
    });

    test('rejects non-string task descriptions in snapshots', () {
      manager.registerTask(
        id: 'refresh',
        interval: const Duration(minutes: 5),
        callback: (_) {},
      );

      expect(
        () => manager.importSnapshot({
          'refresh': {
            'intervalMicroseconds': const Duration(minutes: 5).inMicroseconds,
            'description': null,
            'intervalDescription': '5m',
            'stopped': false,
            'lastSuccessTime': null,
          },
        }),
        throwsFormatException,
      );
    });

    test('re-registering an ID replaces callback but preserves state',
        () async {
      var originalCalls = 0;
      var replacementCalls = 0;
      manager.registerTask(
        id: 'refresh',
        interval: const Duration(seconds: 1),
        callback: (_) => originalCalls++,
      );
      manager.onPeriodic();
      await _flushAsyncWork();
      final lastSuccessTime = manager.task('refresh')!.lastSuccessTime;

      manager.updateInterval('refresh', const Duration(seconds: 5));
      manager.registerTask(
        id: 'refresh',
        interval: const Duration(seconds: 20),
        callback: (_) => replacementCalls++,
      );

      expect(manager.task('refresh')!.interval, const Duration(seconds: 5));
      expect(manager.task('refresh')!.lastSuccessTime, lastSuccessTime);
      manager.startTask('refresh');
      now = now.add(const Duration(seconds: 5));
      manager.onPeriodic();
      await _flushAsyncWork();

      expect(originalCalls, 1);
      expect(replacementCalls, 1);
    });

    test('rejects invalid snapshots without partially applying them', () {
      manager.registerTask(
        id: 'first',
        interval: const Duration(seconds: 1),
        callback: (_) {},
      );
      manager.registerTask(
        id: 'second',
        interval: const Duration(seconds: 2),
        callback: (_) {},
      );

      final snapshot = {
        'first': {
          'intervalMicroseconds': const Duration(seconds: 10).inMicroseconds,
          'stopped': false,
          'lastSuccessTime': null,
        },
        'second': {
          'intervalMicroseconds': 0,
          'stopped': false,
          'lastSuccessTime': null,
        },
      };

      expect(() => manager.importSnapshot(snapshot), throwsFormatException);
      expect(manager.task('first')!.interval, const Duration(seconds: 1));
    });

    test('rejects snapshot tasks without a registered callback', () {
      expect(
        () => manager.importSnapshot({
          'missing': {
            'intervalMicroseconds': const Duration(seconds: 1).inMicroseconds,
            'stopped': false,
            'lastSuccessTime': null,
          },
        }),
        throwsStateError,
      );
    });

    test('requires snapshot timestamps to include a timezone', () {
      manager.registerTask(
        id: 'refresh',
        interval: const Duration(seconds: 1),
        callback: (_) {},
      );

      expect(
        () => manager.importSnapshot({
          'refresh': {
            'intervalMicroseconds': const Duration(seconds: 1).inMicroseconds,
            'stopped': false,
            'lastSuccessTime': '2025-01-01T00:00:00',
          },
        }),
        throwsFormatException,
      );
    });

    group('dispose', () {
      test('prevents new tasks from being registered', () {
        manager.registerTask(
          id: 'task1',
          interval: const Duration(seconds: 1),
          callback: (_) {},
        );
        manager.dispose();

        expect(
          () => manager.registerTask(
            id: 'task2',
            interval: const Duration(seconds: 1),
            callback: (_) {},
          ),
          throwsStateError,
        );
      });

      test('prevents heartbeats from starting new tasks', () async {
        var calls = 0;
        manager.registerTask(
          id: 'task1',
          interval: const Duration(seconds: 1),
          callback: (_) => calls++,
        );
        manager.onPeriodic();
        await _flushAsyncWork();
        expect(calls, 1);

        manager.dispose();
        manager.onPeriodic();
        await _flushAsyncWork();
        expect(calls, 1); // No additional calls after dispose
      });

      test('clears all registered tasks', () {
        manager.registerTask(
          id: 'task1',
          interval: const Duration(seconds: 1),
          callback: (_) {},
        );
        manager.registerTask(
          id: 'task2',
          interval: const Duration(seconds: 2),
          callback: (_) {},
        );
        expect(manager.tasks, hasLength(2));

        manager.dispose();
        expect(manager.tasks, isEmpty);
      });

      test('sets isDisposed flag', () {
        expect(manager.isDisposed, false);
        manager.dispose();
        expect(manager.isDisposed, true);
      });

      test('clears error handler', () {
        manager.onError = (_) {};
        manager.dispose();
        expect(manager.onError, isNull);
      });

      test('idempotent - can be called multiple times', () {
        manager.registerTask(
          id: 'task1',
          interval: const Duration(seconds: 1),
          callback: (_) {},
        );
        manager.dispose();
        manager.dispose(); // Should not throw
        expect(manager.isDisposed, true);
      });

      test('prevents other state modifications', () {
        manager.registerTask(
          id: 'task1',
          interval: const Duration(seconds: 1),
          callback: (_) {},
        );
        manager.dispose();

        expect(
          () => manager.updateInterval('task1', const Duration(seconds: 2)),
          throwsStateError,
        );
        expect(
          () => manager.startTask('task1'),
          throwsStateError,
        );
      });
    });
  });
}

Future<void> _flushAsyncWork() => Future<void>.delayed(Duration.zero);
