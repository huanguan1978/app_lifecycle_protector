# 周期任务管理：管理应用中的定期任务

`AppIntervalTaskManager` 用于管理客户端应用中按间隔执行的任务，并在满足运行条件时调用任务回调。

任务管理器本身不创建心跳，也不依赖 `AppLifecycleScheduler`。应用可在生命周期事件的 `onPeriodic()` 中调用它，也可用自己的定时器或其他事件源驱动。

## 客户端周期任务的特点与限制

服务端应用通常可以长期运行，适合用 `cron` 按固定时间调度任务。客户端应用，尤其是移动应用，可能被系统挂起或关闭，无法始终按时执行。平台后台任务 SDK 可以请求系统在应用后台时安排任务，但需要相应的平台配置，执行时机也由系统决定。对于只需在应用运行期间按间隔执行的工作，应用内的轻量任务管理会更合适。

## 两类任务触发方式

应用中的任务可以通过两种方式触发：

- **生命周期事件触发**：将业务逻辑挂载到 `onShow`、`onHide`、`onIdle` 等事件，在相应事件发生时执行。
- **心跳检查触发**：由周期性心跳检查任务是否可以运行，适合按指定间隔重复执行的工作。

`AppIntervalTaskManager` 管理心跳检查触发的任务。新任务会在心跳检查时运行；之后，距离上次成功运行达到设定间隔时，才会在后续心跳再次运行。应用暂时无法执行时，不会在后台运行任务或累积补跑次数；恢复后若间隔已满，后续心跳只启动一轮。

“待运行任务”指已注册、当前未运行且未暂停或停止的任务。

## 第一步：接入并运行一个任务

下面用“刷新缓存”作为例子。创建任务管理器、注册任务，然后在生命周期心跳中驱动它：

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
    description: '刷新缓存',
    intervalDescription: '5m',
  );

  AppLifecycleScheduler.initialize(
    interval: const Duration(seconds: 10),
    event: AppEvents(tasks),
  );
}

Future<void> refreshCache(String taskId) async {
  // 根据 taskId 获取对应数据，再调用应用自己的缓存刷新逻辑。
}
```

`callback` 必须接收一个 `String` 参数，即注册任务时的 `id`。同一个回调可以注册给不同 ID 和间隔的任务，并根据 ID 读取各自的数据；如果回调不需要 ID，可以用 `callback: (_) => runMaintenance()` 忽略它。

请在 Flutter binding 初始化后调用 `startAppLifecycle()`，例如在 `runApp()` 前。本例中：

- `AppLifecycleScheduler` 的 10 秒是**心跳间隔**：每隔 10 秒触发一次生命周期心跳。
- `registerTask` 的 5 分钟是**任务运行间隔**，与心跳间隔相互独立。

## 第二步：按需管理任务

以下示例中的 `tasks` 是应用中持有的任务管理器实例。每个任务使用稳定且唯一的 ID；注册后，可以更新间隔、暂停/停止、重新启动或移除任务：

```dart
tasks.updateTask(
  id: 'refresh-cache',
  interval: const Duration(minutes: 2),
  intervalDescription: '2m',
);
tasks.pauseTask('refresh-cache'); // 暂停
tasks.startTask('refresh-cache'); // 恢复或重新启动
tasks.stopTask('refresh-cache'); // 停止
tasks.removeTask('refresh-cache'); // 移除
```

暂停是临时状态，停止状态会保存在任务快照中。暂停、停止或移除后，后续心跳不会再启动该任务；已开始的回调会继续执行到结束。

`updateTask` 只更新传入的字段，未传入的字段保持不变；传入空字符串可清除 `description` 或 `intervalDescription`。更改间隔时，记得同时更新对应的选项标识，或传入空字符串清除旧标识。

需要替换任务回调时，再次注册相同 ID 即可。原间隔和任务运行状态会保留；这次注册的 `description` 和 `intervalDescription` 会替换原值，未提供时设为空字符串。传入 `reset: true` 则同时应用新间隔、清除成功时间并恢复任务：

```dart
tasks.registerTask(
  id: 'refresh-cache',
  interval: const Duration(minutes: 5),
  callback: refreshCacheWithNewLogic,
  reset: true,
);
```
任务正在执行或错误处理尚未结束时不能重置；处理结束后即可使用 `reset: true`。

### 异步任务与失败处理

任务执行失败时，管理器会记录错误；如需在应用中进一步处理，可以设置 `onError`：

```dart
final tasks = AppIntervalTaskManager(
  onError: (failure) {
    reportTaskFailure(failure.taskId, failure.error);
  },
);
```

`onError` 接收包含任务 ID、错误对象和堆栈信息的 `IntervalTaskFailure`。同步或异步回调失败都会触发它，且不会更新上次成功时间，因此后续心跳仍可重试任务。

## 第三步：按需导入和导出任务快照

任务默认保存在内存中。需要在应用重启后恢复时，由应用保存 `exportSnapshot()` 返回的 `Map<String, dynamic>`；启动时先重新注册回调，再导入快照。管理器不直接读写存储。

```dart
// 启动时：先注册回调，再恢复任务数据。
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

// 需要保存时：导出快照并交给应用自己的存储层。
Future<void> saveTasks(AppIntervalTaskManager tasks) async {
  await writeSnapshotToAppStorage(tasks.exportSnapshot());
}
```

示例中的存储函数由应用实现；不需要跨重启恢复时，无需使用快照 API。

快照以任务 ID 为键，对应的值保存该任务的数据：

```dart
{
  'refresh-cache': {
    'intervalMicroseconds': 300000000,
    'stopped': false,
    'lastSuccessTime': '2025-01-01T00:00:00.000Z',
    'description': '刷新缓存',
    'intervalDescription': '5m',
  },
}
```

`intervalMicroseconds` 是任务实际使用的间隔；`intervalDescription` 是应用的选项标识（如 `5m`），用于恢复界面选择，不参与计时。两个描述字段未设置时为空字符串。任务回调和运行中的临时状态不在快照中。

## 适用范围

适合缓存刷新、数据同步等可在应用运行期间处理且无需严格准时的工作。需要在应用关闭后继续运行或严格准时触发的任务，应使用服务端调度或平台后台任务。

## 与生命周期事件的关系

生命周期事件触发也可用于处理用户交互状态。例如，`onIdle` 表示用户在约定时间内没有操作应用界面；用户操作时调用 `updateAliveStatus()` 可重新开始计时，超时后框架会派发 `onIdle()`。

更多框架与可复用功能说明，请参阅[中文总览](README.md)。
