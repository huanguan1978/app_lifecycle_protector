import 'dart:async';

import 'package:app_lifecycle_protector/app_lifecycle_protector.dart';
import 'package:flutter/material.dart';

class ScreenSecureDemo {
  ScreenSecureDemo({required this.onLog}) : screenSecure = ScreenSecure() {
    screenSecure.lock();
  }

  final void Function(String message) onLog;
  final ScreenSecure screenSecure;

  void onPeriodic({required bool isAlive}) {
    if (!isAlive && !screenSecure.isLocked) {
      onLog('[ScreenSecure] Idle timeout reached. Locking the app.');
      screenSecure.lock();
    }
  }

  void onPause() {
    onLog('[ScreenSecure] Applying privacy mask.');
    screenSecure.mask();
  }

  void onResume() {
    onLog('[ScreenSecure] Removing privacy mask.');
    screenSecure.unmask();
  }

  void lockNow() {
    onLog('[ScreenSecure] Manual lock requested.');
    screenSecure.lock();
  }

  Widget buildLockWidget({required VoidCallback onUnlocked}) {
    return BiometricLockScreen(
      validator: MockBiometricValidator(),
      onUnlocked: onUnlocked,
      reason: 'Demo mode: biometric authentication fails by design.',
      onLog: (message) {
        if (message == 'Authenticating...') {
          onLog(
            '[Biometric] Simulated failure. Use the passphrase fallback; '
            'production apps should integrate real authentication.',
          );
        }
      },
      fallback: PassphraseLockScreen(
        title: 'Security Verification',
        footerText: "Enter '123456' to simulate successful authorization.",
        onValidate: (passphrase, _) =>
            passphrase == '123456' ? null : 'Invalid passphrase. Try 123456.',
        onUnlocked: onUnlocked,
      ),
    );
  }

  void dispose() {
    screenSecure.dispose();
  }
}

class MockBiometricValidator implements BiometricValidator {
  @override
  Future<bool> canAuthenticate() async => true;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    return false;
  }
}
