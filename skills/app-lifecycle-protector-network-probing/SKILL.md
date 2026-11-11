---
name: app-lifecycle-protector-network-probing
description: "Use when checking endpoint reachability or displaying network status in a Flutter app with app_lifecycle_protector, including NetworkProber, RouteSentry, probe configuration, and lifecycle-driven checks."
---

# App Lifecycle Protector: Network Probing

Use this skill to check whether a configured HTTP endpoint can be reached.
Start with a one-shot check; add configuration and scheduling only when the
application needs them.

## 1. Start with a one-shot check

Use `NetworkProber` to check its configured endpoint and dispose it when its
owner is finished:

```dart
final prober = NetworkProber();
try {
  final isReachable = await prober.checkConnectivity();
  if (!isReachable) {
    // Show or handle the unavailable state.
  }
} finally {
  prober.dispose();
}
```

Import `package:app_lifecycle_protector/app_lifecycle_protector.dart`. The
default endpoint is Apple's captive-portal check URL; for a service-specific
health check, configure `checkUri` or call `probeUri()` with the endpoint
that represents the service the app needs.

`NetworkProber` starts with `NetworkStatus.connected` before a check has
completed. Do not interpret that initial value as a successful probe; call
`checkConnectivity()` first. A successful HTTP probe indicates reachability
of its target, not that every API or network service is healthy.

## 2. Tune existing behavior

- Configure `checkUri` for the target to monitor and `fallbackUris` if a
  fallback endpoint is useful.
- Configure `timeout` for each connection/read attempt and `minInterval` to
  limit repeat successful probes. `checkConnectivity(force: true)` bypasses
  the successful-result interval.
- Use `statusNotifier` with `ValueListenableBuilder` or `onStatusChanged` to
  update UI or app state.
- Use `probeUri()` to test another endpoint with the instance's proxy,
  certificate, and timeout settings. Use `NetworkProber.probe()` for a
  standalone one-off URI check.
- Add `RouteSentry` when checks should be associated with named routes. It
  reports whether the current route is monitored and can trigger a check on
  entry when attached to a prober. It does not prevent application code from
  explicitly calling the prober on an unmonitored route.

## 3. Prefer this package's framework for periodic checks

`NetworkProber` does not run a periodic loop by itself. When recurring checks
should follow app lifecycle or route state, prefer
`AppLifecycleScheduler` and `AppLifecycleEvent` rather than creating a second
timer:

```dart
import 'dart:async';

class NetworkEvents extends AppLifecycleEvent {
  NetworkEvents(this.prober, this.routeSentry);

  final NetworkProber prober;
  final RouteSentry routeSentry;

  @override
  void onPeriodic() {
    if (isInForeground && routeSentry.value) {
      unawaited(prober.checkConnectivity());
    }
  }
}
```

Add `routeSentry` to `MaterialApp.navigatorObservers`, and initialize the
scheduler after Flutter binding initialization:

```dart
final routeSentry = RouteSentry(monitoredRoutes: {'/status'});
final prober = NetworkProber();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppLifecycleScheduler.initialize(
    interval: const Duration(seconds: 5),
    event: NetworkEvents(prober, routeSentry),
  );
  runApp(const MyApp());
}
```

In `MyApp`, pass `routeSentry` through `MaterialApp.navigatorObservers`.
Use named routes that match `monitoredRoutes`. Choose the scheduler interval
and probe `minInterval` together to avoid unnecessary requests. If the app
already has an appropriate scheduler, keep it and invoke the prober from that
existing mechanism instead.

The route sentry is a condition for the caller's scheduling policy, not a
global guard: check `routeSentry.value` before invoking a scheduled probe if
unmonitored routes should stay quiet. Avoid attaching it to auto-trigger
checks and also scheduling overlapping checks unless both behaviors are
intentional.

## 4. Build application-specific monitoring last

After the basic probe and scheduling behavior are correct, add app-specific
retry policy, service health rules, connectivity UI, or coordination with
business operations. Treat probe status as a signal, not proof that a
subsequent request will succeed; the network may change between the probe and
the operation.

Dispose owned `NetworkProber` and `RouteSentry` objects with their owning
scope. A lifecycle timer can be delayed when the operating system suspends the
app, so do not rely on it for exact background monitoring.
