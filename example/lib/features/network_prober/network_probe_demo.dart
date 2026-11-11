import 'dart:async';

import 'package:app_lifecycle_protector/app_lifecycle_protector.dart';
import 'package:flutter/foundation.dart';

class NetworkProbeDemo extends ChangeNotifier {
  NetworkProbeDemo({
    required RouteSentry routeSentry,
    required this.onLog,
  })  : _routeSentry = routeSentry,
        _prober = NetworkProber() {
    _routeSentry.addListener(_handleRouteChange);
    _prober.statusNotifier.addListener(_handleStatusChange);
  }

  final RouteSentry _routeSentry;
  final NetworkProber _prober;
  final void Function(String message) onLog;

  bool _hasProbeResult = false;
  bool _isChecking = false;
  bool? _lastProbeResult;
  Object? _probeError;
  int _tick = 0;
  bool _isDisposed = false;

  bool get isMonitoringRoute => _routeSentry.value;
  bool get hasProbeResult => _hasProbeResult;
  bool get isChecking => _isChecking;
  bool? get lastProbeResult => _lastProbeResult;
  Object? get probeError => _probeError;
  String? get proxyAddress => _proxyAddress;
  Uri get probeUri => NetworkProber.defaultProbeUri;

  String? _proxyAddress;

  void _handleRouteChange() {
    _tick = 0;
    notifyListeners();
    if (_routeSentry.value) {
      onLog('[NetworkProber] Entered the monitored route. Checking endpoint.');
      unawaited(checkNow());
    }
  }

  void _handleStatusChange() {
    onLog('[NetworkProber] Status changed: ${_prober.status.name}.');
    notifyListeners();
  }

  void onPeriodic({required bool isInForeground}) {
    if (!isInForeground || !_routeSentry.value) {
      _tick = 0;
      return;
    }

    _tick++;
    final shouldCheck = _prober.isDisconnected || _tick % 4 == 0;
    if (shouldCheck) {
      unawaited(checkNow());
    }
  }

  void onResume({required bool isInForeground}) {
    if (isInForeground && _routeSentry.value) {
      onLog('[NetworkProber] App resumed on the monitored route.');
      unawaited(checkNow());
    }
  }

  Future<void> checkNow({bool force = false}) async {
    if (_isDisposed || _isChecking) return;

    _isChecking = true;
    _probeError = null;
    notifyListeners();
    try {
      final result = await _prober.checkConnectivity(force: force);
      if (_isDisposed) return;
      _lastProbeResult = result;
      _hasProbeResult = true;
      onLog(
        '[NetworkProber] Endpoint ${_lastProbeResult! ? 'reachable' : 'unreachable'}.',
      );
    } on Exception catch (error) {
      if (_isDisposed) return;
      _probeError = error;
      onLog('[NetworkProber] Probe failed with an error: $error');
    } finally {
      if (!_isDisposed) {
        _isChecking = false;
        notifyListeners();
      }
    }
  }

  Future<void> updateProxy(String? hostPort) async {
    final normalizedHostPort = hostPort?.trim();
    _proxyAddress = normalizedHostPort == null || normalizedHostPort.isEmpty
        ? null
        : normalizedHostPort;
    _prober.updateProxy(_proxyAddress);
    onLog(
      _proxyAddress == null
          ? '[NetworkProber] Proxy disabled; using a direct connection.'
          : '[NetworkProber] Proxy configured: $_proxyAddress.',
    );
    notifyListeners();
    await checkNow(force: true);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _routeSentry.removeListener(_handleRouteChange);
    _prober.statusNotifier.removeListener(_handleStatusChange);
    _prober.dispose();
    super.dispose();
  }
}
