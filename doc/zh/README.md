# App Lifecycle Protector（中文版）

`app_lifecycle_protector` 是一个帮助 Flutter 应用集中处理生命周期事件和定时任务的框架，并提供屏幕保护与网络探测两种可复用功能。

## 核心价值

### 把生命周期逻辑集中起来

应用恢复时刷新数据、切到后台时隐藏内容，或定期检查会话状态，这些逻辑通常散落在不同的 Widget 和服务中。继承 `AppLifecycleEvent` 并覆盖需要的方法，就能把它们集中在一个事件处理器里，不必为每项业务重复注册生命周期监听、管理计时器和判断前后台状态。

### 前后台都可使用定时任务

`AppLifecycleScheduler` 按设定间隔调用 `onPeriodic()`，不会仅因为应用界面隐藏就停止计时器。应用切换到另一个应用后，自己的界面不可见，这叫进入后台，但应用进程通常仍然存在；只要进程仍在运行并能执行 Dart 代码，周期回调就可继续处理前台或后台任务。

如果操作系统挂起应用，进程可能仍存在，但 Dart 代码暂停执行，定时回调会延后；如果进程被终止，应用中的定时器和回调都会停止。因此，本框架能在应用仍可执行代码时处理前后台任务，但不能阻止操作系统挂起或终止应用。

## 快速上手

`AppLifecycleEvent` 用来编写应用自己的事件处理逻辑；`AppLifecycleScheduler` 负责接收 Flutter 的生命周期通知，并定期调用 `onPeriodic()`。例如：

```dart
class MyAppEvents extends AppLifecycleEvent {
  @override
  void onResume() {
    // 应用恢复时刷新数据
  }

  @override
  void onPeriodic() {
    if (isInForeground) {
      // 前台任务
    } else {
      // 后台任务
    }
  }
}

void initializeLifecycle() {
  AppLifecycleScheduler.initialize(
    interval: const Duration(seconds: 10),
    event: MyAppEvents(),
  );
}
```

在 Flutter binding 初始化之后调用 `initializeLifecycle()`，例如在 `runApp` 前或根组件的 `initState` 中。第一次 `onPeriodic()` 会在一个 `interval` 过去后触发。

## 两个可复用功能

需要在切换应用或用户闲置时保护敏感界面时，可用 `ScreenSecure` 管理遮罩与锁定状态，再由 `ScreenProtector` 显示自定义保护界面。认证方式由应用决定，可接入已有的密码或生物识别流程。详见[屏幕保护功能](screen_secure.md)。

需要检查某个服务端点是否可达时，可用 `NetworkProber` 发起 HTTP 探测并监听结果。它不自行定时轮询，调用方决定何时探测；需要限定在特定路由时，可配合 `RouteSentry`。详见[网络探针功能](network_prober.md)。

这两项功能可以与生命周期框架组合，也可以按需独立使用。你也可以在自己的事件处理器中实现会话过期检查、业务心跳等逻辑。

## 运行和探索示例

你可以运行 `example/` 目录中的 Flutter 示例应用，实际体验生命周期框架、屏幕保护和网络探针：

```shell
cd example
flutter run
```

示例应用的代码按框架演示、功能实现和界面分层组织。你可以阅读并复制其中的源码到自己的项目，再按实际需求修改、运行和探索各项功能。详细的示例介绍、源码导读及平台联网配置说明，请参阅 [`example/example.md`](../../example/example.md)。

## 依赖与进一步使用

本包依赖 Flutter SDK 和 `logging`，不依赖平台插件或特定状态管理方案。除 `onResume()` 外，`AppLifecycleEvent` 还提供显示、隐藏、暂停、退出等事件回调；它们对应不同通知，不应视为同义方法。

`AppLifecycleScheduler` 是全局单例，`initialize()` 只会创建一次；需要释放时调用 `AppLifecycleScheduler.instance.dispose()`。空闲超时可通过 `aliveDuration` 设置时长，在应用启动和用户交互时调用 `updateAliveStatus()`，再用 `isAlive()` 检查。首次记录活跃时间之前，`isAlive()` 返回 `false`。

## AI 编码助手 skills

本包提供生命周期框架、屏幕保护和网络探测相关的 skills。在 Flutter 项目中添加本包依赖并运行 `flutter pub get` 后，从项目根目录运行以下命令，可为 VS Code 中的 GitHub Copilot 发现并选择安装：

```shell
dart run skills@ get -p app_lifecycle_protector --agent copilot
```

CLI 会将 skills 安装到 `.github/skills/`，这是 VS Code Copilot 的项目级 skills 目录。`skills` CLI 不会自动检测 Copilot，因此需要显式指定 `--agent copilot`。仅添加依赖或运行 `pub get` 不会自动安装 skills。

`-p app_lifecycle_protector` 会将发现范围限定为本包，但命令仍会显示交互式选择列表。要安装本包的全部三个 skills，请在列表中全选（例如按 `Ctrl+A`，再按 `Enter`）。如果只想安装本包的 skills，不要加 `--all`；该选项会安装所有依赖和已配置来源中可用的 skills。

安装后，在 VS Code 中打开项目并新建 Copilot Chat 会话。skills 应可在 `/` 菜单中找到；你可以直接调用某个 skill，也可以让 Copilot 根据请求尝试选择。能发现 skill 不代表每次相关请求都会自动触发它。

`skills` CLI 也支持其他常见编程助手。常用选项及其项目级 skills 目录如下：

| 编程助手 | 选项 | 项目级 skills 目录 |
| --- | --- | --- |
| Antigravity | `--agent antigravity` | `.agents/skills/` |
| Claude Code | `--agent claude` | `.claude/skills/` |
| Cline | `--agent cline` | `.cline/skills/` |
| OpenAI Codex | `--agent codex` | `.agents/skills/` |
| Cursor | `--agent cursor` | `.cursor/skills/` |
| GitHub Copilot | `--agent copilot` | `.github/skills/` |
| OpenCode | `--agent opencode` | `.opencode/skills/` |
| 通用 Agent Skills 客户端 | `--agent generic` | `.agents/skills/` |

为其他助手安装时，将命令中的 `copilot` 替换为对应选项值。支持列表可能更新，详见 [`skills` CLI 文档](https://pub.dev/packages/skills)。
