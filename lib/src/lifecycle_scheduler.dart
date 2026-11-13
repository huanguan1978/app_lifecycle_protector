import 'dart:async';
import 'dart:ui' show AppExitResponse;
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';

/// Abstract class to define lifecycle event handlers.
abstract class AppLifecycleEvent {
  bool _isInForeground = true;

  /// Whether the application is currently running in the foreground (visible).
  bool get isInForeground => _isInForeground;

  /// Whether the application is currently running in the background (hidden or minimized).
  bool get isInBackground => !_isInForeground;

  void onPeriodic() {}

  /// Called once after the configured user-interaction idle timeout.
  ///
  /// The timeout is independent of foreground/background state and is checked
  /// on the scheduler's periodic heartbeat.
  void onIdle() {}
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

  Future<AppExitResponse> onExitRequested() async {
    return AppExitResponse.exit;
  }
}

/// Manages periodic tasks aligned with the application's lifecycle.
class AppLifecycleScheduler {
  Timer? _timer;
  final Duration _interval;
  final AppLifecycleEvent _event;
  final Logger? _logger;
  AppLifecycleListener? _listener;

  /// User inactivity timeout and default duration used by [isAlive].
  Duration aliveDuration = const Duration(minutes: 3);
  DateTime? _aliveAt;
  DateTime _idleSince = DateTime.now();
  bool _idleEventDispatched = false;

  AppLifecycleScheduler._internal({
    required Duration interval,
    required AppLifecycleEvent event,
    Logger? logger,
  })  : _interval = interval,
        _event = event,
        _logger = logger {
    _initListener();
  }

  /// Whether the application is currently running in the foreground (visible).
  bool get isInForeground => _event.isInForeground;

  /// Whether the application is currently running in the background (hidden or minimized).
  bool get isInBackground => _event.isInBackground;

  void _initListener() {
    _listener = AppLifecycleListener(
      onShow: () {
        _logger?.finest(
            'AppLifecycle: onShow. Ensuring periodic timer is active.');
        _event._isInForeground = true;
        _start();
        _event.onShow();
      },
      onHide: () {
        _logger?.finest(
            'AppLifecycle: onHide. Keeping periodic timer running in background.');
        _event._isInForeground = false;
        // Keep the timer running while the app is in background until suspended or terminated.
        _event.onHide();
      },
      onDetach: () {
        _logger?.finest(
            'AppLifecycle: onDetach. Stopping periodic timer on app termination.');
        _stop();
        _event.onDetach();
      },
      onInactive: _event.onInactive,
      onPause: _event.onPause,
      onResume: () {
        _logger?.finest(
            'AppLifecycle: onResume. Ensuring periodic timer is active.');
        _start();
        _event.onResume();
      },
      onRestart: _event.onRestart,
      onExitRequested: () async {
        _logger
            ?.finest('AppLifecycle: onExitRequested. Stopping periodic timer.');
        _stop();
        return _event.onExitRequested();
      },
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
      _timer = Timer.periodic(_interval, (_) => _dispatchPeriodic());
    }
  }

  void _dispatchPeriodic() {
    _dispatchIdleIfNeeded();
    _event.onPeriodic();
  }

  void _dispatchIdleIfNeeded() {
    if (_idleEventDispatched ||
        DateTime.now().difference(_idleSince) < aliveDuration) {
      return;
    }

    _idleEventDispatched = true;
    _logger?.finest('AppLifecycle: onIdle. No user interaction timed out.');
    _event.onIdle();
  }

  void _stop() {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
      _timer = null;
      _logger?.finest('Periodic task stopped.');
    }
  }

  bool timerIsActive() => _timer?.isActive ?? false;

  DateTime aliveAtNow() {
    final now = DateTime.now();
    _aliveAt = now;
    _idleSince = now;
    _idleEventDispatched = false;
    return now;
  }

  bool isAlive([Duration? duration]) {
    final lastAlive = _aliveAt;
    if (lastAlive == null) return false;
    final isAlive =
        DateTime.now().difference(lastAlive) < (duration ?? aliveDuration);
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
