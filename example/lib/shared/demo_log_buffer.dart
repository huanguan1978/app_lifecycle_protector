import 'package:flutter/foundation.dart';

class DemoLogBuffer extends ChangeNotifier {
  final List<String> _entries = [];
  bool _isDisposed = false;

  List<String> get entries => List.unmodifiable(_entries);

  void add(String message) {
    final now = DateTime.now();
    final timestamp = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    _entries.insert(0, '$timestamp - $message');
    Future<void>.microtask(() {
      if (!_isDisposed) notifyListeners();
    });
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
