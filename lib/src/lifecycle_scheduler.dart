import 'dart:async';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';

/// Abstract class to define lifecycle event handlers.
abstract class AppLifecycleEvent {
  void onPeriodic() {}
  void initialize() {}
  void dispose() {}

  void onShow() {}
  void onHide() {}
  void onInactive() {}
  void onDetach() {}

  void onPause() {}
  void onResume() {}
  void onRestart() {}

  void onStateChange(AppLifecycleState state) {}
  AppExitRequestCallback? onExitRequested;
}

/// Manages periodic tasks aligned with the application's lifecycle.
class AppLifecycleScheduler {
  Timer? _timer;
  final Duration _interval;
  final AppLifecycleEvent _event;
  final Logger? _logger;
  AppLifecycleListener? _listener;

  Duration aliveDuration = const Duration(minutes: 3);
  DateTime? _aliveAt;

  AppLifecycleScheduler._internal({
    required Duration interval,
    required AppLifecycleEvent event,
    Logger? logger,
  })  : _interval = interval,
        _event = event,
        _logger = logger {
    _initListener();
  }

  void _initListener() {
    _listener = AppLifecycleListener(
      onShow: () {
        _logger?.finest('AppLifecycle: onShow. Starting periodic timer.');
        _start();
        _event.onShow();
      },
      onHide: () {
        _logger?.finest('AppLifecycle: onHide. Stopping periodic timer.');
        _stop();
        _event.onHide();
      },
      onDetach: () {
        _logger?.finest('AppLifecycle: onDetach. Stopping periodic timer.');
        _stop();
        _event.onDetach();
      },
      onInactive: _event.onInactive,
      onPause: _event.onPause,
      onResume: _event.onResume,
      onRestart: _event.onRestart,
      onExitRequested: _event.onExitRequested,
      onStateChange: _event.onStateChange,
    );
  }

  static AppLifecycleScheduler? _instance;

  static void initialize({
    required Duration interval,
    required AppLifecycleEvent event,
    Logger? logger,
  }) {
    if (_instance == null) {
      _instance = AppLifecycleScheduler._internal(
        interval: interval,
        event: event,
        logger: logger,
      );
      event.initialize();
      instance._start();
    }
  }

  static AppLifecycleScheduler get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError('AppLifecycleScheduler not initialized.');
    }
    return instance;
  }

  void dispose() {
    _listener?.dispose();
    _listener = null;
    _stop();
    _instance = null;
    _event.dispose();
    _logger?.finest('AppLifecycleScheduler disposed.');
  }

  void _start() {
    if (_timer == null || !_timer!.isActive) {
      _logger?.finest('Periodic task started.');
      _timer = Timer.periodic(_interval, (_) => _event.onPeriodic());
    }
  }

  void _stop() {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
      _timer = null;
      _logger?.finest('Periodic task stopped.');
    }
  }

  bool timerIsActive() => _timer?.isActive ?? false;

  DateTime aliveAtNow() => _aliveAt = DateTime.now();

  bool isAlive([Duration? duration]) {
    final lastAlive = _aliveAt;
    if (lastAlive == null) return false;
    final isAlive = DateTime.now().difference(lastAlive) < (duration ?? aliveDuration);
    _logger?.finest('Monitor task isAlive: $isAlive');
    return isAlive;
  }
}

/// Semantic extensions for AppLifecycleScheduler.
extension AppLifecycleSchedulerExtension on AppLifecycleScheduler {
  /// Update the last alive timestamp to the current time.
  /// Call this on user interaction (e.g., in a Listener widget).
  void updateAliveStatus() => aliveAtNow();
}
