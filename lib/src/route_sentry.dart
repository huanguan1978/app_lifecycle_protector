import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A lightweight, zero-third-party-dependency route observer and sentry.
///
/// Implements [ValueListenable<bool>] and extends [NavigatorObserver] to monitor route
/// transitions against a set of monitored route names and notify listeners (such as
/// `NetworkProber`) when entering or exiting monitored pages.
class RouteSentry extends NavigatorObserver implements ValueListenable<bool> {
  /// Creates a [RouteSentry] with a set of [monitoredRoutes].
  RouteSentry({required Set<String> monitoredRoutes})
      : _monitoredRoutes = monitoredRoutes;

  final Set<String> _monitoredRoutes;
  final ValueNotifier<bool> _notifier = ValueNotifier<bool>(false);

  /// The set of route names being actively monitored.
  Set<String> get monitoredRoutes => Set.unmodifiable(_monitoredRoutes);

  @override
  bool get value => _notifier.value;

  @override
  void addListener(VoidCallback listener) => _notifier.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _notifier.removeListener(listener);

  void _syncRoute(Route<dynamic>? route) {
    final routeName = route?.settings.name;
    final isMonitored =
        routeName != null && _monitoredRoutes.contains(routeName);
    if (_notifier.value != isMonitored) {
      _notifier.value = isMonitored;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _syncRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _syncRoute(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _syncRoute(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _syncRoute(previousRoute);
  }

  /// Disposes the underlying notifier.
  void dispose() {
    _notifier.dispose();
  }
}
