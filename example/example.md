# App Lifecycle Protector Example

This runnable Flutter app demonstrates two layers:

1. The lifecycle framework: `AppLifecycleEvent` and
   `AppLifecycleScheduler`.
2. Features built with the framework: screen protection and network probing.

The source is split by responsibility so you can follow how the framework is
connected to feature logic and then to the UI.

## Run the app

From the package's `example` directory:

```shell
flutter run
```

The app starts with the screen locked. Choose **Use Alternate Method** after
the simulated biometric check, then enter `123456`.

## How the example is assembled

The app creates **one** `AppLifecycleScheduler` with one
`DemoLifecycleEvent`. The event handler receives lifecycle callbacks and
periodic ticks, then coordinates both feature demos. Each feature does not
create its own scheduler.

```dart
AppLifecycleScheduler.initialize(
  interval: const Duration(seconds: 5),
  event: DemoLifecycleEvent(
    screenSecureDemo: screenSecureDemo,
    networkProbeDemo: networkProbeDemo,
    onLog: logs.add,
  ),
);
```

This shows the division of responsibility:

- `AppLifecycleEvent` is the application's handler for lifecycle callbacks
  such as `onResume`, `onPause`, and periodic `onPeriodic`.
- `AppLifecycleScheduler` listens to lifecycle changes and calls the handler
  on the configured interval.
- The feature classes decide what their feature should do when the handler
  forwards an event or tick.

The example's scheduler interval is 5 seconds and its idle timeout is 60
seconds so the behavior is easy to observe. These are demo settings, not
recommended production values.

## What you can try

### Screen protection

Open **Screen protection** to see the app-wide `ScreenProtector`, privacy
masking, manual locking, and idle-timeout locking. The biometric validator is a
mock that deliberately fails; choose the alternate method and enter `123456`
to unlock. Pointer and keyboard interactions refresh the activity timer.

This UI overlay demonstrates Flutter-level masking and locking. It does not
provide production authentication or operating-system screenshot protection.

### Network probe

Open **Network probe** to send an HTTP `HEAD` request to the configured probe
endpoint. The page shows **Not checked yet** until a request completes, then
shows whether the endpoint was reachable. It also provides a manual **Check
now** action.

The lifecycle handler schedules periodic probes only while the app is in the
foreground on the monitored network route. `RouteSentry` reports whether the
current named route is monitored; the app's event handler uses that information
to decide when to probe. It does not prevent other code from explicitly
calling the probe.

The result describes whether the configured endpoint responded successfully.
Choose an endpoint that represents the network or service your app needs; a
successful probe does not guarantee every other service is reachable.

## Platform network configuration

If a probe fails, check whether the endpoint is reachable from the device and
whether the packaged app is allowed to make outbound network connections.
Requirements depend on both platform and packaging:

| Platform or package | What to check |
| --- | --- |
| Android | Declare [`android.permission.INTERNET`](https://developer.android.com/develop/connectivity/network-ops/connecting) in the app manifest. It is a normal install-time permission. `ACCESS_NETWORK_STATE` is for reading connection state and is not required just to send HTTP requests. |
| macOS App Sandbox | Enable the [`com.apple.security.network.client`](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.client) entitlement for outgoing connections. This example includes it in both Debug/Profile and Release entitlements. |
| Flatpak | Grant network access to the sandbox, for example with the [`--share=network`](https://docs.flatpak.org/en/latest/sandbox-permissions.html) permission. |
| Snap | Ensure the [`network` interface](https://snapcraft.io/docs/reference/interfaces/network-interface/) is connected. |
| MSIX | Check the [package manifest and app trust level](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/app-capability-declarations). AppContainer apps and full-trust desktop apps have different capability requirements. |
| iOS | Ordinary HTTPS requests do not require a runtime network permission. Platform transport-security rules still apply, especially if using non-HTTPS endpoints. |

These are outbound network-access requirements. They are distinct from
permissions to inspect network-interface hardware: `NetworkProber` sends HTTP
requests and does not read hardware network state. Check the current platform
and store documentation for your exact deployment target.

## Using a proxy

`NetworkProber` supports configuring an HTTP proxy for its own requests. In the
demo, enter a proxy host and port, such as `127.0.0.1:8080`, and choose
**Apply proxy and check**. Choose **Use direct connection** to clear it.

The same API is available in application code:

```dart
final prober = NetworkProber();

prober.updateProxy('127.0.0.1:8080');
final reachable = await prober.checkConnectivity(force: true);

// Clear the proxy and use a direct connection.
prober.updateProxy(null);
```

A proxy can help when the probe endpoint is blocked by the current network, but
the proxy itself must be reachable and allowed by the platform. This setting
applies only to this `NetworkProber` instance; it does not configure other HTTP
clients or bypass platform network permissions. The prober tries the configured
proxy before falling back to a direct connection, so this is not a strict
proxy-only or traffic-tunneling setting.

## Source map

| Layer | Source | Responsibility |
| --- | --- | --- |
| App composition | [`lib/app/demo_app.dart`](lib/app/demo_app.dart) | Creates feature instances and the single scheduler; registers routes and disposes resources |
| Route names | [`lib/app/demo_routes.dart`](lib/app/demo_routes.dart) | Defines the named routes used by the app and `RouteSentry` |
| Framework demonstration | [`lib/framework/demo_lifecycle_event.dart`](lib/framework/demo_lifecycle_event.dart) | Logs framework events and forwards lifecycle work to feature demos |
| Screen-protection feature | [`lib/features/screen_secure/screen_secure_demo.dart`](lib/features/screen_secure/screen_secure_demo.dart) | Implements the demo's lock, mask, idle timeout, and mock validator |
| Network-probing feature | [`lib/features/network_prober/network_probe_demo.dart`](lib/features/network_prober/network_probe_demo.dart) | Configures the probe, route-aware schedule, status, and proxy |
| UI | [`lib/pages/`](lib/pages/) | Presents the home, screen-protection, and network-probe pages |
| App entry point | [`lib/main.dart`](lib/main.dart) | Configures logging and starts the demo |

To trace the integration, start at `lib/main.dart`, continue to
`lib/app/demo_app.dart` for composition, then follow
`lib/framework/demo_lifecycle_event.dart` into either feature implementation.
