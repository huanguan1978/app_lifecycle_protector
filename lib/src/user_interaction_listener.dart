/*
 * app_lifecycle_protector
 * Description: Lifecycle and interaction management for Flutter applications.
 * 
 * This library helps apps manage lifecycle events, idle detection, and user interactions
 * in a unified and efficient way.
 */

import 'package:flutter/material.dart';

import 'lifecycle_scheduler.dart';

/// A widget that monitors all user interactions and updates the app's alive status.
///
/// This ensures the app doesn't trigger [AppLifecycleEvent.onIdle] during active 
/// user engagement. Use this widget together with [AppLifecycleEvent.onIdle] to 
/// automatically pause background tasks (e.g., history cleanup, data sync) when 
/// the user is actively using the app.
///
/// Monitored interactions:
///   - **Keyboard input**: All key presses and key releases
///   - **Pointer events**: Mouse clicks, touches, stylus input, moves, and drags
///   - **Scroll events**: List/page scrolling and other scroll notifications
///
/// ## Usage
///
/// Wrap your app's root widget with [UserInteractionListener]:
///
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return MaterialApp(
///     builder: (context, child) => UserInteractionListener(
///       child: child!,
///     ),
///     // ... rest of your MaterialApp config
///   );
/// }
/// ```
///
/// Then, implement [AppLifecycleEvent.onIdle] in your lifecycle event handler
/// to perform background tasks:
///
/// ```dart
/// class MyLifecycleEvent extends AppLifecycleEvent {
///   @override
///   void onIdle() {
///     super.onIdle();
///     // This runs only after the user has been inactive for aliveDuration
///     // (default 3 minutes).
///     performBackgroundCleanup();
///   }
/// }
/// ```
class UserInteractionListener extends StatefulWidget {
  /// The widget tree to monitor for user interactions.
  final Widget child;

  const UserInteractionListener({super.key, required this.child});

  @override
  State<UserInteractionListener> createState() =>
      _UserInteractionListenerState();
}

class _UserInteractionListenerState extends State<UserInteractionListener> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onUserInteraction() {
    AppLifecycleScheduler.instance.updateAliveStatus();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (_) => _onUserInteraction(),
      child: Listener(
        onPointerDown: (_) => _onUserInteraction(),
        onPointerMove: (_) => _onUserInteraction(),
        child: NotificationListener<ScrollNotification>(
          onNotification: (_) {
            _onUserInteraction();
            return false;
          },
          child: widget.child,
        ),
      ),
    );
  }
}
