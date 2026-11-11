import 'package:flutter/material.dart';

import '../features/network_prober/network_probe_demo.dart';

class NetworkProbePage extends StatefulWidget {
  const NetworkProbePage({
    required this.networkProbeDemo,
    super.key,
  });

  final NetworkProbeDemo networkProbeDemo;

  @override
  State<NetworkProbePage> createState() => _NetworkProbePageState();
}

class _NetworkProbePageState extends State<NetworkProbePage> {
  late final TextEditingController _proxyController;

  NetworkProbeDemo get networkProbeDemo => widget.networkProbeDemo;

  @override
  void initState() {
    super.initState();
    _proxyController = TextEditingController(
      text: networkProbeDemo.proxyAddress ?? '',
    );
  }

  @override
  void dispose() {
    _proxyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network probe')),
      body: ListenableBuilder(
        listenable: networkProbeDemo,
        builder: (context, _) {
          final result = networkProbeDemo.lastProbeResult;
          final status = !networkProbeDemo.hasProbeResult
              ? 'Not checked yet'
              : result == true
                  ? 'Endpoint reachable'
                  : 'Endpoint unreachable';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Probe endpoint: ${networkProbeDemo.probeUri}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: Icon(
                    networkProbeDemo.hasProbeResult
                        ? result == true
                            ? Icons.wifi
                            : Icons.wifi_off
                        : Icons.help_outline,
                  ),
                  title: Text(
                    networkProbeDemo.isChecking ? 'Checking…' : status,
                  ),
                  subtitle: Text(
                    networkProbeDemo.isMonitoringRoute
                        ? 'This route is monitored.'
                        : 'This route is not monitored.',
                  ),
                ),
              ),
              if (networkProbeDemo.probeError case final error?) ...[
                const SizedBox(height: 8),
                Text(
                  'Probe error: $error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: networkProbeDemo.isChecking
                    ? null
                    : () => networkProbeDemo.checkNow(force: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Check now'),
              ),
              const SizedBox(height: 16),
              const Text(
                'The lifecycle coordinator probes periodically only while '
                'the app is in the foreground on this monitored route. '
                'The probe checks the configured HTTP endpoint; it does not '
                'read network-interface hardware state.',
              ),
              const SizedBox(height: 16),
              _buildProxySection(context),
              const SizedBox(height: 8),
              _buildPlatformSetupSection(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProxySection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Network proxy',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'A reachable HTTP proxy can help when the probe endpoint is '
              'blocked by the current network. Enter its host and port. '
              'This setting applies to this NetworkProber only.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _proxyController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Proxy host:port',
                hintText: '127.0.0.1:8080',
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: networkProbeDemo.isChecking
                      ? null
                      : () =>
                          networkProbeDemo.updateProxy(_proxyController.text),
                  child: const Text('Apply proxy and check'),
                ),
                OutlinedButton(
                  onPressed: networkProbeDemo.isChecking
                      ? null
                      : () {
                          _proxyController.clear();
                          networkProbeDemo.updateProxy(null);
                        },
                  child: const Text('Use direct connection'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformSetupSection(BuildContext context) {
    return const Card(
      child: ExpansionTile(
        leading: Icon(Icons.settings_ethernet),
        title: Text('Platform network configuration'),
        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            'Network access can depend on the target platform and how the app '
            'is packaged. Check these common cases when a probe fails:',
          ),
          SizedBox(height: 8),
          _PlatformRequirement(
            platform: 'Android',
            detail: 'Declare android.permission.INTERNET in the app manifest. '
                'This normal permission is granted at install time.',
          ),
          _PlatformRequirement(
            platform: 'macOS',
            detail:
                'For App Sandbox builds, enable the outgoing network client '
                'entitlement (com.apple.security.network.client).',
          ),
          _PlatformRequirement(
            platform: 'Flatpak / Snap',
            detail:
                'The package must be granted network access (Flatpak network '
                'share or the Snap network interface).',
          ),
          _PlatformRequirement(
            platform: 'MSIX',
            detail:
                'Check the package manifest for the capabilities required by '
                'the app type; full-trust desktop and AppContainer apps differ.',
          ),
          _PlatformRequirement(
            platform: 'iOS',
            detail: 'Ordinary HTTPS requests do not need a runtime network '
                'permission. Keep platform transport-security rules in mind '
                'if using non-HTTPS endpoints.',
          ),
          SizedBox(height: 8),
          Text(
            'These are outbound network permissions, not permission to read '
            'network-interface hardware. A proxy can help only if the proxy '
            'itself is reachable and allowed by the platform. This prober '
            'tries the configured proxy before falling back to a direct '
            'connection.',
          ),
        ],
      ),
    );
  }
}

class _PlatformRequirement extends StatelessWidget {
  const _PlatformRequirement({
    required this.platform,
    required this.detail,
  });

  final String platform;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$platform: ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: detail),
            ],
          ),
        ),
      ),
    );
  }
}
