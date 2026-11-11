import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'app/demo_app.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  runApp(const DemoApp());
}
