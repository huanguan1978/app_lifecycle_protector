import 'package:app_lifecycle_protector_example/app/demo_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unlocks into the demo and opens screen protection', (
    tester,
  ) async {
    await tester.pumpWidget(const DemoApp());
    await tester.pump();

    expect(find.text('Use Alternate Method'), findsOneWidget);
    await tester.tap(find.text('Use Alternate Method'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    final passphraseField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Secret Key',
    );
    await tester.enterText(passphraseField, '123456');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Framework'), findsOneWidget);
    await tester.tap(find.text('Screen protection'));
    await tester.pumpAndSettle();
    expect(find.text('Lock now'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
