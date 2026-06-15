# App Lifecycle Protector (中文版)

`app_lifecycle_protector` 是一个专为 Flutter 开发者设计的**增强型生命周期管理与业务逻辑调度中心**。

虽然它提供了开箱即用的隐私遮罩与安全锁屏功能，但其更深层级的价值在于：它提供了一套**事件驱动的架构**，让你可以将任何复杂的业务逻辑（不仅是安全逻辑）与应用的生命周期状态实现深度、声明式的绑定。

## 🌟 核心价值

在开发复杂应用时，逻辑往往散落在各个 Widget 的生命周期回调中，导致代码碎片化且难以维护。本工具包通过以下机制解决这一痛点：

### 1. `onPeriodic` 增强型巡检机制
这是本工具包的灵魂。不同于普通的 `Timer`，`onPeriodic` 任务**仅在应用可见（Visible）时触发**：
*   **资源友好**：当应用切入后台或隐藏时，巡检会自动静默，停止不必要的 CPU 和网络消耗。
*   **智能场景**：完美适用于“仅在使用时维持心跳”、“空闲超时自动锁屏”、“定时清理敏感缓存”等场景。

### 2. 事件驱动的逻辑解耦
通过继承 `AppLifecycleEvent`，你可以将逻辑从 UI 树中彻底解耦：
*   **架构清晰**：不再需要在多个页面重复监听 `didChangeAppLifecycleState`。
*   **全量钩子**：除了 `onResume/onPause`，还支持 `onShow/onHide`、`onRestart` 以及 `onExitRequested` 等精细化控制。

---

## 🛠️ 四大核心应用场景

| 场景 | 描述 |
| :--- | :--- |
| **通用业务调度** | 仅在可见时开启**前台定时任务（如 API 调用及结果分发）**、网络连接检测以及自动化数据管理（清理、刷新、拉取等），实现真正的“按需运行”。 |
| **空闲超时保护** | 基于 `onPeriodic` 与 `isAlive()` 机制，在用户长时间无交互后自动触发安全加锁。 |
| **隐私快照遮罩** | 在多任务切换界面自动覆盖隐私层，防止敏感数据通过系统快照泄露。 |
| **冷启动授权** | 确保用户在接触到敏感数据前，必须先完成身份验证（生物识别或密码）。 |

---

## 🚀 快速上手

### 步骤 1: 定义业务逻辑处理器
继承 `AppLifecycleEvent`，根据需求覆盖对应方法。你可以将安全逻辑与通用业务逻辑写在一起：

```dart
class MyLogicHandler extends AppLifecycleEvent {
  final ScreenSecure screenSecure;

  MyLogicHandler(this.screenSecure);

  @override
  void onPeriodic() {
    // 【增强型巡检】仅在应用可见时，每 10 秒执行一次
    // 示例：检查用户是否已闲置超过 5 分钟
    if (!AppLifecycleScheduler.instance.isAlive()) {
      screenSecure.lock(); 
    }
    
    // 也可以执行非安全逻辑，如：维持心跳
    print("应用活跃中，执行业务巡检...");
  }

  @override
  void onPause() {
    // 应用切后台，立即显示防窥遮罩
    screenSecure.mask();
  }

  @override
  void onResume() {
    // 应用回前台，解除遮罩
    screenSecure.unmask();
  }
}
```

### 步骤 2: 在根组件中初始化
**最佳实践**：在应用根组件（如 `MyApp`）的 `initState` 中进行配置。这样可以确保调度器与应用生命周期同步，且在 `MaterialApp` 构建前完成准备工作。

```dart
class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    
    // 1. 初始化调度中心（此时 WidgetsBinding 已就绪）
    AppLifecycleScheduler.initialize(
      interval: const Duration(seconds: 10),
      event: MyLogicHandler(screenSecure),
    );
    
    // 2. 配置参数（如闲置超时时长）
    AppLifecycleScheduler.instance.aliveDuration = const Duration(minutes: 5);
    
    // 3. 可选：如果需要冷启动立即加锁
    screenSecure.lock();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
       // ...
    );
  }
}
```

### 步骤 3: 集成 UI 保护器

#### 方案 A: 全应用保护 (推荐)
若要保护应用内的所有页面，请在 `MaterialApp.builder` 中包裹 `Navigator`。

```dart
MaterialApp(
  builder: (context, child) {
    return ScreenProtector(
      screenSecure: screenSecure,
      lockWidget: MyLockScreen(),
      child: child!, // 保护整个导航栈
    );
  },
  home: MyHomePage(),
)
```

#### 方案 B: 局部应用 (单页面)
仅包裹特定页面（不保护弹出的后续页面）。

```dart
ScreenProtector(
  screenSecure: screenSecure,
  lockWidget: MyLockScreen(),
  child: MyHomePage(),
)
```

---

## 🔧 核心 API 说明

| 类/方法 | 说明 |
| :--- | :--- |
| `AppLifecycleScheduler` | 全局单例，管理定时巡检与生命周期分发中心。 |
| `AppLifecycleEvent` | 事件处理器基类，包含 `onPeriodic` 及所有系统级生命周期回调。 |
| `ScreenSecure` | 状态管理类，控制 `isMasked`（防窥遮罩）与 `isLocked`（安全加锁）。 |
| `ScreenProtector` | UI 组件，通过 `Stack` 自动处理 UI 的叠加与显示逻辑。 |
| `updateAliveStatus()` | 更新最后一次活跃时间戳。建议在全局 `Listener` 的 `onPointerDown` 中调用。 |

---

## 🤝 与第三方包协同建议

为了获得极致的安全体验，我们建议：
1.  **防截屏**：使用 [no_screenshot](https://pub.dev/packages/no_screenshot) 禁止系统截屏和录屏。
2.  **本地存储**：结合 `shared_preferences` 持久化用户的锁屏配置。

---

## 💡 进阶指南
想要深入理解示例背后的逻辑设计与最佳实践？请阅读我们的 [实现指南 (EXAMPLE.md)](EXAMPLE.md)。

---

### 支持本项目 💖

如果您觉得这个工具包对您的项目有所帮助，并希望看到它持续改进和演进，请考虑通过以下方式给予支持：

- **点亮认可**：在 GitHub 上点亮 **Star** 或在 pub.dev 上点击 **Like**。这不仅是对我的巨大鼓舞，也能让更多开发者发现并受益于这个工具。
- **赞助开发者 (全球)**：任何数额的支持，无论大小，都是对我工作的极大肯定。您可以通过 [GitHub Sponsors](https://github.com/sponsors/huanguan1978) 或 [Buy Me a Coffee](https://buymeacoffee.com/huanguan1978) 给予赞助。
- **通过爱发电赞助 (中国大陆)**：中国大陆的用户也可以通过 [爱发电 (Ifdian)](https://ifdian.net/a/huangaun1978) 表达您的支持。

*感谢您的支持，这是让我能够专注于项目持续迭代的核心动力；因为有您，更多人能更早地从这个工具中受益。*

## 📄 开源协议
MIT License.
