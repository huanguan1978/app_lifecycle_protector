import 'package:flutter_test/flutter_test.dart';
import 'package:skills_lint/skills_lint.dart';

void main() {
  test('published package skills pass lint', () async {
    final config = await ConfigParser.loadConfig();

    expect(config.parsingErrors, isEmpty);
    expect(await validateSkills(config: config), isTrue);
  });
}
