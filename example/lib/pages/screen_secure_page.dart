import 'package:flutter/material.dart';

import '../features/screen_secure/screen_secure_demo.dart';

class ScreenSecurePage extends StatelessWidget {
  const ScreenSecurePage({
    required this.screenSecureDemo,
    super.key,
  });

  final ScreenSecureDemo screenSecureDemo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Screen protection')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'This page is covered by the app-wide ScreenProtector. '
              'The app starts locked. After the simulated biometric check '
              'fails, choose “Use Alternate Method” and enter 123456.',
            ),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: screenSecureDemo.screenSecure,
              builder: (context, _) {
                final secure = screenSecureDemo.screenSecure;
                return Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.lock),
                        title: const Text('Lock state'),
                        trailing: Text(secure.isLocked ? 'Locked' : 'Unlocked'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.visibility_off),
                        title: const Text('Privacy mask'),
                        trailing: Text(secure.isMasked ? 'Visible' : 'Hidden'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: screenSecureDemo.lockNow,
              icon: const Icon(Icons.lock),
              label: const Text('Lock now'),
            ),
            const SizedBox(height: 12),
            const Text(
              'The mask is applied when the app is paused and removed when it '
              'resumes. User interaction refreshes the idle timer.',
            ),
          ],
        ),
      ),
    );
  }
}
