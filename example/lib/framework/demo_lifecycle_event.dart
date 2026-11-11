import 'package:app_lifecycle_protector/app_lifecycle_protector.dart';

import '../features/network_prober/network_probe_demo.dart';
import '../features/screen_secure/screen_secure_demo.dart';

class DemoLifecycleEvent extends AppLifecycleEvent {
  DemoLifecycleEvent({
    required this.screenSecureDemo,
    required this.networkProbeDemo,
    required this.onLog,
  });

  final ScreenSecureDemo screenSecureDemo;
  final NetworkProbeDemo networkProbeDemo;
  final void Function(String message) onLog;

  @override
  void initialize() {
    super.initialize();
    AppLifecycleScheduler.instance.updateAliveStatus();
    onLog('Lifecycle scheduler initialized.');
  }

  @override
  void onPeriodic() {
    final scheduler = AppLifecycleScheduler.instance;
    final alive = scheduler.isAlive();
    final foreground = isInForeground;
    onLog(
      '[Framework] onPeriodic: '
      '${foreground ? 'foreground' : 'background'}, '
      'user active: $alive.',
    );

    screenSecureDemo.onPeriodic(isAlive: alive);
    networkProbeDemo.onPeriodic(isInForeground: foreground);
  }

  @override
  void onPause() {
    onLog('[Framework] onPause.');
    screenSecureDemo.onPause();
  }

  @override
  void onResume() {
    onLog('[Framework] onResume.');
    screenSecureDemo.onResume();
    networkProbeDemo.onResume(isInForeground: isInForeground);
  }

  @override
  void onShow() {
    onLog('[Framework] onShow.');
  }

  @override
  void onHide() {
    onLog('[Framework] onHide.');
  }

  @override
  void onInactive() {
    onLog('[Framework] onInactive.');
  }

  @override
  void onRestart() {
    onLog('[Framework] onRestart.');
  }

  @override
  void onDetach() {
    onLog('[Framework] onDetach.');
  }

  @override
  void dispose() {
    onLog('[Framework] Lifecycle event disposed.');
  }
}
