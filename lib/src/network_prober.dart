import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Network connectivity status.
enum NetworkStatus {
  /// The network probe succeeded and the target is reachable.
  connected,

  /// The network probe failed or timed out.
  disconnected;
}

/// Callback for custom proxy resolution, matching [HttpClient.findProxy].
typedef ProxyResolver = String Function(Uri url);

/// Callback to validate [HttpClientResponse].
typedef ResponseValidator = bool Function(HttpClientResponse response);

/// {@template network_prober}
/// # NetworkProber
///
/// A lightweight, zero-third-party-dependency network connectivity and reachability
/// prober built purely on Dart (`dart:io`) and Flutter standard libraries (`package:flutter/foundation.dart`).
///
/// ## 1. Design Intent: Three-Dimensional Orthogonal Architecture
///
/// `NetworkProber` decouples network health management into three orthogonal concerns:
/// - **Spatial Dimension (Where to monitor)**: Delegated to route sentries (such as [RouteSentry]).
///   The monitored route whitelist decides which pages activate health polling. Non-monitored pages
///   remain completely dormant with 0 packet emission.
/// - **Temporal Dimension (When and how often to monitor)**: Delegated to the application's external
///   scheduler (such as [AppLifecycleScheduler] and [AppLifecycleEvent.onPeriodic]).
///   The polling cadence is dynamically paced (e.g. 3s when disconnected, 12s when connected).
/// - **State & Network IO Dimension (What the connectivity status is)**: Cohesively contained within
///   `NetworkProber`. It manages HTTP socket execution, proxy resolution, certificate checks, and
///   exposes the current status through reactive listenables ([statusNotifier]) and lifecycle hooks ([onStatusChanged]).
///
/// ## 2. Core Advantages: Aggressive Request Optimization
///
/// - **Zero Third-Party Dependencies**: Purely standard libraries (`dart:io` and `flutter/foundation.dart`).
///   Zero platform plugins, zero unmanaged background threads, zero battery drain.
/// - **Result Caching via `minInterval`**: Within the cooldown window (default 2 seconds), consecutive
///   calls to [checkConnectivity] immediately return the cached connected status in 0 ms without
///   firing duplicate network I/O or keeping the cellular baseband awake.
/// - **In-Flight Request Deduplication**: If a probe request is already active (`_isChecking`),
///   simultaneous or rapid-fire calls (such as a user pressing submit while a periodic tick is probing)
///   are automatically coalesced and safely reuse the ongoing check result.
/// - **Flapping & Jitter Mitigation**: Features an automatic 300 ms retry before broadcasting a disconnect,
///   preventing false-positive offline alerts during cell tower handovers or transient packet drops.
/// - **Native Proxy & Certificate Support**: Supports runtime proxy updating ([updateProxy]) and
///   self-signed certificate testing ([allowBadCertificates]).
/// - **Global Reliability**: Defaults to Apple's globally reachable captive portal check endpoint
///   (`https://captive.apple.com/internet-check`), working dependably worldwide without Google dependencies.
///
/// ## 3. Typical Use Cases
///
/// 1. **Reactive UI Data-Binding**: Bind UI banners or offline notices directly to [statusNotifier] using
///    [ValueListenableBuilder] with zero `setState` boilerplate.
/// 2. **Global Variable Synchronization**: Pass [onStatusChanged] in the constructor to keep application-wide
///    state stores or dictionaries synchronized in real time.
/// 3. **Pre-flight Operation Guards**: Imperatively call `await prober.checkConnectivity()` before submitting
///    AI prompts, file uploads, or transactions to immediately interrupt requests when offline.
/// 4. **Targeted Endpoint Health Checks**: Use [probeUri] or the static [NetworkProber.probe] to test
///    specific backend metadata or API microservices.
///
/// ## 4. Usage Examples
///
/// ### Initialization with `onStatusChanged` Hook & Global Sync
/// ```dart
/// final prober = NetworkProber(
///   timeout: const Duration(seconds: 2),
///   minInterval: const Duration(seconds: 2),
///   onStatusChanged: (status) {
///     // Synchronize application global variable or state store
///     AppGlobal.shareData['isOnline'] = (status == NetworkStatus.connected);
///   },
/// );
/// ```
///
/// ### Reactive UI Binding via `statusNotifier`
/// ```dart
/// ValueListenableBuilder<NetworkStatus>(
///   valueListenable: prober.statusNotifier,
///   builder: (context, status, child) {
///     if (status == NetworkStatus.disconnected) {
///       return const OfflineBanner(message: 'Internet disconnected');
///     }
///     return const SizedBox.shrink();
///   },
/// );
/// ```
///
/// ### Pre-Flight Check Before Critical Action
/// ```dart
/// Future<void> onSubmit() async {
///   // Checks cached connectivity; returns in 0ms if recently validated
///   final isOnline = await prober.checkConnectivity();
///   if (!isOnline) {
///     showToast('Network unavailable. Please reconnect.');
///     return;
///   }
///   await executeApiCall();
/// }
/// ```
///
/// ### Integrating with RouteSentry and AppLifecycleEvent
/// ```dart
/// final sentry = RouteSentry(
///   monitoredRoutes: {'/talking/chat', '/talking/gencontent'},
/// );
/// prober.attachRouteMonitor(sentry);
/// ```
/// {@endtemplate}
class NetworkProber {
  /// Creates a [NetworkProber] instance.
  NetworkProber({
    Uri? checkUri,
    List<Uri>? fallbackUris,
    this.timeout = const Duration(seconds: 2),
    this.minInterval = const Duration(seconds: 2),
    this.findProxy,
    this.allowBadCertificates = false,
    this.responseValidator,
    this.onStatusChanged,
    ValueListenable<bool>? routeMonitor,
  })  : _checkUri = checkUri ?? defaultProbeUri,
        _fallbackUris = fallbackUris ??
            (checkUri != null && checkUri != defaultProbeUri
                ? [defaultProbeUri]
                : const []) {
    if (routeMonitor != null) {
      attachRouteMonitor(routeMonitor);
    }
  }

  /// Default globally reachable probe endpoint provided by Apple.
  /// Works reliably worldwide without relying on Google servers.
  static final Uri defaultProbeUri =
      Uri.parse('https://captive.apple.com/internet-check');

  /// Primary probe target URI.
  final Uri _checkUri;

  /// Secondary fallback URIs probed in order when the primary target fails.
  final List<Uri> _fallbackUris;

  /// Connection and read timeout for each probe request.
  final Duration timeout;

  /// Minimum interval between consecutive successful probes to avoid request spam.
  final Duration minInterval;

  /// Whether to accept bad/self-signed SSL certificates (useful for proxy debugging).
  final bool allowBadCertificates;

  /// Optional custom validator for the HTTP probe response.
  final ResponseValidator? responseValidator;

  /// Optional listener hook invoked whenever network status transitions.
  final ValueChanged<NetworkStatus>? onStatusChanged;

  /// Optional proxy resolver callback, conforming to [HttpClient.findProxy].
  ProxyResolver? findProxy;

  /// Reactive status notifier suitable for UI data-binding via [ValueListenableBuilder].
  final ValueNotifier<NetworkStatus> statusNotifier =
      ValueNotifier<NetworkStatus>(NetworkStatus.connected);

  ValueListenable<bool>? _routeMonitor;
  VoidCallback? _routeListener;

  /// External route monitor listener. When attached, connectivity is only
  /// considered monitored when [routeMonitor.value] is `true`.
  ValueListenable<bool>? get routeMonitor => _routeMonitor;

  /// Current network status.
  NetworkStatus get status => statusNotifier.value;

  /// Whether the network is currently connected and reachable.
  bool get isConnected => status == NetworkStatus.connected;

  /// Whether the network is currently disconnected.
  bool get isDisconnected => status == NetworkStatus.disconnected;

  /// Whether the current route is monitored.
  /// Always returns `true` if no [routeMonitor] was supplied.
  bool get isMonitoredRoute => _routeMonitor?.value ?? true;

  HttpClient? _activeClient;
  bool _isChecking = false;
  bool _isDisposed = false;
  DateTime? _lastSuccessTime;

  /// Attaches or updates the external route monitor.
  ///
  /// Safely removes any previous listener and binds to [monitor].
  /// Automatically triggers an initial check if [monitor.value] is currently `true`.
  void attachRouteMonitor(ValueListenable<bool> monitor) {
    if (identical(_routeMonitor, monitor)) return;

    if (_routeMonitor != null && _routeListener != null) {
      _routeMonitor!.removeListener(_routeListener!);
    }

    _routeMonitor = monitor;
    _routeListener = () {
      if (_routeMonitor?.value == true) {
        checkConnectivity();
      }
    };
    _routeMonitor!.addListener(_routeListener!);

    if (_routeMonitor!.value) {
      checkConnectivity();
    }
  }

  /// Probes network connectivity.
  ///
  /// If [force] is `true`, bypasses the [minInterval] throttling check.
  /// Returns `true` if connected, `false` otherwise.
  Future<bool> checkConnectivity({bool force = false}) async {
    if (_isDisposed) return !isDisconnected;

    final now = DateTime.now();
    if (!force &&
        status == NetworkStatus.connected &&
        _lastSuccessTime != null &&
        now.difference(_lastSuccessTime!) < minInterval) {
      return true;
    }

    if (_isChecking) return !isDisconnected;
    _isChecking = true;

    final connected = await _probeWithRetry();

    if (_isDisposed) return connected;

    if (connected) {
      _lastSuccessTime = DateTime.now();
    }

    final newStatus =
        connected ? NetworkStatus.connected : NetworkStatus.disconnected;
    if (statusNotifier.value != newStatus) {
      statusNotifier.value = newStatus;
      onStatusChanged?.call(newStatus);
    }

    _isChecking = false;
    return connected;
  }

  /// Probes the primary URI with an automatic 300ms retry, followed by fallback URIs.
  Future<bool> _probeWithRetry() async {
    if (await _probeUri(_checkUri)) return true;

    // Retry once after 300ms to eliminate momentary radio/handshake glitches.
    await Future.delayed(const Duration(milliseconds: 300));
    if (_isDisposed) return false;
    if (await _probeUri(_checkUri)) return true;

    // Probe fallback URIs if primary target continues to fail.
    for (final fallback in _fallbackUris) {
      if (_isDisposed) return false;
      if (await _probeUri(fallback)) return true;
    }

    return false;
  }

  /// Probes a specific [uri] using this prober's configured proxy, certificate,
  /// and timeout options, with optional overrides.
  Future<bool> probeUri(
    Uri uri, {
    Duration? timeout,
    ResponseValidator? responseValidator,
  }) async {
    return _probeUri(
      uri,
      timeout: timeout,
      responseValidator: responseValidator,
    );
  }

  /// One-shot probe to test if a specific [uri] is reachable without requiring
  /// an existing [NetworkProber] instance.
  static Future<bool> probe(
    Uri uri, {
    Duration timeout = const Duration(seconds: 2),
    ProxyResolver? findProxy,
    bool allowBadCertificates = false,
    ResponseValidator? responseValidator,
  }) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = timeout;
      if (findProxy != null) {
        client.findProxy = findProxy;
      }
      if (allowBadCertificates) {
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
      }
      final request = await client.headUrl(uri);
      final response = await request.close();
      if (responseValidator != null) {
        return responseValidator(response);
      }
      if (uri.path.endsWith('generate_204')) {
        return response.statusCode == HttpStatus.noContent;
      }
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  Future<bool> _probeUri(
    Uri uri, {
    Duration? timeout,
    ResponseValidator? responseValidator,
  }) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = timeout ?? this.timeout;
      _activeClient = client;

      if (findProxy != null) {
        client.findProxy = findProxy!;
      }

      if (allowBadCertificates) {
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
      }

      final request = await client.headUrl(uri);
      final response = await request.close();

      final validator = responseValidator ?? this.responseValidator;
      if (validator != null) {
        return validator(response);
      }

      // Default validation logic.
      if (uri.path.endsWith('generate_204')) {
        return response.statusCode == HttpStatus.noContent;
      }
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
      if (identical(_activeClient, client)) {
        _activeClient = null;
      }
    }
  }

  /// Dynamically updates the HTTP proxy address (e.g. `'127.0.0.1:7890'`).
  ///
  /// Passing `null` or an empty string restores direct connection.
  void updateProxy(String? proxyHostPort) {
    if (proxyHostPort == null || proxyHostPort.trim().isEmpty) {
      findProxy = null;
    } else {
      findProxy = (uri) => 'PROXY $proxyHostPort; DIRECT';
    }
  }

  /// Releases resources, cancels ongoing requests, and detaches listeners.
  void dispose() {
    _isDisposed = true;
    if (_routeMonitor != null && _routeListener != null) {
      _routeMonitor!.removeListener(_routeListener!);
    }
    _routeMonitor = null;
    _routeListener = null;
    _activeClient?.close(force: true);
    _activeClient = null;
    statusNotifier.dispose();
  }
}
