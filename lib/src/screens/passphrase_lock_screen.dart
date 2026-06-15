import 'dart:async';
import 'package:flutter/material.dart';

/// Callback for validation. Returns null on success, or an error message on failure.
typedef LockScreenValidator = FutureOr<String?> Function(String password, String? username);

/// Builder for the username widget.
typedef UsernameFieldBuilder = Widget Function(
  BuildContext context,
  TextEditingController controller,
);

/// Builder for the password widget.
typedef PasswordFieldBuilder = Widget Function(
  BuildContext context,
  TextEditingController controller,
  String? errorText,
  bool isLoading,
  VoidCallback onTryUnlock,
);

/// A highly customizable full-screen lock interface.
class PassphraseLockScreen extends StatefulWidget {
  final LockScreenValidator onValidate;
  final VoidCallback? onUnlocked;
  final UsernameFieldBuilder? usernameBuilder;
  final PasswordFieldBuilder? passwordBuilder;
  final Widget? icon;
  final String? title;
  final String? footerText;

  const PassphraseLockScreen({
    super.key,
    required this.onValidate,
    this.onUnlocked,
    this.usernameBuilder,
    this.passwordBuilder,
    this.icon,
    this.title,
    this.footerText,
  });

  @override
  State<PassphraseLockScreen> createState() => _PassphraseLockScreenState();
}

class _PassphraseLockScreenState extends State<PassphraseLockScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  String? _errorText;
  bool _isLoading = false;

  void _handleUnlock() {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    Future.value(widget.onValidate(
      _passwordController.text,
      widget.usernameBuilder != null ? _usernameController.text : null,
    )).then((error) {
      if (mounted) {
        if (error == null) {
          _passwordController.clear();
          widget.onUnlocked?.call();
        } else {
          setState(() => _errorText = error);
        }
      }
    }).catchError((e) {
      if (mounted) {
        setState(() => _errorText = e.toString());
      }
    }).whenComplete(() {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.icon ??
                    Icon(
                      Icons.lock_person_outlined,
                      size: 80,
                      color: Theme.of(context).primaryColor,
                    ),
                const SizedBox(height: 24),

                if (widget.title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      widget.title!,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                  ),

                if (widget.usernameBuilder != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: widget.usernameBuilder!(context, _usernameController),
                  ),

                widget.passwordBuilder?.call(
                      context,
                      _passwordController,
                      _errorText,
                      _isLoading,
                      _handleUnlock,
                    ) ??
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      autofocus: true,
                      enabled: !_isLoading,
                      style: const TextStyle(fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        labelText: 'Secret Key',
                        hintText: 'Enter your passphrase',
                        errorText: _errorText,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.arrow_forward),
                                onPressed: _handleUnlock,
                              ),
                      ),
                      onSubmitted: (_) => _handleUnlock(),
                    ),
                const SizedBox(height: 16),

                Text(
                  widget.footerText ?? "Verification required to resume your session",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
