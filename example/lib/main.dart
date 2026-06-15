import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_lifecycle_protector/app_lifecycle_protector.dart';
import 'package:logging/logging.dart';

// --- MOCK SERVICES ---
// These simulate real-world services like local_auth or storage.

class MockBiometricValidator implements BiometricValidator {
  @override
  Future<bool> canAuthenticate() async => true;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    // Simulate the biometric dialog popping up and waiting
    await Future.delayed(const Duration(seconds: 2));

    // CRITICAL: We return false here to simulate a "canceled" or "failed" biometric.
    // This forces the user to manually click "Use Alternate Method" and type the password,
    // ensuring the lock screen DOES NOT unlock automatically without interaction.
    return false;
  }
}

// --- SECURITY LOGIC ---

class MySecurityHandler extends AppLifecycleEvent {
  final ScreenSecure screenSecure;
  final Function(String) onLog;

  MySecurityHandler(this.screenSecure, {required this.onLog});

  @override
  void onPeriodic() {
    final scheduler = AppLifecycleScheduler.instance;
    final isAlive = scheduler.isAlive();
    onLog('[onPeriodic] IsAlive: $isAlive. Check performed.');

    if (!isAlive) {
      onLog('[Action] Idle timeout reached. Locking app!');
      screenSecure.lock();
    }
  }

  @override
  void onPause() {
    onLog('[onPause] App entered background. Applying mask.');
    screenSecure.mask();
  }

  @override
  void onResume() {
    onLog('[onResume] App returned to foreground. Removing mask.');
    screenSecure.unmask();
  }

  @override
  void onInactive() => onLog('[onInactive] System is transitioning states.');
}

// --- LOGGING BUFFER ---

class LogBuffer extends ChangeNotifier {
  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  void add(String msg) {
    _logs.insert(0,
        "${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second} - $msg");
    // Ensure notification happens after the current frame to avoid build-phase errors
    Future.microtask(() => notifyListeners());
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }
}

// --- UI COMPONENTS ---

final ScreenSecure screenSecure = ScreenSecure();
final Logger logger = Logger('SecurityExample');
final LogBuffer logBuffer = LogBuffer();

void main() {
  // Setup Logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  runApp(const SecurityDemoApp());
}

class SecurityDemoApp extends StatefulWidget {
  const SecurityDemoApp({super.key});

  @override
  State<SecurityDemoApp> createState() => _SecurityDemoAppState();
}

class _SecurityDemoAppState extends State<SecurityDemoApp> {
  @override
  void initState() {
    super.initState();

    // 1. [BEST PRACTICE] Initialize the Orchestrator inside the root widget's initState.
    // This ensures the scheduler is synchronized with the app lifecycle and 
    // ready before the MaterialApp and its Navigator are built.
    AppLifecycleScheduler.initialize(
      interval: const Duration(seconds: 5), // High frequency for demo
      event: MySecurityHandler(
        screenSecure,
        onLog: logBuffer.add,
      ),
      logger: logger,
    );

    // 2. Configure parameters for the periodic inspection logic
    AppLifecycleScheduler.instance.aliveDuration = const Duration(seconds: 60);

    // 3. Global Hardware Keyboard Tracking (Business Logic Integration)
    HardwareKeyboard.instance.addHandler((event) {
      AppLifecycleScheduler.instance.updateAliveStatus();
      return false;
    });

    // 4. Force initial lock for demonstration (Security Logic Integration)
    // By calling this here, the app starts in a protected state immediately.
    screenSecure.lock();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // CRITICAL: Tracks touch interactions to refresh active status
      onPointerDown: (_) => AppLifecycleScheduler.instance.updateAliveStatus(),
      child: MaterialApp(
        title: 'Security Protector Demo',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.blue,
        ),
        builder: (context, child) {
          void onUnlocked() {
            screenSecure.unlock();
            // IMPORTANT: Refresh activity status after unlocking to prevent immediate re-lock
            AppLifecycleScheduler.instance.updateAliveStatus();
            logger.info('[Action] App Unlocked and activity status refreshed');
          }

          // Authorization Screens
          final lockWidget = BiometricLockScreen(
            validator: MockBiometricValidator(),
            onUnlocked: onUnlocked,
            reason: "Simulation Mode: Biometric check will fail by design.",
            onLog: (msg) {
              if (msg == "Authenticating...") {
                logBuffer.add(
                    "[Biometric] Retry clicked. This is a simulation. For production, please integrate the 'local_auth' package for real biometric security.");
              }
            },
            fallback: PassphraseLockScreen(
              title: "Security Verification",
              footerText:
                  "This is a mock lock. Enter '123456' to simulate a successful authorization.",
              onValidate: (pw, _) =>
                  pw == "123456" ? null : "Invalid Secret Key (Try 123456)",
              onUnlocked: onUnlocked,
            ),
          );

          return ScreenProtector(
            screenSecure: screenSecure,
            lockWidget: lockWidget,
            child: child!,
          );
        },
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("App Lifecycle Protector"),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock),
            onPressed: () => screenSecure.lock(),
            tooltip: "Lock Now",
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 24),
            const Text(
              "Interaction Test Zone",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Type here to stay active",
                hintText: "Updates status on every character",
              ),
              onChanged: (_) =>
                  AppLifecycleScheduler.instance.updateAliveStatus(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Activity Logs",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => logBuffer.clear(),
                  child: const Text("Clear"),
                )
              ],
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ListenableBuilder(
                  listenable: logBuffer,
                  builder: (context, _) {
                    final logs = logBuffer.logs;
                    return ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: logs.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          logs[index],
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 0,
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.timer, color: Colors.blue),
                SizedBox(width: 8),
                Text("Idle Timeout Config: 60 Seconds"),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.security, color: Colors.blue),
                const SizedBox(width: 8),
                const Text("Privacy Mask: "),
                ListenableBuilder(
                  listenable: screenSecure,
                  builder: (context, _) => Text(
                    screenSecure.isMasked ? "ACTIVE" : "INACTIVE",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: screenSecure.isMasked ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
