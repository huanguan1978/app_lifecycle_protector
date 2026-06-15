import 'package:flutter/material.dart';

/// Defines the contract for biometric authentication operations.
abstract class BiometricValidator {
  Future<bool> canAuthenticate();
  Future<bool> authenticate({required String localizedReason});
}

/// A standard lock screen for biometric authentication.
class BiometricLockScreen extends StatefulWidget {
  final BiometricValidator validator;
  final Widget fallback;
  final VoidCallback onUnlocked;
  final String? reason;
  final void Function(String msg)? onLog;

  const BiometricLockScreen({
    super.key,
    required this.validator,
    required this.fallback,
    required this.onUnlocked,
    this.reason,
    this.onLog,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  bool _isShowingFallback = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    widget.onLog?.call("Authenticating...");

    setState(() {
      _isAuthenticating = true;
    });

    final supported = await widget.validator.canAuthenticate();
    if (!supported) {
      setState(() {
        _isShowingFallback = true;
        _isAuthenticating = false;
      });
      return;
    }

    final success = await widget.validator.authenticate(
      localizedReason: widget.reason ?? 'Please authenticate to unlock the app',
    );

    if (success) {
      widget.onUnlocked();
    } else {
      setState(() {
        _isAuthenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isShowingFallback) {
      return widget.fallback;
    }

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.fingerprint,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                "Biometric Authentication",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (widget.reason != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16, left: 32, right: 32),
                  child: Text(
                    widget.reason!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isShowingFallback = true;
                  });
                },
                icon: const Icon(Icons.password),
                label: const Text("Use Alternate Method"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
