import 'package:flutter/material.dart';

/// Manages privacy mask and application lock states.
class ScreenSecure extends ChangeNotifier {
  bool _isMasked = false;
  bool _isLocked = false;

  bool get isMasked => _isMasked;

  void setMasked(bool masked) {
    if (_isMasked != masked) {
      _isMasked = masked;
      notifyListeners();
    }
  }

  bool get isLocked => _isLocked;

  void setLocked(bool locked) {
    if (locked) setMasked(false);
    if (_isLocked != locked) {
      _isLocked = locked;
      notifyListeners();
    }
  }
}

/// Semantic extensions for ScreenSecure.
extension ScreenSecureExtension on ScreenSecure {
  /// Lock the screen and hide the mask.
  void lock() => setLocked(true);

  /// Unlock the screen.
  void unlock() => setLocked(false);

  /// Show the privacy mask.
  void mask() => setMasked(true);

  /// Hide the privacy mask.
  void unmask() => setMasked(false);
}

/// A wrapper widget that overlays privacy mask or lock screen based on state.
class ScreenProtector extends StatelessWidget {
  final Widget child;
  final ScreenSecure screenSecure;
  final Widget? maskWidget;
  final Widget? lockWidget;

  const ScreenProtector({
    super.key,
    required this.child,
    required this.screenSecure,
    this.maskWidget,
    this.lockWidget,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: screenSecure,
      builder: (context, _) {
        return Stack(
          children: [
            child,
            if (screenSecure.isMasked)
              Positioned.fill(
                child: Overlay(
                  initialEntries: [
                    OverlayEntry(
                      builder: (context) => Material(
                        child: maskWidget ?? _defaultMask(),
                      ),
                    ),
                  ],
                ),
              ),
            if (screenSecure.isLocked)
              Positioned.fill(
                child: Overlay(
                  initialEntries: [
                    OverlayEntry(
                      builder: (context) => Material(
                        child: lockWidget ?? _defaultLock(),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _defaultMask() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(Icons.privacy_tip, size: 64, color: Colors.blue),
      ),
    );
  }

  Widget _defaultLock() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          "App Locked",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
