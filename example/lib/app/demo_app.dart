import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:app_lifecycle_protector/app_lifecycle_protector.dart';

import '../features/network_prober/network_probe_demo.dart';
import '../features/screen_secure/screen_secure_demo.dart';
import '../framework/demo_lifecycle_event.dart';
import '../pages/demo_home_page.dart';
import '../pages/network_probe_page.dart';
import '../pages/screen_secure_page.dart';
import '../shared/demo_log_buffer.dart';
import 'demo_routes.dart';

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  late final DemoLogBuffer _logs;
  late final ScreenSecureDemo _screenSecureDemo;
  late final RouteSentry _routeSentry;
  late final NetworkProbeDemo _networkProbeDemo;

  @override
  void initState() {
    super.initState();

    _logs = DemoLogBuffer();
    _screenSecureDemo = ScreenSecureDemo(onLog: _logs.add);
    _routeSentry = RouteSentry(
      monitoredRoutes: const {DemoRoutes.networkProbe},
    );
    _networkProbeDemo = NetworkProbeDemo(
      routeSentry: _routeSentry,
      onLog: _logs.add,
    );

    AppLifecycleScheduler.initialize(
      interval: const Duration(seconds: 5),
      event: DemoLifecycleEvent(
        screenSecureDemo: _screenSecureDemo,
        networkProbeDemo: _networkProbeDemo,
        onLog: _logs.add,
      ),
      logger: Logger('ExampleScheduler'),
    );
    AppLifecycleScheduler.instance.aliveDuration = const Duration(seconds: 60);

    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  bool _handleKeyEvent(KeyEvent event) {
    AppLifecycleScheduler.instance.updateAliveStatus();
    return false;
  }

  void _handleUnlocked() {
    _screenSecureDemo.screenSecure.unlock();
    AppLifecycleScheduler.instance.updateAliveStatus();
    _logs.add('App unlocked; idle timer refreshed.');
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    AppLifecycleScheduler.instance.dispose();
    _networkProbeDemo.dispose();
    _screenSecureDemo.dispose();
    _routeSentry.dispose();
    _logs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => AppLifecycleScheduler.instance.updateAliveStatus(),
      child: MaterialApp(
        title: 'App Lifecycle Protector Demo',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.blue,
        ),
        initialRoute: DemoRoutes.home,
        navigatorObservers: [_routeSentry],
        routes: {
          DemoRoutes.home: (context) => DemoHomePage(
                screenSecureDemo: _screenSecureDemo,
                networkProbeDemo: _networkProbeDemo,
                logs: _logs,
              ),
          DemoRoutes.screenSecure: (context) => ScreenSecurePage(
                screenSecureDemo: _screenSecureDemo,
              ),
          DemoRoutes.networkProbe: (context) => NetworkProbePage(
                networkProbeDemo: _networkProbeDemo,
              ),
        },
        builder: (context, child) {
          return ScreenProtector(
            screenSecure: _screenSecureDemo.screenSecure,
            lockWidget: _screenSecureDemo.buildLockWidget(
              onUnlocked: _handleUnlocked,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
