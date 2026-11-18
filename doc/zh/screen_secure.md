# 屏幕保护：ScreenSecure 与 ScreenProtector

本文详细介绍如何使用 `ScreenSecure` 管理遮罩与锁定状态，并用 `ScreenProtector` 将状态呈现到 Flutter 界面。示例进一步演示如何结合生命周期事件、用户交互追踪和认证界面；认证逻辑需要由应用自行接入。

## 💡 核心实现思路

1.  **全局状态**：实例化 `ScreenSecure` 以驱动 UI 层的遮罩与锁屏。
2.  **生命周期逻辑**：继承 `AppLifecycleEvent`，在 `onPeriodic` 中巡检闲置状态，在 `onPause`/`onResume` 中切换遮罩。
3.  **交互捕获**：结合 `Listener`（指针事件）与 `HardwareKeyboard`（硬件按键）实现多维度交互监听，确保用户活跃时实时刷新状态。
4.  **UI 层级**：使用 `ScreenProtector` 封装业务页面，根据状态自动叠加保护层。

---

## 🚀 完整代码示例

你可以直接参考或复制以下代码块到你的项目中。

### 1. 定义安全事件处理器
这是应用的安全大脑，负责所有状态转换逻辑。

```dart
import 'package:app_lifecycle_protector/app_lifecycle_protector.dart';

class MySecurityHandler extends AppLifecycleEvent {
  final ScreenSecure screenSecure;

  MySecurityHandler(this.screenSecure);

  @override
  void initialize() {
    super.initialize();
    AppLifecycleScheduler.instance.updateAliveStatus();
  }

  @override
  void onPeriodic() {
    // 由调度器按设定周期触发；应用在后台时也可能被操作系统挂起
    final scheduler = AppLifecycleScheduler.instance;

    // 如果用户闲置时间超过配置的 aliveDuration，自动锁屏
    if (!scheduler.isAlive()) {
      screenSecure.lock();
    }

    // 结合 isInForeground / isInBackground，按需执行前后台特定逻辑
    if (isInForeground) {
      // 仅前台执行的轻量业务...
    }
  }

  @override
  void onPause() {
    // 当应用准备切入后台（如打开任务管理器），显示防窥遮罩
    screenSecure.mask();
  }

  @override
  void onResume() {
    // 当应用回到前台，解除防窥遮罩
    screenSecure.unmask();
  }
}
```

### 2. 模拟生物识别校验器
在实际项目中，你可以配合 `local_auth` 包来实现此接口。

```dart
class MockBiometricValidator implements BiometricValidator {
  @override
  Future<bool> canAuthenticate() async => true; // 模拟支持指纹/面容

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    // 模拟认证过程
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }
}
```

### 3. 应用入口与 UI 组装 (局部应用模式)
展示如何对特定页面（如首页）进行保护。请注意，此模式下保护仅适用于 `ScreenProtector` 下方的组件。

```dart
import 'package:flutter/material.dart';
import 'package:app_lifecycle_protector/app_lifecycle_protector.dart';

// 全局安全状态管理
final ScreenSecure screenSecure = ScreenSecure();

void main() {
  // 必须：确保 Flutter 绑定已初始化
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // 1. 初始化生命周期调度器
    AppLifecycleScheduler.initialize(
      interval: const Duration(seconds: 3), // 每 3 秒巡检一次
      event: MySecurityHandler(screenSecure),
    );

    // 2. 设置闲置超时时长为 5 分钟
    AppLifecycleScheduler.instance.aliveDuration = const Duration(minutes: 5);
  }

  @override
  void dispose() {
    AppLifecycleScheduler.instance.dispose();
    super.dispose();
  }

  void _handleUnlocked() {
    screenSecure.unlock();
    // 重要：解锁后务必刷新活跃状态，否则下一次巡检会因为超时立刻再次锁屏
    AppLifecycleScheduler.instance.updateAliveStatus();
  }

  @override
  Widget build(BuildContext context) {
    return UserInteractionListener(
      child: MaterialApp(
        title: 'Security App',
        home: Builder(
          builder: (context) {
            // 构建授权界面
            final lockWidget = BiometricLockScreen(
              validator: MockBiometricValidator(),
              onUnlocked: _handleUnlocked,
              fallback: PassphraseLockScreen(
                onValidate: (pw, _) => pw == "123456" ? null : "密码错误",
                onUnlocked: _handleUnlocked,
              ),
            );

            // 使用保护器包裹业务主页
            return ScreenProtector(
              screenSecure: screenSecure,
              lockWidget: lockWidget,
              // maskWidget: MyCustomMask(), // 可选：自定义防窥遮罩
              child: const MyHomePage(),
            );
          },
        ),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("隐私数据中心")),
      body: const Center(child: Text("这里是只有授权后才能看到的敏感内容")),
    );
  }
}
```

---

## 📌 关键点拨

### 如何精准捕获用户交互？
为了防止用户在活跃使用（如阅读、输入）时被误判为闲置，本包提供了 **`UserInteractionListener`** 工具类，可统一管理所有用户交互的捕获。这是推荐的做法：

```dart
MaterialApp(
  home: UserInteractionListener(
    child: MyHomePage(),
  ),
)
```

`UserInteractionListener` 一次性覆盖以下交互类型：
*   **触摸/鼠标**：所有指针事件（点击、滑动、移动等）
*   **硬件键盘**：所有物理按键输入
*   **滚动事件**：列表滚动、页面滑动等

如果你不使用 `UserInteractionListener`，也可手动组装多种交互监听器。下面是底层的详细方法（作为参考）：

<details>
<summary><b>展开：手动组装多种交互监听器（仅供参考，推荐使用 UserInteractionListener）</b></summary>

通过组合以下几种方式可以捕获各类交互：
*   **触摸/鼠标**：根级别 `Listener` 覆盖了所有点击、滑动等指针事件。
*   **硬件键盘**：用 `HardwareKeyboard.addHandler` 覆盖物理按键输入。
*   **软件键盘（特殊处理）**：由于系统软键盘的按键点击不属于指针事件，**编辑器类应用**应在 `TextField.onChanged` 中手动刷新状态：
  ```dart
  TextField(
    onChanged: (_) => AppLifecycleScheduler.instance.updateAliveStatus(),
  )
  ```

如果采用手动方式，代码示例如下：
```dart
class _MyAppState extends State<MyApp> {
  bool _handleKeyEvent(KeyEvent event) {
    AppLifecycleScheduler.instance.updateAliveStatus();
    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => AppLifecycleScheduler.instance.updateAliveStatus(),
      child: MaterialApp(
        // 应用配置...
      ),
    );
  }
}
```

</details>

### 如何立即加锁？
在某些场景下（如用户手动点击“安全退出”），你可以直接调用：
```dart
screenSecure.lock();
```

### 如何自定义保护界面？
`ScreenProtector` 提供了 `maskWidget` 和 `lockWidget` 槽位。如果你不提供，它将使用内置的默认样式：
*   **默认遮罩**：深灰色背景 + 隐私图标。
*   **默认锁屏**：黑色背景 + "App Locked" 文字。

`ScreenProtector` 是 Flutter 界面层的遮罩与锁屏展示，不负责身份认证，也不等同于系统级截屏或录屏防护；需要这些能力时，应由应用另行接入认证和平台能力。

### 建议配合的辅助包
*   **[local_auth](https://pub.dev/packages/local_auth)**: 用于真实的生物识别。
*   **[no_screenshot](https://pub.dev/packages/no_screenshot)**: 禁止系统层级的截屏和录屏，与本包的遮罩功能互补。
