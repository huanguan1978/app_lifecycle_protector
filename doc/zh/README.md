# App Lifecycle Protector (中文版)

`app_lifecycle_protector` 是一个专为 Flutter 开发者设计的**增强型生命周期管理与业务逻辑调度中心**。

虽然它提供了开箱即用的隐私遮罩与安全锁屏功能，但其更深层级的价值在于：它提供了一套**事件驱动的架构**，让你可以将任何复杂的业务逻辑（不仅是安全逻辑）与应用的生命周期状态实现深度、声明式的绑定。

## 🌟 核心价值

在开发复杂应用时，逻辑往往散落在各个 Widget 的生命周期回调中，导致代码碎片化且难以维护。本工具包通过以下机制解决这一痛点：

### 1. 全生命周期 `onPeriodic` 调度与前后台状态自感知
这是本工具包的核心特色。不同于普通的 `Timer`，`onPeriodic` 任务**在应用整个活跃生命周期内持续周期性运行**（直至系统挂起或应用被退出）：
*   **前后台自感知**：内置只读属性 `isInForeground` 与 `isInBackground`，让开发者能自由精细化控制“哪些逻辑只在前台跑，哪些逻辑在后台也持续跑”。
*   **全场景防御**：即使应用处于后台或最小化，空闲超时巡检依然生效，超时可在后台主动完成加锁，杜绝切回前台时发生内容露底；同时在切回前台时具备自动保活机制。

### 2. 事件驱动的逻辑解耦
通过继承 `AppLifecycleEvent`，你可以将逻辑从 UI 树中彻底解耦：
*   **架构清晰**：不再需要在多个页面重复监听 `didChangeAppLifecycleState`。
*   **全量钩子**：除了 `onResume/onPause`，还支持 `onShow/onHide`、`onRestart` 以及 `onExitRequested` 等精细化控制。
*   **优雅退出处理**：覆盖 `onExitRequested()` 可拦截应用关闭，在退出前执行清理逻辑，例如关闭数据库连接、保存配置和缓存。

---

## 🛠️ 四大核心应用场景

| 场景 | 描述 |
| :--- | :--- |
| **通用业务调度** | 借助 `isInForeground` 与 `isInBackground`，灵活配置前台高频任务（如 API 轮询、UI 刷新）与后台轻量任务（状态同步、缓存维护），实现精准的“按需运行”。 |
| **空闲超时保护** | 基于 `onPeriodic` 与 `isAlive()` 机制，在用户长时间无交互后自动触发安全加锁，后台超时直接在后台静默上锁。 |
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
    // 1. 【全周期安全巡检】前台与后台均周期性检查
    // 示例：检查用户是否已闲置超过 5 分钟，后台超时直接在后台加锁
    if (!AppLifecycleScheduler.instance.isAlive()) {
      screenSecure.lock(); 
    }
    
    // 2. 【按需前台业务】仅在前台可见时运行，避免后台无谓消耗电量和网络
    if (isInForeground) {
      print("应用处于前台，执行前台数据刷新或维持心跳...");
    }

    // 3. 【可选后台任务】仅在后台时执行轻量逻辑
    if (isInBackground) {
      // 例如：记录后台持续时长或暂存未提交数据
    }
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

| 类/方法/属性 | 说明 |
| :--- | :--- |
| `AppLifecycleScheduler` | 全局单例，管理全周期定时调度与生命周期分发中心。 |
| `AppLifecycleEvent` | 事件处理器基类，包含 `onPeriodic`、前后台状态感知及所有系统级生命周期回调。 |
| `isInForeground` / `isInBackground` | `AppLifecycleEvent` 与 `AppLifecycleScheduler` 上的只读属性，指示当前应用是否处于前台（可见）或后台（隐藏）。 |
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
- **通过爱发电赞助 (中国大陆)**：中国大陆的用户也可以通过 [爱发电 (Ifdian)](https://ifdian.net/a/huanguan1978) 表达您的支持。

*感谢您的支持，这是让我能够专注于项目持续迭代的核心动力；因为有您，更多人能更早地从这个工具中受益。*

## 📄 开源协议
MIT License.
