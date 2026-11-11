import 'package:flutter/material.dart';
import 'package:app_lifecycle_protector/app_lifecycle_protector.dart';

import '../app/demo_routes.dart';
import '../features/network_prober/network_probe_demo.dart';
import '../features/screen_secure/screen_secure_demo.dart';
import '../shared/demo_log_buffer.dart';

class DemoHomePage extends StatelessWidget {
  const DemoHomePage({
    required this.screenSecureDemo,
    required this.networkProbeDemo,
    required this.logs,
    super.key,
  });

  final ScreenSecureDemo screenSecureDemo;
  final NetworkProbeDemo networkProbeDemo;
  final DemoLogBuffer logs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Lifecycle Protector')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFrameworkCard(),
            const SizedBox(height: 12),
            _buildFeatureCard(
              context,
              title: 'Screen protection',
              description:
                  'Privacy mask, idle locking, and a simulated unlock flow.',
              icon: Icons.security,
              route: DemoRoutes.screenSecure,
            ),
            const SizedBox(height: 12),
            _buildNetworkCard(context),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Activity log',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: logs.clear,
                  child: const Text('Clear'),
                ),
              ],
            ),
            Expanded(child: _buildLogList()),
          ],
        ),
      ),
    );
  }

  Widget _buildFrameworkCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Framework',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Scheduler interval: 5 seconds · Idle timeout: '
              '${AppLifecycleScheduler.instance.aliveDuration.inSeconds} seconds',
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Type to refresh the activity timer',
              ),
              onChanged: (_) =>
                  AppLifecycleScheduler.instance.updateAliveStatus(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required String route,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).pushNamed(route),
      ),
    );
  }

  Widget _buildNetworkCard(BuildContext context) {
    return ListenableBuilder(
      listenable: networkProbeDemo,
      builder: (context, _) {
        final result = networkProbeDemo.hasProbeResult
            ? (networkProbeDemo.lastProbeResult! ? 'Reachable' : 'Unreachable')
            : 'Not checked';
        return Card(
          child: ListTile(
            leading: const Icon(Icons.wifi),
            title: const Text('Network probe'),
            subtitle: Text(
              networkProbeDemo.isChecking ? 'Checking…' : result,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.of(context).pushNamed(DemoRoutes.networkProbe),
          ),
        );
      },
    );
  }

  Widget _buildLogList() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ListenableBuilder(
        listenable: logs,
        builder: (context, _) {
          final entries = logs.entries;
          if (entries.isEmpty) {
            return const Center(
                child: Text('Lifecycle events will appear here.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: entries.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                entries[index],
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          );
        },
      ),
    );
  }
}
