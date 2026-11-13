import 'package:app_lifecycle_protector/app_lifecycle_protector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dispatches onIdle once per inactivity period and heartbeats tasks',
      () async {
    final tasks = AppIntervalTaskManager();
    final event = _TestLifecycleEvent(tasks);
    AppLifecycleScheduler.initialize(
      interval: const Duration(milliseconds: 10),
      event: event,
    );
    addTearDown(AppLifecycleScheduler.instance.dispose);

    final scheduler = AppLifecycleScheduler.instance;
    scheduler.aliveDuration = const Duration(milliseconds: 30);
    var taskCalls = 0;
    tasks.registerTask(
      id: 'heartbeat-task',
      interval: const Duration(minutes: 1),
      callback: () => taskCalls++,
    );

    expect(scheduler.isAlive(), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(event.idleCalls, 1);
    expect(event.periodicCalls, greaterThanOrEqualTo(3));
    expect(taskCalls, 1);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(event.idleCalls, 1);

    scheduler.updateAliveStatus();
    expect(scheduler.isAlive(), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(event.idleCalls, 1);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(event.idleCalls, 2);
  });
}

class _TestLifecycleEvent extends AppLifecycleEvent {
  _TestLifecycleEvent(this.taskManager);

  final AppIntervalTaskManager taskManager;
  int idleCalls = 0;
  int periodicCalls = 0;

  @override
  void onPeriodic() {
    periodicCalls++;
    taskManager.onPeriodic();
  }

  @override
  void onIdle() => idleCalls++;
}
